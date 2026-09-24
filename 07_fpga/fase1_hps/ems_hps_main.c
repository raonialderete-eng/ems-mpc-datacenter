#include "ems_param.h"
#include "planta_bess.h"
#include "controle_heuristico.h"
#include "controle_mpc_fpga.h"
#include "gera_cenario.h"
#include "ems_protocol.h"
#include "qp_admm.h"
#include "qp_engine.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef _WIN32
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#ifndef CRTSCTS
#define CRTSCTS 0
#endif
#endif

#define NMAX 4096

static double g_rho_ov = -1.0;
static int g_iter_ov = -1;
static int g_diag;
static const char *g_dump_dir;
static const char *g_trace_csv;
static const char *g_state_path;

static void hil_step(const char *ctrl, const EmsParam *param, const char *line,
                     FILE *out)
{
    HilReq req;
    HilRsp rsp;
    MpcInfo inf;
    int gtmp[EMS_NP];
    int i;

    if (ems_parse_req(line, &req) != 0) {
        fprintf(out, "ERR parse\n");
        fflush(out);
        return;
    }

    if (strcmp(ctrl, "heur") == 0) {
        rsp.PBESS_ref = controle_heuristico(req.Pload[0], req.Pmax[0],
                                            req.grid[0], req.SOC, param);
        rsp.exitflag = 1;
        rsp.fallback = 0;
        rsp.evento = 0;
        rsp.t_us = 0;
    } else if (strcmp(ctrl, "heur_fs") == 0) {
        for (i = 0; i < req.Np; ++i)
            gtmp[i] = req.grid[i];
        rsp.PBESS_ref = controle_heuristico_foresight(
            0, req.SOC, req.uref, req.Pload, req.Pmax, gtmp, req.Np, param);
        rsp.exitflag = 1;
        rsp.fallback = 0;
        rsp.evento = 0;
        rsp.t_us = 0;
    } else {
        for (i = 0; i < req.Np; ++i)
            gtmp[i] = req.grid[i];
        inf = controle_mpc_fpga(0, req.SOC, req.PBESS, req.uref, req.Psrc_ant,
                                req.Pload, req.Pmax, gtmp, req.Np, param);
        rsp.PBESS_ref = inf.PBESS_ref;
        rsp.exitflag = inf.exitflag;
        rsp.fallback = inf.usou_fallback;
        rsp.evento = inf.modo_evento;
        rsp.t_us = (unsigned long)(inf.tempo_qp_s * 1e6);
    }
    fprintf(out, "RSP %.8f %lu %d %d %d\n",
            rsp.PBESS_ref, rsp.t_us, rsp.exitflag, rsp.fallback, rsp.evento);
    fflush(out);
}

static void hil_loop_io(const char *ctrl, FILE *in, FILE *out, int banner)
{
    EmsParam param;
    char line[4096];
    ems_param_fpga(&param);
    if (g_rho_ov > 0.0)
        param.admm_rho = g_rho_ov;
    if (g_iter_ov > 0)
        param.admm_max_iter = g_iter_ov;
    qp_admm_reset_warm();
    if (banner)
        fprintf(out, "EMS HPS HIL ready\n");
    fflush(out);
    while (fgets(line, sizeof(line), in))
        hil_step(ctrl, &param, line, out);
}

#ifndef _WIN32
static FILE *uart_open(const char *dev)
{
    int fd;
    struct termios tio;
    FILE *fp;

    fd = open(dev, O_RDWR | O_NOCTTY);
    if (fd < 0) {
        perror(dev);
        return NULL;
    }
    memset(&tio, 0, sizeof(tio));
    if (tcgetattr(fd, &tio) != 0) {
        perror("tcgetattr");
        close(fd);
        return NULL;
    }
    cfsetispeed(&tio, B115200);
    cfsetospeed(&tio, B115200);
    tio.c_cflag |= (CLOCAL | CREAD);
    tio.c_cflag &= ~PARENB;
    tio.c_cflag &= ~CSTOPB;
    tio.c_cflag &= ~CSIZE;
    tio.c_cflag |= CS8;
    tio.c_cflag &= ~CRTSCTS;
    tio.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    tio.c_iflag &= ~(IXON | IXOFF | IXANY | IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);
    tio.c_oflag &= ~OPOST;
    tio.c_cc[VMIN] = 1;
    tio.c_cc[VTIME] = 0;
    if (tcsetattr(fd, TCSANOW, &tio) != 0) {
        perror("tcsetattr");
        close(fd);
        return NULL;
    }
    fp = fdopen(fd, "r+");
    if (!fp) {
        perror("fdopen");
        close(fd);
        return NULL;
    }
    setvbuf(fp, NULL, _IONBF, 0);
    return fp;
}
#endif

