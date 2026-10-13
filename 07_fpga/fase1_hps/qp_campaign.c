#include "qp_engine.h"
#include "qp_dump_io.h"
#include "qp_sha256.h"
#include "qp_eval.h"
#include "qp_metrics.h"
#include "ems_param.h"
#include "ems_clock.h"
#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <dirent.h>
#endif

#define MAX_FILES 256
#define INF_BND 1e20

static int g_fail;
static const char *g_ref_dir;
static const char *g_write_xref;
static FILE *g_ref_src;

static void die_msg(const char *s)
{
    fprintf(stderr, "%s\n", s);
    g_fail = 1;
}

static int almost(double a, double b, double tol)
{
    return fabs(a - b) <= tol;
}

static int parse_engine(const char *s)
{
    if (strcmp(s, "admm") == 0) return QP_ENG_ADMM;
    if (strcmp(s, "admm_hist") == 0) return QP_ENG_ADMM_HIST;
    if (strcmp(s, "osqp") == 0) return QP_ENG_OSQP;
    if (strcmp(s, "qpoases") == 0) return QP_ENG_QPOASES;
    return -1;
}

static void csv_nan(FILE *fp, double v)
{
    if (v != v)
        fprintf(fp, ",");
    else
        fprintf(fp, ",%.8g", v);
}

static void write_row(FILE *csv, const char *file, const char *qid, int n, int m, int k,
                      const char *eng, const char *init, const QpSolveOut *so,
                      const QpEvalOut *ev)
{
    if (!csv)
        return;
    fprintf(csv, "%s,%s,%s,%d,%d,%d,%s,%d,%s,%d,%d,%d,%d,%d",
            eng, file, qid, n, m, k, init, so->native_status, so->native_name,
            so->n_iter, so->x_missing, ev->layout_ok, ev->pass_app, ev->pass_kkt);
    csv_nan(csv, ev->cost);
    csv_nan(csv, ev->u0);
    csv_nan(csv, ev->pri_inf);
    csv_nan(csv, ev->pri_rel);
    csv_nan(csv, ev->stat_abs);
    csv_nan(csv, ev->stat_rel);
    csv_nan(csv, ev->dual_feas_inf);
    csv_nan(csv, ev->dual_feas_rel);
    csv_nan(csv, ev->comp_inf);
    csv_nan(csv, ev->comp_rel);
    csv_nan(csv, ev->viol_power_kw);
    csv_nan(csv, ev->viol_cmd_kw);
    csv_nan(csv, ev->viol_ramp_kws);
    csv_nan(csv, ev->viol_soc_pp);
    csv_nan(csv, ev->du0);
    csv_nan(csv, ev->dJ_rel);
    fprintf(csv, ",%.8g,%.8g,%.8g,%.8g,%d\n",
            so->t_setup, so->t_update, so->t_solve, so->t_total, ev->has_ref);
}

static void csv_header(FILE *csv)
{
    fprintf(csv, "solver,file,qp_id,n,m,k,init,native_status,native_name,n_iter,"
                 "x_missing,layout_ok,pass_app,pass_kkt,cost,u0,pri_inf,pri_rel,"
                 "stat_abs,stat_rel,dual_feas_inf,dual_feas_rel,comp_inf,comp_rel,viol_power,viol_cmd,"
                 "viol_ramp,viol_soc,du0,dJ_rel,t_setup,t_update,t_solve,t_total,has_ref\n");
}

static void dump_basename(const char *path, char *out, int n)
{
    const char *s = path, *p;
    for (p = path; *p; ++p)
        if (*p == '/' || *p == '\\')
            s = p + 1;
    snprintf(out, (size_t)n, "%s", s);
}

static int read_xref_file(const char *path, double *x, int n)
{
    FILE *fp;
    int i;
    fp = fopen(path, "r");
    if (!fp)
        return 0;
    for (i = 0; i < n; ++i)
        if (fscanf(fp, "%lf", &x[i]) != 1) {
            fclose(fp);
            return 0;
        }
    fclose(fp);
    return 1;
}

static int load_xref(const char *dump_path, double *x, int n)
{
    char path[640], base[260];
    snprintf(path, sizeof(path), "%s.xref", dump_path);
    if (read_xref_file(path, x, n))
        return 1;
    if (g_ref_dir && g_ref_dir[0]) {
        dump_basename(dump_path, base, (int)sizeof(base));
        snprintf(path, sizeof(path), "%s/%s.xref", g_ref_dir, base);
        if (read_xref_file(path, x, n))
            return 1;
    }
    return 0;
}

