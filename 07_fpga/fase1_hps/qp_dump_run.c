#include "qp_admm.h"
#include "qp_dump_io.h"
#include "qp_metrics.h"
#include "ems_param.h"
#include "ems_clock.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *status_name(int s)
{
    if (s == QP_ADMM_CONV) return "convergencia";
    if (s == QP_ADMM_ITER_LIMIT) return "limite_iter";
    if (s == QP_ADMM_CHOL) return "falha_fatoracao";
    if (s == QP_ADMM_ALIAS) return "alias_HK";
    if (s == QP_ADMM_BAD_INPUT) return "entrada_invalida";
    return "desconhecido";
}

static int run_one(const char *path, int max_iter, double rho, FILE *csv)
{
    QpDump d;
    QpAdmmReport r;
    double x[EMS_NVAR], pri = 0.0;
    int n_iter = 0, rc;
    double t0;

    if (qp_dump_load(path, &d) != 0) {
        fprintf(stderr, "falha ao ler %s\n", path);
        return 1;
    }
    qp_admm_reset_warm();
    t0 = ems_now_s();
    rc = qp_admm_solve(d.P, d.q, d.A, d.l, d.u, d.n, d.m, rho, max_iter,
                       x, &pri, &n_iter);
    qp_admm_get_report(&r);
    r.t_s = ems_now_s() - t0;
    if (r.t_s < 0.0)
        r.t_s = 0.0;
    printf("%s hash=%08lx n=%d m=%d status=%s(%d) iter=%d rho_upd=%d "
           "pri=%.4g dual=%.4g stat_abs=%.4g stat_rel=%.4g "
           "violP=%.4g violU=%.4g violR=%.4g violSOC=%.4g "
           "J=%.6g u0=%.6f Pfro %g->%g t=%.4g\n",
           path, qp_dump_hash(&d), d.n, d.m, status_name(r.status), rc,
           r.n_iter, r.n_rho_update, r.pri_unscaled, r.dual_admm,
           r.stat_abs, r.stat_rel, r.viol_power_kw, r.viol_cmd_kw,
           r.viol_ramp_kws, r.viol_soc_pp, r.cost, r.u0,
           r.p_fro_before, r.p_fro_after, r.t_s);
    if (csv)
        fprintf(csv,
                "%s,%08lx,%d,%d,%s,%d,%d,%d,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,%.8g,cold\n",
                path, qp_dump_hash(&d), d.n, d.m, status_name(r.status),
                r.status, r.n_iter, r.n_rho_update, r.pri_unscaled, r.dual_admm,
                r.stat_abs, r.stat_rel, r.viol_power_kw, r.viol_cmd_kw,
                r.viol_ramp_kws, r.viol_soc_pp, r.cost, r.u0,
                r.p_fro_before, r.p_fro_after, r.t_s);
    if (fabs(r.p_fro_before - r.p_fro_after) > 1e-9 * (1.0 + r.p_fro_before)) {
        fprintf(stderr, "FALHA Hessiana P alterada em %s\n", path);
        return 2;
    }
    return 0;
}

static int run_toy(int max_iter, double rho)
{
    /* min ||x-[1,1]||^2  <=> P=2I, q=-2*1, caixa larga. x*=(1,1), J=-2 */
    double P[4] = {2, 0, 0, 2};
    double q[2] = {-2, -2};
    double A[4] = {1, 0, 0, 1};
    double l[2] = {-10, -10};
    double u[2] = {10, 10};
    double x[2], pri = 0.0;
    int n_iter = 0;
    QpAdmmReport r;
    qp_admm_reset_warm();
    qp_admm_solve(P, q, A, l, u, 2, 2, rho, max_iter, x, &pri, &n_iter);
    qp_admm_get_report(&r);
    printf("TOY status=%s x=(%.6f,%.6f) J=%.6g pri=%.4g stat_rel=%.4g "
           "Pfro %g->%g (esperado x=1,1 J=-2)\n",
           status_name(r.status), x[0], x[1], r.cost, r.pri_unscaled,
           r.stat_rel, r.p_fro_before, r.p_fro_after);
    if (fabs(x[0] - 1.0) > 2e-2 || fabs(x[1] - 1.0) > 2e-2)
        return 3;
    if (fabs(r.p_fro_before - r.p_fro_after) > 1e-12)
        return 2;
    return 0;
}

int main(int argc, char **argv)
{
    int i, max_iter = 80, rc = 0, toy = 0;
    double rho = 1.0;
    const char *csv_path = NULL;
    FILE *csv = NULL;
    EmsParam p;

    ems_param_fpga(&p);
    max_iter = p.admm_max_iter;
    rho = p.admm_rho;

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--max-iter") == 0 && i + 1 < argc)
            max_iter = atoi(argv[++i]);
        else if (strcmp(argv[i], "--rho") == 0 && i + 1 < argc)
            rho = atof(argv[++i]);
        else if (strcmp(argv[i], "--csv") == 0 && i + 1 < argc)
            csv_path = argv[++i];
        else if (strcmp(argv[i], "--toy") == 0)
            toy = 1;
        else if (argv[i][0] == '-') {
            fprintf(stderr, "uso: qp_dump_run [--toy] [--max-iter N] [--rho R] "
                            "[--csv FILE] dump.txt ...\n");
            return 1;
        } else
            break;
    }
    if (csv_path) {
        csv = fopen(csv_path, "w");
        if (!csv)
            return 1;
        fprintf(csv, "file,hash,n,m,status_name,status,n_iter,n_rho,pri,dual_admm,"
                     "stat_abs,stat_rel,viol_power,viol_cmd,viol_ramp,viol_soc,"
                     "cost,u0,p_fro_before,p_fro_after,t_s,init\n");
    }
    if (toy)
        rc |= run_toy(max_iter, rho);
    for (; i < argc; ++i)
        rc |= run_one(argv[i], max_iter, rho, csv);
    if (csv)
        fclose(csv);
    return rc ? 1 : 0;
}