static int event_bounds(const int *grid, int N, int *k_prep, int *k_on,
                        int *k_off, int *k_ret)
{
    int i, first = -1, last = -1;
    for (i = 0; i < N; ++i) {
        if (grid[i] == 0) {
            if (first < 0)
                first = i;
            last = i;
        }
    }
    *k_on = first;
    *k_off = last;
    *k_prep = (first >= EMS_NP) ? first - EMS_NP : first;
    *k_ret = (last >= 0 && last + 1 < N - 1) ? last + 1 : -1;
    return first >= 0;
}

static int want_dump(int k, int k_prep, int k_on, int k_off, int k_ret)
{
    if (k == 0)
        return 1;
    if (k_prep >= 0 && k == k_prep)
        return 1;
    if (k_on >= 0 && k == k_on)
        return 1;
    if (k_off >= 0 && k == k_off)
        return 1;
    if (k_ret >= 0 && k == k_ret)
        return 1;
    return 0;
}

static void simular(const char *ctrl, const char *cenario)
{
    EmsParam param;
    double Pload[NMAX], Pmax[NMAX];
    int grid[NMAX];
    int N, k;
    double SOC, PBESS, uref, Psrc, Pnao_max;
    int n_fb, n_evt, n_lim, n_inv, n_iter_sum;
    int n_eval_app, n_eval_kkt, n_shadow_ok;
    int k_prep = -1, k_on = -1, k_off = -1, k_ret = -1;
    double tqp_sum, tqp_max, pri_max, pri_sum, du0_same_max;
    FILE *fcsv;

    ems_param_fpga(&param);
    if (g_rho_ov > 0.0)
        param.admm_rho = g_rho_ov;
    if (g_iter_ov > 0)
        param.admm_max_iter = g_iter_ov;
    qp_admm_reset_warm();
    if (g_dump_dir)
        qp_admm_set_dump_dir(g_dump_dir);
    if (gera_cenario(cenario, &param, Pload, Pmax, grid, &N) != 0 || N > NMAX) {
        fprintf(stderr, "cenario invalido ou N grande\n");
        exit(1);
    }
    event_bounds(grid, N, &k_prep, &k_on, &k_off, &k_ret);
    if (g_dump_dir && k_on >= 0)
        fprintf(stderr, "dump landmarks k=0 prep=%d on=%d off=%d ret=%d dir=%s\n",
                k_prep, k_on, k_off, k_ret, g_dump_dir);

    SOC = param.SOC_ref;
    PBESS = 0.0;
    uref = 0.0;
    Psrc = Pload[0];
    Pnao_max = 0.0;
    n_fb = 0;
    n_evt = 0;
    n_lim = 0;
    n_inv = 0;
    n_iter_sum = 0;
    tqp_sum = 0.0;
    tqp_max = 0.0;
    pri_max = 0.0;
    pri_sum = 0.0;
    n_eval_app = 0;
    n_eval_kkt = 0;
    n_shadow_ok = 0;
    du0_same_max = 0.0;

    {
        FILE *tr = NULL;
        MpcInfo inf0;
        memset(&inf0, 0, sizeof(inf0));
        if (g_trace_csv) {
            tr = fopen(g_trace_csv, "w");
            if (tr)
                fprintf(tr, "k,u,SOC,PBESS,Pnao,Psrc,exitflag,fallback,causa,pri,iter,t_s,shadow_u0,shadow_ok,eval_app,eval_kkt,du0_same\n");
        }

    for (k = 0; k < N - 1; ++k) {
        double u;
        PlantaOut po;
        memset(&inf0, 0, sizeof(inf0));
        if (strcmp(ctrl, "heur") == 0) {
            u = controle_heuristico(Pload[k], Pmax[k], grid[k], SOC, &param);
        } else if (strcmp(ctrl, "heur_fs") == 0) {
            u = controle_heuristico_foresight(k, SOC, uref, Pload, Pmax, grid, N, &param);
        } else {
            if (g_diag && k < 2)
                qp_admm_set_trace(stderr);
            else
                qp_admm_set_trace(NULL);
            qp_admm_request_dump(k, g_dump_dir ? want_dump(k, k_prep, k_on, k_off, k_ret) : 0);
            inf0 = controle_mpc_fpga(k, SOC, PBESS, uref, Psrc,
                                     Pload, Pmax, grid, N, &param);
            u = inf0.PBESS_ref;
            n_fb += inf0.usou_fallback;
            n_evt += inf0.modo_evento;
            n_iter_sum += inf0.admm_iter;
            pri_sum += inf0.pri_res;
            if (inf0.pri_res > pri_max)
                pri_max = inf0.pri_res;
            if (inf0.exitflag == 0)
                n_lim++;
            else if (inf0.exitflag < 0)
                n_inv++;
            tqp_sum += inf0.tempo_qp_s;
            if (inf0.tempo_qp_s > tqp_max)
                tqp_max = inf0.tempo_qp_s;
            n_eval_app += inf0.eval_pass_app;
            n_eval_kkt += inf0.eval_pass_kkt;
            n_shadow_ok += inf0.shadow_ok;
            if (inf0.du0_same == inf0.du0_same && inf0.du0_same > du0_same_max)
                du0_same_max = inf0.du0_same;
            if (k == 0)
                fprintf(stderr, "u0=%.8f pri=%.6g iter=%d fb=%d exit=%d\n",
                        u, inf0.pri_res, inf0.admm_iter, inf0.usou_fallback,
                        inf0.exitflag);
        }
        po = planta_bess(SOC, PBESS, u, Pload[k], Pmax[k], grid[k], &param);
        if (tr)
            fprintf(tr, "%d,%.8f,%.8f,%.8f,%.8f,%.8f,%d,%d,%s,%.8g,%d,%.8g,%.8g,%d,%d,%d,%.8g\n",
                    k, u, SOC, PBESS, po.Pnao, po.Psource, inf0.exitflag,
                    inf0.usou_fallback, inf0.fallback_causa[0] ? inf0.fallback_causa : "ok",
                    inf0.pri_res, inf0.admm_iter, inf0.tempo_qp_s,
                    inf0.shadow_u0, inf0.shadow_ok, inf0.eval_pass_app,
                    inf0.eval_pass_kkt, inf0.du0_same);
        SOC = po.SOC_next;
        PBESS = po.PBESS_next;
        Psrc = po.Psource;
        uref = u;
        if (po.Pnao > Pnao_max)
            Pnao_max = po.Pnao;
    }
        if (tr)
            fclose(tr);
    }

    printf("ctrl=%s cenario=%s Pnao_max=%.6f SOC_final=%.6f fallback=%d evento=%d "
           "tqp_med=%.6f tqp_max=%.6f pri_med=%.4g pri_max=%.4g iter_med=%.1f n_lim=%d n_inv=%d "
           "eval_app=%d eval_kkt=%d du0_same_max=%.4g shadow_ok=%d\n",
           ctrl, cenario, Pnao_max, SOC, n_fb, n_evt,
           tqp_sum / (N - 1), tqp_max,
           pri_sum / (N - 1), pri_max,
           n_iter_sum / (double)(N - 1), n_lim, n_inv,
           n_eval_app, n_eval_kkt, du0_same_max, n_shadow_ok);

    fcsv = fopen("ems_hps_kpi.csv", "a");
    if (fcsv) {
        fprintf(fcsv,
                "%s,%s,rho=%.4g,max_iter=%d,pri_tol=1.0,"
                "Pnao_max=%.6f,SOC=%.6f,fallback=%d,evento=%d,"
                "tqp_med=%.6f,tqp_max=%.6f,pri_max=%.4g,n_lim=%d,n_inv=%d,"
                "eval_app=%d,eval_kkt=%d,du0_same_max=%.4g,shadow_ok=%d\n",
                ctrl, cenario, param.admm_rho, param.admm_max_iter,
                Pnao_max, SOC, n_fb, n_evt,
                tqp_sum / (N - 1), tqp_max, pri_max, n_lim, n_inv,
                n_eval_app, n_eval_kkt, du0_same_max, n_shadow_ok);
        fclose(fcsv);
    }
}