static void maybe_write_xref(const char *dump_path, const double *x, int n,
                            int pass_kkt, const char *engine)
{
    char path[640], base[260];
    FILE *fp, *exist;
    int i;
    if (!g_write_xref || !g_write_xref[0] || !x || n <= 0)
        return;
    dump_basename(dump_path, base, (int)sizeof(base));
    snprintf(path, sizeof(path), "%s/%s.xref", g_write_xref, base);
    exist = fopen(path, "r");
    if (exist) {
        fclose(exist);
        if (g_ref_src)
            fprintf(g_ref_src, "%s,keep_existing,%s,pass_kkt=%d\n",
                    base, engine, pass_kkt);
        return;
    }
    if (!pass_kkt) {
        if (g_ref_src)
            fprintf(g_ref_src, "%s,skip_no_kkt,%s,pass_kkt=0\n", base, engine);
        return;
    }
    fp = fopen(path, "w");
    if (!fp)
        return;
    for (i = 0; i < n; ++i)
        fprintf(fp, "%.16g\n", x[i]);
    fclose(fp);
    if (g_ref_src)
        fprintf(g_ref_src, "%s,write,%s,pass_kkt=1\n", base, engine);
}

static void maybe_flip_lambda(const double *P, const double *q, const double *A,
                              const double *x, double *lambda, int n, int m)
{
    int i;
    double tmp[EMS_NCONS_MAX];
    double sa, sb, dummy;
    if (m > EMS_NCONS_MAX || m <= 0)
        return;
    memcpy(tmp, lambda, sizeof(double) * (size_t)m);
    for (i = 0; i < m; ++i)
        tmp[i] = -lambda[i];
    qp_stationarity(P, q, A, lambda, x, n, m, &sa, &dummy);
    qp_stationarity(P, q, A, tmp, x, n, m, &sb, &dummy);
    if (sb < sa)
        memcpy(lambda, tmp, sizeof(double) * (size_t)m);
}

static int run_one_dump(const char *path, int engine, int init_pol, FILE *csv)
{
    QpDump d;
    QpSolveOut so;
    QpEvalOut ev;
    char qid[65];
    double xref[EMS_NVAR];
    int has_ref;
    qp_engine_set(engine);
    if (init_pol == QP_INIT_COLD)
        qp_engine_reset();
    if (qp_dump_load(path, &d) != 0) {
        fprintf(stderr, "falha ao ler %s\n", path);
        return 1;
    }
    qp_id_sha256(d.P, d.q, d.A, d.l, d.u, d.n, d.m, qid);
    qp_engine_solve(d.P, d.q, d.A, d.l, d.u, d.n, d.m, init_pol, &so);
    if (!so.x_missing)
        maybe_flip_lambda(d.P, d.q, d.A, so.x, so.lambda, d.n, d.m);
    has_ref = load_xref(path, xref, d.n);
    qp_eval(d.P, d.q, d.A, d.l, d.u, so.x_missing ? NULL : so.x,
            so.x_missing ? NULL : so.lambda, d.n, d.m,
            has_ref ? xref : NULL, has_ref, &ev);
    printf("%s %s id=%.12s n=%d m=%d native=%s(%d) miss=%d kkt=%d app=%d "
           "pri=%.3g stat=%.3g u0=%.6g t=%.4g has_ref=%d du0=%.3g\n",
           qp_engine_name(engine), path, qid, d.n, d.m, so.native_name,
           so.native_status, so.x_missing, ev.pass_kkt, ev.pass_app,
           ev.pri_inf, ev.stat_rel, ev.u0, so.t_total, ev.has_ref, ev.du0);
    if (!so.x_missing)
        maybe_write_xref(path, so.x, d.n, ev.pass_kkt, qp_engine_name(engine));
    write_row(csv, path, qid, d.n, d.m, d.k, qp_engine_name(engine),
              init_pol == QP_INIT_COLD ? "cold" : "warm", &so, &ev);
    return 0;
}

/* ---- contracts ---- */
static int expect(int ok, const char *msg)
{
    if (!ok) {
        fprintf(stderr, "CONTRATO FALHOU: %s\n", msg);
        g_fail = 1;
        return 0;
    }
    printf("ok  %s\n", msg);
    return 1;
}

