#include "ems_param.h"
#include "planta_bess.h"
#include "controle_heuristico.h"
#include "controle_mpc_fpga.h"
#include "gera_cenario.h"
#include "ems_protocol.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NMAX 4096

static void simular(const char *ctrl, const char *cenario, int hil_stdio)
{
    EmsParam param;
    double Pload[NMAX], Pmax[NMAX];
    int grid[NMAX];
    int N, k;
    double SOC, PBESS, uref, Psrc, Pnao_max;
    int n_fb, n_evt;
    double tqp_sum, tqp_max;
    FILE *fcsv;

    ems_param_fpga(&param);
    if (gera_cenario(cenario, &param, Pload, Pmax, grid, &N) != 0 || N > NMAX) {
        fprintf(stderr, "cenario invalido ou N grande\n");
        exit(1);
    }

    SOC = param.SOC_ref;
    PBESS = 0.0;
    uref = 0.0;
    Psrc = Pload[0];
    Pnao_max = 0.0;
    n_fb = 0;
    n_evt = 0;
    tqp_sum = 0.0;
    tqp_max = 0.0;

    if (hil_stdio) {
        char line[4096];
        while (fgets(line, sizeof(line), stdin)) {
            HilReq req;
            HilRsp rsp;
            MpcInfo inf;
            if (ems_parse_req(line, &req) != 0) {
                printf("ERR parse\n");
                fflush(stdout);
                continue;
            }
            if (strcmp(ctrl, "heur") == 0) {
                rsp.PBESS_ref = controle_heuristico(req.Pload[0], req.Pmax[0],
                                                    req.grid[0], req.SOC, &param);
                rsp.exitflag = 1;
                rsp.fallback = 0;
                rsp.evento = 0;
                rsp.t_us = 0;
            } else if (strcmp(ctrl, "heur_fs") == 0) {
                int gtmp[EMS_NP];
                int i;
                for (i = 0; i < req.Np; ++i)
                    gtmp[i] = req.grid[i];
                rsp.PBESS_ref = controle_heuristico_foresight(
                    0, req.SOC, req.uref, req.Pload, req.Pmax, gtmp, req.Np, &param);
                rsp.exitflag = 1;
                rsp.fallback = 0;
                rsp.evento = 0;
                rsp.t_us = 0;
            } else {
                int gtmp[EMS_NP];
                int i;
                for (i = 0; i < req.Np; ++i)
                    gtmp[i] = req.grid[i];
                inf = controle_mpc_fpga(0, req.SOC, req.PBESS, req.uref, req.Psrc_ant,
                                        req.Pload, req.Pmax, gtmp, req.Np, &param);
                rsp.PBESS_ref = inf.PBESS_ref;
                rsp.exitflag = inf.exitflag;
                rsp.fallback = inf.usou_fallback;
                rsp.evento = inf.modo_evento;
                rsp.t_us = (unsigned long)(inf.tempo_qp_s * 1e6);
            }
            ems_print_rsp(&rsp);
            fflush(stdout);
        }
        return;
    }

    for (k = 0; k < N - 1; ++k) {
        double u;
        PlantaOut po;
        if (strcmp(ctrl, "heur") == 0) {
            u = controle_heuristico(Pload[k], Pmax[k], grid[k], SOC, &param);
        } else if (strcmp(ctrl, "heur_fs") == 0) {
            u = controle_heuristico_foresight(k, SOC, uref, Pload, Pmax, grid, N, &param);
        } else {
            MpcInfo inf = controle_mpc_fpga(k, SOC, PBESS, uref, Psrc,
                                            Pload, Pmax, grid, N, &param);
            u = inf.PBESS_ref;
            n_fb += inf.usou_fallback;
            n_evt += inf.modo_evento;
            tqp_sum += inf.tempo_qp_s;
            if (inf.tempo_qp_s > tqp_max)
                tqp_max = inf.tempo_qp_s;
        }
        po = planta_bess(SOC, PBESS, u, Pload[k], Pmax[k], grid[k], &param);
        SOC = po.SOC_next;
        PBESS = po.PBESS_next;
        Psrc = po.Psource;
        uref = u;
        if (po.Pnao > Pnao_max)
            Pnao_max = po.Pnao;
    }

    printf("ctrl=%s cenario=%s Pnao_max=%.6f SOC_final=%.6f fallback=%d evento=%d tqp_med=%.6f tqp_max=%.6f\n",
           ctrl, cenario, Pnao_max, SOC, n_fb, n_evt,
           (n_fb + 1) ? tqp_sum / (N - 1) : 0.0, tqp_max);

    fcsv = fopen("ems_golden_kpi.csv", "a");
    if (fcsv) {
        fprintf(fcsv, "%s,%s,%.6f,%.6f,%d,%d,%.6f,%.6f\n",
                ctrl, cenario, Pnao_max, SOC, n_fb, n_evt,
                tqp_sum / (N - 1), tqp_max);
        fclose(fcsv);
    }
}

int main(int argc, char **argv)
{
    const char *ctrl = "heur";
    const char *cen = "carga_faixas";
    int hil = 0;
    int i;
    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--hil") == 0)
            hil = 1;
        else if (strcmp(argv[i], "--ctrl") == 0 && i + 1 < argc)
            ctrl = argv[++i];
        else if (strcmp(argv[i], "--cenario") == 0 && i + 1 < argc)
            cen = argv[++i];
    }
    simular(ctrl, cen, hil);
    return 0;
}