static void usage(void)
{
    fprintf(stderr,
            "uso: ems_hps [--ctrl heur|heur_fs|mpc] [--cenario NOME]\n"
            "             [--hil] [--hil-uart DEV] [--rho R] [--max-iter N]\n"
            "             [--qp-solver admm|admm_hist|osqp|qpoases]\n"
            "             [--shadow-solver NAME]  resolve o mesmo QP sem aplicar o comando\n"
            "  --hil            REQ/RSP em stdin/stdout (MATLAB c_exe ou SSH)\n"
            "  --hil-uart DEV   mesmo protocolo em UART 115200 8N1 (POSIX/HPS)\n"
            "  --rho R          sobrescreve admm_rho\n"
            "  --max-iter N     sobrescreve admm_max_iter (criterio pri<1 inalterado)\n"
            "  --diag-admm      imprime residual das 2 primeiras iteracoes do 1o/2o passo\n"
            "  --dump-qp DIR    exporta QPs: k=0, prep/ilha/retorno e ate 6 rejeites\n"
            "  --trace-csv F    trajetoria k,u,SOC,Pnao,fallback,causa\n"
            "  --from-state F   um passo C com o pacote de entradas (sem planta)\n");
}

static int read_vec(FILE *fp, double *v, int n)
{
    int i;
    for (i = 0; i < n; ++i)
        if (fscanf(fp, "%lf", &v[i]) != 1)
            return -1;
    return 0;
}