static int contract_layout_unknown(void)
{
    QpEvalOut ev;
    double P[1] = {2}, q[1] = {-2}, A[1] = {1}, l[1] = {-10}, u[1] = {10}, x[1] = {1}, lam[1] = {0};
    qp_eval(P, q, A, l, u, x, lam, 1, 1, NULL, 0, &ev);
    return expect(ev.layout_ok == 0 && ev.viol_power_kw != ev.viol_power_kw,
                  "layout desconhecido => familia NaN, nao zero");
}

static int contract_toy_box(int engine)
{
    double P[4] = {2, 0, 0, 2};
    double q[2] = {-2, -2};
    double A[4] = {1, 0, 0, 1};
    double l[2] = {-10, -10};
    double u[2] = {10, 10};
    QpSolveOut so;
    QpEvalOut ev;
    qp_engine_set(engine);
    qp_engine_reset();
    qp_engine_solve(P, q, A, l, u, 2, 2, QP_INIT_COLD, &so);
    if (so.x_missing)
        return expect(0, "toy box: x ausente");
    maybe_flip_lambda(P, q, A, so.x, so.lambda, 2, 2);
    qp_eval(P, q, A, l, u, so.x, so.lambda, 2, 2, NULL, 0, &ev);
    return expect(!so.x_missing && almost(so.x[0], 1.0, 2e-2) && almost(so.x[1], 1.0, 2e-2),
                  "toy box x~=(1,1)");
}

static int contract_active_lower(int engine)
{
    /* min 0.5 x^2  s.t. x >= 1  => x=1, lambda_A = -1 (Px+q+A'λ=0) */
    double P[1] = {1}, q[1] = {0}, A[1] = {1}, l[1] = {1}, u[1] = {INF_BND};
    QpSolveOut so;
    QpEvalOut ev;
    qp_engine_set(engine);
    qp_engine_reset();
    qp_engine_solve(P, q, A, l, u, 1, 1, QP_INIT_COLD, &so);
    if (so.x_missing)
        return expect(engine == QP_ENG_ADMM || engine == QP_ENG_ADMM_HIST,
                      "active lower: x ausente (admm pode falhar; libs nao)");
    maybe_flip_lambda(P, q, A, so.x, so.lambda, 1, 1);
    qp_eval(P, q, A, l, u, so.x, so.lambda, 1, 1, NULL, 0, &ev);
    return expect(almost(so.x[0], 1.0, 1e-3) && ev.pri_inf < 1e-4,
                  "active lower x=1 factivel");
}

static int contract_equality(int engine)
{
    double P[1] = {1}, q[1] = {0}, A[1] = {1}, l[1] = {2}, u[1] = {2};
    QpSolveOut so;
    qp_engine_set(engine);
    qp_engine_reset();
    qp_engine_solve(P, q, A, l, u, 1, 1, QP_INIT_COLD, &so);
    if (so.x_missing)
        return expect(0, "equality: x ausente");
    return expect(almost(so.x[0], 2.0, 1e-3), "equality x=2");
}

static int contract_infeasible(int engine)
{
    double P[1] = {1}, q[1] = {0}, A[1] = {1}, l[1] = {1}, u[1] = {0};
    QpSolveOut so;
    QpEvalOut ev;
    qp_engine_set(engine);
    qp_engine_reset();
    qp_engine_solve(P, q, A, l, u, 1, 1, QP_INIT_COLD, &so);
    qp_eval(P, q, A, l, u, so.x_missing ? NULL : so.x,
            so.x_missing ? NULL : so.lambda, 1, 1, NULL, 0, &ev);
    return expect(so.x_missing || !ev.pass_kkt,
                  "infeasible: avaliador nao certifica KKT");
}

static int contract_dim_change(int engine)
{
    double P1[1] = {1}, q1[1] = {0}, A1[1] = {1}, l1[1] = {-1}, u1[1] = {1};
    double P2[4] = {2, 0, 0, 2}, q2[2] = {-2, -2}, A2[4] = {1, 0, 0, 1};
    double l2[2] = {-10, -10}, u2[2] = {10, 10};
    QpSolveOut so;
    qp_engine_set(engine);
    qp_engine_reset();
    qp_engine_solve(P1, q1, A1, l1, u1, 1, 1, QP_INIT_WARM, &so);
    qp_engine_solve(P2, q2, A2, l2, u2, 2, 2, QP_INIT_WARM, &so);
    return expect(!so.x_missing && almost(so.x[0], 1.0, 5e-2),
                  "mudanca de dimensao reconstrói workspace");
}

static int contract_admm_rho(void)
{
    /* min 0.5 x^2 s.t. x>=1, rho in {0.1,1,10} — lambda = rho S y */
    double P[1] = {1}, q[1] = {0}, A[1] = {1}, l[1] = {1}, u[1] = {10};
    double rhos[3] = {0.1, 1.0, 10.0};
    int k, ok = 1;
    for (k = 0; k < 3; ++k) {
        double x[1], pri = 0.0;
        int n_iter = 0;
        QpAdmmReport r;
        QpEvalOut ev;
        qp_admm_reset_warm();
        qp_admm_solve(P, q, A, l, u, 1, 1, rhos[k], 200, x, &pri, &n_iter);
        qp_admm_get_report(&r);
        qp_eval(P, q, A, l, u, x, r.lambda, 1, 1, NULL, 0, &ev);
        printf("  rho=%.2g x=%.6g stat_rel=%.3g lambda=%.4g n_rho=%d status=%d\n",
               rhos[k], x[0], ev.stat_rel, r.lambda[0], r.n_rho_update, r.status);
        if (r.status == QP_ADMM_CONV && ev.stat_rel > 0.05)
            ok = 0;
    }
    return expect(ok, "ADMM lambda=rho*S*y com rho != 1 (se convergir, stat ok)");
}

static int contract_missing_x(void)
{
    QpEvalOut ev;
    qp_eval(NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 2, NULL, 0, &ev);
    return expect(ev.x_missing == 1 && ev.pass_kkt == 0 && ev.pass_app == 0,
                  "x ausente nao gera metricas aprovadas");
}

static int run_contracts(int engine)
{
    printf("=== contratos engine=%s ===\n", qp_engine_name(engine));
    contract_layout_unknown();
    contract_missing_x();
    contract_toy_box(engine);
    contract_active_lower(engine);
    contract_equality(engine);
    contract_infeasible(engine);
    contract_dim_change(engine);
    if (engine == QP_ENG_ADMM)
        contract_admm_rho();
    return g_fail;
}

static int list_txt(const char *dir, char paths[][520], int *n)
{
#ifdef _WIN32
    WIN32_FIND_DATAA fd;
    HANDLE h;
    char pat[540];
    snprintf(pat, sizeof(pat), "%s\\qp_k*.txt", dir);
    h = FindFirstFileA(pat, &fd);
    *n = 0;
    if (h == INVALID_HANDLE_VALUE)
        return -1;
    do {
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
            snprintf(paths[*n], 520, "%s\\%s", dir, fd.cFileName);
            (*n)++;
            if (*n >= MAX_FILES)
                break;
        }
    } while (FindNextFileA(h, &fd));
    FindClose(h);
    return 0;
#else
    DIR *dp;
    struct dirent *de;
    size_t nlen;
    *n = 0;
    dp = opendir(dir);
    if (!dp)
        return -1;
    while ((de = readdir(dp)) != NULL) {
        nlen = strlen(de->d_name);
        if (nlen < 8 || strncmp(de->d_name, "qp_k", 4) != 0)
            continue;
        if (strcmp(de->d_name + nlen - 4, ".txt") != 0)
            continue;
        snprintf(paths[*n], 520, "%s/%s", dir, de->d_name);
        (*n)++;
        if (*n >= MAX_FILES)
            break;
    }
    closedir(dp);
    return (*n > 0) ? 0 : -1;
#endif
}

static int cmpstr(const void *a, const void *b)
{
    return strcmp((const char *)a, (const char *)b);
}

static int run_inventory(const char *dir, FILE *out)
{
    char paths[MAX_FILES][520];
    char ids[MAX_FILES][65];
    int n = 0, i, j;
    if (list_txt(dir, paths, &n) != 0) {
        fprintf(stderr, "sem dumps em %s\n", dir);
        return 1;
    }
    qsort(paths, (size_t)n, 520, cmpstr);
    fprintf(out, "file,k,n,m,qp_id,dup_of\n");
    for (i = 0; i < n; ++i) {
        QpDump d;
        if (qp_dump_load(paths[i], &d) != 0)
            continue;
        qp_id_sha256(d.P, d.q, d.A, d.l, d.u, d.n, d.m, ids[i]);
        fprintf(out, "%s,%d,%d,%d,%s,", paths[i], d.k, d.n, d.m, ids[i]);
        for (j = 0; j < i; ++j)
            if (strcmp(ids[i], ids[j]) == 0) {
                fprintf(out, "%s", paths[j]);
                break;
            }
        fprintf(out, "\n");
        printf("%s k=%d %s%s\n", paths[i], d.k, ids[i],
               (j < i) ? " DUP" : "");
    }
    return 0;
}