static int run_from_state(const char *path)
{
    FILE *fp;
    EmsParam param;
    double SOC = 60, PBESS = 0, uref = 0, Psrc = 600;
    double Pload[EMS_NP], Pmax[EMS_NP];
    int grid[EMS_NP];
    int N = EMS_NP, i, k = 0;
    char tag[64];
    MpcInfo inf;

    fp = fopen(path, "r");
    if (!fp) {
        perror(path);
        return 1;
    }
    ems_param_fpga(&param);
    if (g_rho_ov > 0.0)
        param.admm_rho = g_rho_ov;
    if (g_iter_ov > 0)
        param.admm_max_iter = g_iter_ov;
    for (i = 0; i < EMS_NP; ++i) {
        Pload[i] = 600.0;
        Pmax[i] = 800.0;
        grid[i] = 1;
    }
    while (fscanf(fp, "%63s", tag) == 1) {
        if (strcmp(tag, "SOC") == 0)
            fscanf(fp, "%lf", &SOC);
        else if (strcmp(tag, "PBESS") == 0)
            fscanf(fp, "%lf", &PBESS);
        else if (strcmp(tag, "uref") == 0)
            fscanf(fp, "%lf", &uref);
        else if (strcmp(tag, "Psrc") == 0)
            fscanf(fp, "%lf", &Psrc);
        else if (strcmp(tag, "N") == 0)
            fscanf(fp, "%d", &N);
        else if (strcmp(tag, "k") == 0)
            fscanf(fp, "%d", &k);
        else if (strcmp(tag, "Pload") == 0) {
            if (N > EMS_NP) N = EMS_NP;
            if (read_vec(fp, Pload, N) != 0)
                break;
        } else if (strcmp(tag, "Pmax") == 0) {
            if (read_vec(fp, Pmax, N) != 0)
                break;
        } else if (strcmp(tag, "grid") == 0) {
            for (i = 0; i < N; ++i)
                fscanf(fp, "%d", &grid[i]);
        }
    }
    fclose(fp);
    if (N > EMS_NP)
        N = EMS_NP;
    qp_admm_reset_warm();
    if (g_dump_dir)
        qp_admm_set_dump_dir(g_dump_dir);
    qp_admm_request_dump(k, 1);
    inf = controle_mpc_fpga(0, SOC, PBESS, uref, Psrc, Pload, Pmax, grid, N, &param);
    printf("from_state k=%d u=%.8f exit=%d fb=%d causa=%s pri=%.6g iter=%d\n",
           k, inf.PBESS_ref, inf.exitflag, inf.usou_fallback,
           inf.fallback_causa[0] ? inf.fallback_causa : "ok",
           inf.pri_res, inf.admm_iter);
    return 0;
}