static int cmp_double(const void *a, const void *b)
{
    double da = *(const double *)a, db = *(const double *)b;
    return (da > db) - (da < db);
}

static void percentiles(double *v, int n, double *med, double *p95, double *mx)
{
    qsort(v, (size_t)n, sizeof(double), cmp_double);
    *med = v[n / 2];
    *p95 = v[(int)(0.95 * (n - 1))];
    *mx = v[n - 1];
}

static int run_timing(const char *path, int engine, FILE *out, int warmup, int reps)
{
    QpDump d;
    QpSolveOut so;
    QpEvalOut ev;
    double *ts, *tu, *tv, *tt;
    int i, n_ok = 0;
    double med, p95, mx;
    const char *note;
    if (qp_dump_load(path, &d) != 0)
        return 1;
    ts = (double *)calloc((size_t)reps, sizeof(double));
    tu = (double *)calloc((size_t)reps, sizeof(double));
    tv = (double *)calloc((size_t)reps, sizeof(double));
    tt = (double *)calloc((size_t)reps, sizeof(double));
    qp_engine_set(engine);
    for (i = 0; i < warmup; ++i) {
        qp_engine_reset();
        qp_engine_solve(d.P, d.q, d.A, d.l, d.u, d.n, d.m, QP_INIT_COLD, &so);
    }
    memset(&ev, 0, sizeof(ev));
    for (i = 0; i < reps; ++i) {
        qp_engine_reset();
        qp_engine_solve(d.P, d.q, d.A, d.l, d.u, d.n, d.m, QP_INIT_COLD, &so);
        ts[i] = so.t_setup;
        tu[i] = so.t_update;
        tv[i] = so.t_solve;
        tt[i] = so.t_total;
        if (!so.x_missing)
            maybe_flip_lambda(d.P, d.q, d.A, so.x, so.lambda, d.n, d.m);
        qp_eval(d.P, d.q, d.A, d.l, d.u, so.x_missing ? NULL : so.x,
                so.x_missing ? NULL : so.lambda, d.n, d.m, NULL, 0, &ev);
        if (qp_engine_accepted(&so) && ev.pass_app)
            n_ok++;
        else
            fprintf(out, "%s,%s,FAIL,iter=%d,native=%s,app=%d,kkt=%d\n",
                    qp_engine_name(engine), path, so.n_iter, so.native_name,
                    ev.pass_app, ev.pass_kkt);
    }
    note = (n_ok == reps) ? "ok" : "FAIL";
    percentiles(tt, reps, &med, &p95, &mx);
    fprintf(out, "%s,%s,total,%.8g,%.8g,%.8g,%s\n",
            qp_engine_name(engine), path, med, p95, mx, note);
    percentiles(ts, reps, &med, &p95, &mx);
    fprintf(out, "%s,%s,setup,%.8g,%.8g,%.8g,\n", qp_engine_name(engine), path, med, p95, mx);
    percentiles(tv, reps, &med, &p95, &mx);
    fprintf(out, "%s,%s,solve,%.8g,%.8g,%.8g,\n", qp_engine_name(engine), path, med, p95, mx);
    printf("timing %s %s total med=%.4g p95=%.4g max=%.4g note=%s app=%d kkt=%d n_ok=%d/%d\n",
           qp_engine_name(engine), path, med, p95, mx, note, ev.pass_app, ev.pass_kkt,
           n_ok, reps);
    free(ts); free(tu); free(tv); free(tt);
    return 0;
}

static void usage(void)
{
    fprintf(stderr,
            "qp_campaign --contracts [--solver NAME]\n"
            "qp_campaign --inventory DIR --csv FILE\n"
            "qp_campaign --set DIR --solver NAME [--init cold|warm] --csv FILE [dumps...]\n"
            "qp_campaign --timing DUMP --solver NAME --csv FILE [--warmup 5] [--reps 100]\n"
            "  --ref-dir DIR       procura DUMP.xref e DIR/basename.xref\n"
            "  --write-xref DIR    grava x se pass_kkt e o arquivo ainda nao existe\n"
            "  --ref-source FILE   log de procedencia das referencias\n"
            "solvers: admm admm_hist osqp qpoases all\n");
}

int main(int argc, char **argv)
{
    int i, contracts = 0, inventory = 0, timing = 0;
    int engine = QP_ENG_ADMM, all = 0, init_pol = QP_INIT_COLD;
    int warmup = 5, reps = 100;
    const char *dir = NULL, *csv_path = NULL, *timing_dump = NULL;
    FILE *csv = NULL;
    int engines[4];
    int neng = 1;

    engines[0] = QP_ENG_ADMM;
    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--contracts") == 0)
            contracts = 1;
        else if (strcmp(argv[i], "--inventory") == 0 && i + 1 < argc) {
            inventory = 1;
            dir = argv[++i];
        } else if (strcmp(argv[i], "--set") == 0 && i + 1 < argc)
            dir = argv[++i];
        else if (strcmp(argv[i], "--solver") == 0 && i + 1 < argc) {
            if (strcmp(argv[i + 1], "all") == 0) {
                all = 1;
                i++;
            } else {
                engine = parse_engine(argv[++i]);
                if (engine < 0) {
                    usage();
                    return 1;
                }
            }
        } else if (strcmp(argv[i], "--init") == 0 && i + 1 < argc) {
            init_pol = (strcmp(argv[++i], "warm") == 0) ? QP_INIT_WARM : QP_INIT_COLD;
        } else if (strcmp(argv[i], "--csv") == 0 && i + 1 < argc)
            csv_path = argv[++i];
        else if (strcmp(argv[i], "--timing") == 0 && i + 1 < argc) {
            timing = 1;
            timing_dump = argv[++i];
        }         else if (strcmp(argv[i], "--warmup") == 0 && i + 1 < argc)
            warmup = atoi(argv[++i]);
        else if (strcmp(argv[i], "--reps") == 0 && i + 1 < argc)
            reps = atoi(argv[++i]);
        else if (strcmp(argv[i], "--ref-dir") == 0 && i + 1 < argc)
            g_ref_dir = argv[++i];
        else if (strcmp(argv[i], "--write-xref") == 0 && i + 1 < argc)
            g_write_xref = argv[++i];
        else if (strcmp(argv[i], "--ref-source") == 0 && i + 1 < argc) {
            g_ref_src = fopen(argv[++i], "a");
            if (g_ref_src)
                fprintf(g_ref_src, "file,action,solver,detail\n");
        }
        else if (argv[i][0] == '-') {
            usage();
            return 1;
        } else
            break;
    }
    if (all) {
        engines[0] = QP_ENG_ADMM;
        engines[1] = QP_ENG_ADMM_HIST;
        engines[2] = QP_ENG_OSQP;
        engines[3] = QP_ENG_QPOASES;
        neng = 4;
    } else {
        engines[0] = engine;
        neng = 1;
    }
    if (contracts) {
        for (i = 0; i < neng; ++i)
            run_contracts(engines[i]);
        if (g_ref_src)
            fclose(g_ref_src);
        return g_fail ? 1 : 0;
    }
    if (inventory) {
        csv = csv_path ? fopen(csv_path, "w") : stdout;
        if (!csv)
            return 1;
        run_inventory(dir, csv);
        if (csv_path)
            fclose(csv);
        if (g_ref_src)
            fclose(g_ref_src);
        return 0;
    }
    if (timing) {
        csv = csv_path ? fopen(csv_path, "w") : stdout;
        if (!csv)
            return 1;
        fprintf(csv, "solver,file,phase,median,p95,max,note\n");
        for (i = 0; i < neng; ++i)
            run_timing(timing_dump, engines[i], csv, warmup, reps);
        if (csv_path)
            fclose(csv);
        if (g_ref_src)
            fclose(g_ref_src);
        return 0;
    }
    if (csv_path) {
        csv = fopen(csv_path, "w");
        if (!csv)
            return 1;
        csv_header(csv);
    }
    {
        char paths[MAX_FILES][520];
        int nd = 0, e, k;
        if (dir)
            list_txt(dir, paths, &nd);
        for (; i < argc && nd < MAX_FILES; ++i) {
            snprintf(paths[nd], 520, "%s", argv[i]);
            nd++;
        }
        qsort(paths, (size_t)nd, 520, cmpstr);
        for (e = 0; e < neng; ++e)
            for (k = 0; k < nd; ++k)
                run_one_dump(paths[k], engines[e], init_pol, csv);
    }
    if (csv)
        fclose(csv);
    if (g_ref_src)
        fclose(g_ref_src);
    return g_fail ? 1 : 0;
}