int main(int argc, char **argv)
{
    const char *ctrl = "heur";
    const char *cen = "carga_faixas";
    const char *uart_dev = NULL;
    int hil = 0;
    int i;

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--hil") == 0)
            hil = 1;
        else if (strcmp(argv[i], "--hil-uart") == 0 && i + 1 < argc) {
            uart_dev = argv[++i];
            hil = 1;
        } else if (strcmp(argv[i], "--ctrl") == 0 && i + 1 < argc)
            ctrl = argv[++i];
        else if (strcmp(argv[i], "--cenario") == 0 && i + 1 < argc)
            cen = argv[++i];
        else if (strcmp(argv[i], "--rho") == 0 && i + 1 < argc)
            g_rho_ov = atof(argv[++i]);
        else if (strcmp(argv[i], "--max-iter") == 0 && i + 1 < argc)
            g_iter_ov = atoi(argv[++i]);
        else if (strcmp(argv[i], "--diag-admm") == 0)
            g_diag = 1;
        else if (strcmp(argv[i], "--dump-qp") == 0 && i + 1 < argc)
            g_dump_dir = argv[++i];
        else if (strcmp(argv[i], "--trace-csv") == 0 && i + 1 < argc)
            g_trace_csv = argv[++i];
        else if (strcmp(argv[i], "--from-state") == 0 && i + 1 < argc)
            g_state_path = argv[++i];
        else if (strcmp(argv[i], "--qp-solver") == 0 && i + 1 < argc) {
            if (strcmp(argv[i + 1], "admm") == 0) qp_engine_set(QP_ENG_ADMM);
            else if (strcmp(argv[i + 1], "admm_hist") == 0) qp_engine_set(QP_ENG_ADMM_HIST);
            else if (strcmp(argv[i + 1], "osqp") == 0) qp_engine_set(QP_ENG_OSQP);
            else if (strcmp(argv[i + 1], "qpoases") == 0) qp_engine_set(QP_ENG_QPOASES);
            else {
                fprintf(stderr, "solver desconhecido: %s\n", argv[i + 1]);
                return 1;
            }
            i++;
        } else if (strcmp(argv[i], "--shadow-solver") == 0 && i + 1 < argc) {
            if (strcmp(argv[i + 1], "admm") == 0) qp_engine_set_shadow(QP_ENG_ADMM);
            else if (strcmp(argv[i + 1], "osqp") == 0) qp_engine_set_shadow(QP_ENG_OSQP);
            else if (strcmp(argv[i + 1], "qpoases") == 0) qp_engine_set_shadow(QP_ENG_QPOASES);
            else {
                fprintf(stderr, "shadow desconhecido: %s\n", argv[i + 1]);
                return 1;
            }
            i++;
        }
        else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage();
            return 0;
        }
    }

    if (g_state_path)
        return run_from_state(g_state_path);

    if (uart_dev) {
#ifndef _WIN32
        FILE *fp = uart_open(uart_dev);
        if (!fp)
            return 1;
        hil_loop_io(ctrl, fp, fp, 1);
        fclose(fp);
        return 0;
#else
        fprintf(stderr, "--hil-uart so no Linux/HPS\n");
        return 1;
#endif
    }

    if (hil) {
        hil_loop_io(ctrl, stdin, stdout, 0);
        return 0;
    }

    simular(ctrl, cen);
    return 0;
}
