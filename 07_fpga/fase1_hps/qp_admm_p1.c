#include "qp_admm.h"
#include "ems_work.h"
#include "qp_metrics.h"
#include <math.h>
#include <string.h>
#ifdef __hal__
#include "system.h"
#include "altera_avalon_pio_regs.h"
static void admm_beat(unsigned v)
{
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_LED_BASE, v);
}
#else
static void admm_beat(unsigned v) { (void)v; }
#endif

static FILE *g_trace;
static int g_have_warm;
static int g_warm_n;
static double g_warm_x[EMS_NVAR];
static char g_dump_dir[260];
static int g_dump_k;
static int g_dump_force;
static int g_dump_fail_left;
static QpAdmmReport g_report;

static void dump_qp(const double *P, const double *q, const double *A,
                    const double *l, const double *u, const double *x,
                    int n, int m, int exitflag, double pri, int n_iter,
                    double rho)
{
    FILE *fp;
    char path[320];
    int i, j, do_dump;
    double cost;

    do_dump = 0;
    if (g_dump_dir[0] && g_dump_force)
        do_dump = 1;
    else if (g_dump_dir[0] && exitflag != 1 && g_dump_fail_left > 0) {
        do_dump = 1;
        g_dump_fail_left--;
    } else if (!g_dump_dir[0] && g_trace && g_dump_k == 0 && exitflag == 1) {
        snprintf(path, sizeof(path), "qp_k0_dump.txt");
        do_dump = 2;
    }
    if (!do_dump)
        return;
    if (do_dump == 1)
        snprintf(path, sizeof(path), "%s/qp_k%04d_exit%d.txt",
                 g_dump_dir, g_dump_k, exitflag);
    fp = fopen(path, "w");
    if (!fp)
        return;
    cost = qp_cost(P, q, x, n);
    fprintf(fp, "k %d\nn %d\nm %d\nexit %d\npri %.16g\nn_iter %d\nrho %.16g\ncost %.16g\n",
            g_dump_k, n, m, exitflag, pri, n_iter, rho, cost);
    fprintf(fp, "P\n");
    for (i = 0; i < n; ++i) {
        for (j = 0; j < n; ++j)
            fprintf(fp, "%.16g%s", P[i * n + j], (j + 1 < n) ? " " : "\n");
    }
    fprintf(fp, "q\n");
    for (i = 0; i < n; ++i)
        fprintf(fp, "%.16g\n", q[i]);
    fprintf(fp, "A\n");
    for (i = 0; i < m; ++i) {
        for (j = 0; j < n; ++j)
            fprintf(fp, "%.16g%s", A[i * n + j], (j + 1 < n) ? " " : "\n");
    }
    fprintf(fp, "l\n");
    for (i = 0; i < m; ++i)
        fprintf(fp, "%.16g\n", l[i]);
    fprintf(fp, "u\n");
    for (i = 0; i < m; ++i)
        fprintf(fp, "%.16g\n", u[i]);
    fprintf(fp, "x\n");
    for (i = 0; i < n; ++i)
        fprintf(fp, "%.16g\n", x[i]);
    fclose(fp);
}

void qp_admm_set_trace(FILE *fp)
{
    g_trace = fp;
}

void qp_admm_set_dump_dir(const char *dir)
{
    g_dump_dir[0] = 0;
    g_dump_fail_left = 6;
    if (dir && dir[0]) {
        strncpy(g_dump_dir, dir, sizeof(g_dump_dir) - 1);
        g_dump_dir[sizeof(g_dump_dir) - 1] = 0;
    }
}

void qp_admm_request_dump(int k, int force)
{
    g_dump_k = k;
    g_dump_force = force;
}

void qp_admm_reset_warm(void)
{
    g_have_warm = 0;
    g_dump_k = 0;
    g_dump_force = 0;
}

void qp_admm_get_report(QpAdmmReport *r)
{
    if (r)
        *r = g_report;
}

static void fill_report(const double *P, const double *q, const double *A,
                        const double *l, const double *u, const double *x,
                        const double *lambda, int n, int m, int status,
                        int n_iter, int n_rho, double pri, double dual,
                        double rho, double p0, double p1)
{
    memset(&g_report, 0, sizeof(g_report));
    g_report.status = status;
    g_report.n_iter = n_iter;
    g_report.n_rho_update = n_rho;
    g_report.pri_unscaled = pri;
    g_report.dual_admm = dual;
    g_report.rho = rho;
    g_report.p_fro_before = p0;
    g_report.p_fro_after = p1;
    g_report.n = n;
    g_report.m = m;
    if (lambda && m > 0)
        memcpy(g_report.lambda, lambda, sizeof(double) * (size_t)m);
    g_report.cost = qp_cost(P, q, x, n);
    g_report.u0 = (n > 0) ? x[0] : 0.0;
    qp_family_viol(A, l, u, x, n, m,
                   &g_report.viol_power_kw, &g_report.viol_cmd_kw,
                   &g_report.viol_ramp_kws, &g_report.viol_soc_pp);
    if (lambda)
        qp_stationarity(P, q, A, lambda, x, n, m,
                        &g_report.stat_abs, &g_report.stat_rel);
}

static int chol_decomp(double *L, int n)
{
    int i, j, k;
    for (i = 0; i < n; ++i) {
        for (j = 0; j <= i; ++j) {
            double s = L[i * n + j];
            for (k = 0; k < j; ++k)
                s -= L[i * n + k] * L[j * n + k];
            if (i == j) {
                if (s <= 1e-18)
                    return -1;
                L[i * n + j] = sqrt(s);
            } else {
                L[i * n + j] = s / L[j * n + j];
            }
        }
        for (j = i + 1; j < n; ++j)
            L[i * n + j] = 0.0;
    }
    return 0;
}

static void chol_solve(const double *L, const double *b, double *x, int n)
{
    int i, j;
    for (i = 0; i < n; ++i) {
        double s = b[i];
        for (j = 0; j < i; ++j)
            s -= L[i * n + j] * x[j];
        x[i] = s / L[i * n + i];
    }
    for (i = n - 1; i >= 0; --i) {
        double s = x[i];
        for (j = i + 1; j < n; ++j)
            s -= L[j * n + i] * x[j];
        x[i] = s / L[i * n + i];
    }
}

static double clip(double v, double lo, double hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static double pri_unscaled(const double *A, const double *l, const double *u,
                           const double *S, const double *x, double *Ax,
                           int n, int m)
{
    int p, j;
    double r = 0.0;
    for (p = 0; p < m; ++p) {
        double s = 0.0;
        for (j = 0; j < n; ++j)
            s += A[p * n + j] * x[j];
        Ax[p] = s;
        {
            double d = s - clip(s, l[p], u[p]);
            r += d * d;
        }
        (void)S;
    }
    return sqrt(r);
}

static double fro_abs(const double *M, int n)
{
    int i;
    double s = 0.0;
    for (i = 0; i < n * n; ++i)
        s += M[i] * M[i];
    return sqrt(s);
}

static void form_k(double *K, const double *P, const double *A, const double *S,
                   int n, int m, double rho, double sigma)
{
    int i, j, p;
    /* K e P devem ser buffers distintos. memset(K) nao pode apagar P. */
    memset(K, 0, sizeof(double) * n * n);
    for (i = 0; i < n; ++i) {
        admm_beat(8u | (unsigned)(i & 1));
        for (j = 0; j <= i; ++j) {
            double s = P[i * n + j];
            for (p = 0; p < m; ++p) {
                double ai = S[p] * A[p * n + i];
                double aj = S[p] * A[p * n + j];
                s += rho * ai * aj;
            }
            K[i * n + j] = s;
            K[j * n + i] = s;
        }
        K[i * n + i] += sigma;
    }
}

int qp_admm_solve(const double *P, const double *q, const double *A,
                  const double *l, const double *u,
                  int n, int m, double rho, int max_iter,
                  double *x, double *pri_res, int *n_iter)
{
    double *K = ems_K();
    double *work = ems_scratch();
    double *z, *y, *Ax, *rhs, *xk, *At_term, *S, *z_prev, *lambda, *dz;
    int i, p, j, iter, n_rho = 0;
    const double sigma = 1e-6;
    const double pri_tol = 1.0; /* guarda historica; nao afrouxar */
    const double stat_rel_tol = 1e-2;
    const double viol_p_tol = 1.0;
    const double viol_u_tol = 1.0;
    const double viol_r_tol = 1.0;
    const double viol_s_tol = 0.05;
    double rho_use, pri0, p_fro0, p_fro1, dual_admm = 0.0;
    int last = 0;

    memset(&g_report, 0, sizeof(g_report));
    if (n_iter)
        *n_iter = 0;
    if (n > EMS_NVAR || m > EMS_NCONS_MAX) {
        g_report.status = QP_ADMM_BAD_INPUT;
        return QP_ADMM_BAD_INPUT;
    }
    if (K == P) {
        g_report.status = QP_ADMM_ALIAS;
        return QP_ADMM_ALIAS;
    }
    if (rho <= 0.0)
        rho = 1.0;
    if (max_iter < 1)
        max_iter = 1;
    rho_use = rho;

    z = work;
    y = z + m;
    Ax = y + m;
    z_prev = Ax + m;
    S = z_prev + m;
    lambda = S + m;
    dz = lambda + m;
    rhs = dz + m;
    xk = rhs + n;
    At_term = xk + n;

    for (p = 0; p < m; ++p) {
        double nrm = 0.0;
        for (j = 0; j < n; ++j) {
            double a = fabs(A[p * n + j]);
            if (a > nrm)
                nrm = a;
        }
        if (nrm < 1.0)
            nrm = 1.0;
        S[p] = 1.0 / nrm;
    }

    p_fro0 = fro_abs(P, n);
    form_k(K, P, A, S, n, m, rho_use, sigma);
    p_fro1 = fro_abs(P, n);
    if (g_trace)
        fprintf(g_trace, "admm_Pfro before=%.6g after_form_k=%.6g K_is_P=%d\n",
                p_fro0, p_fro1, (K == P));
    if (chol_decomp(K, n) != 0) {
        g_report.status = QP_ADMM_CHOL;
        g_report.p_fro_before = p_fro0;
        g_report.p_fro_after = p_fro1;
        return QP_ADMM_CHOL;
    }

    memset(z, 0, sizeof(double) * m);
    memset(y, 0, sizeof(double) * m);
    /* Runner e dumps usam reset_warm: estado frio. Warm-start da malha so se
     * qp_admm_reset_warm nao foi chamado. */
    if (g_have_warm && g_warm_n == n)
        memcpy(xk, g_warm_x, sizeof(double) * n);
    else
        memset(xk, 0, sizeof(double) * n);

    for (iter = 0; iter < max_iter; ++iter) {
        admm_beat(8u | ((iter & 1u) ? 4u : 0u));
        for (i = 0; i < n; ++i) {
            double s = 0.0;
            for (p = 0; p < m; ++p)
                s += (S[p] * A[p * n + i]) * (z[p] - y[p]);
            At_term[i] = s;
            rhs[i] = sigma * xk[i] + rho_use * At_term[i] - q[i];
        }
        chol_solve(K, rhs, xk, n);

        memcpy(z_prev, z, sizeof(double) * m);
        {
            double pri_s = 0.0;
            for (p = 0; p < m; ++p) {
                double ax = 0.0;
                for (j = 0; j < n; ++j)
                    ax += A[p * n + j] * xk[j];
                Ax[p] = S[p] * ax;
                z[p] = clip(Ax[p] + y[p], S[p] * l[p], S[p] * u[p]);
                y[p] = y[p] + Ax[p] - z[p];
                lambda[p] = S[p] * y[p];
                {
                    double d = Ax[p] - z[p];
                    pri_s += d * d;
                }
                dz[p] = z[p] - z_prev[p];
            }
            /* residual de iteracao: || rho (SA)^T (z-z_prev) || */
            dual_admm = 0.0;
            for (i = 0; i < n; ++i) {
                double s = 0.0;
                for (p = 0; p < m; ++p)
                    s += (S[p] * A[p * n + i]) * dz[p];
                s *= rho_use;
                dual_admm += s * s;
            }
            dual_admm = sqrt(dual_admm);
            pri0 = pri_unscaled(A, l, u, S, xk, Ax, n, m);
            last = iter + 1;
            memcpy(x, xk, sizeof(double) * n);
            fill_report(P, q, A, l, u, x, lambda, n, m, 0, last, n_rho,
                        pri0, dual_admm, rho_use, p_fro0, p_fro1);
            if (g_trace)
                fprintf(g_trace,
                        "admm_iter %d rho=%.4g pri=%.6g dual=%.6g stat_rel=%.6g\n",
                        last, rho_use, pri0, dual_admm, g_report.stat_rel);

            {
                int pass_pri = (pri0 < pri_tol);
                int pass_stat = (g_report.stat_rel <= stat_rel_tol);
                int pass_fam = (g_report.viol_power_kw <= viol_p_tol &&
                                g_report.viol_cmd_kw <= viol_u_tol &&
                                g_report.viol_ramp_kws <= viol_r_tol &&
                                g_report.viol_soc_pp <= viol_s_tol);
                if (pass_pri && pass_stat && pass_fam) {
                    *pri_res = pri0;
                    if (n_iter)
                        *n_iter = last;
                    memcpy(g_warm_x, xk, sizeof(double) * n);
                    g_warm_n = n;
                    g_have_warm = 1;
                    g_report.status = QP_ADMM_CONV;
                    dump_qp(P, q, A, l, u, x, n, m, 1, pri0, last, rho_use);
                    return QP_ADMM_CONV;
                }
            }

            if ((iter % 8) == 7 && iter + 1 < max_iter) {
                /* Adaptacao rho (separada do criterio de parada):
                 * compara primal escalado ||SAx-z|| com dual_admm. */
                pri_s = sqrt(pri_s);
                if (pri_s > 10.0 * (dual_admm + 1e-12) && rho_use < 1e6) {
                    double fct = 2.0;
                    for (p = 0; p < m; ++p)
                        y[p] /= fct;
                    rho_use *= fct;
                    n_rho++;
                    form_k(K, P, A, S, n, m, rho_use, sigma);
                    if (chol_decomp(K, n) != 0) {
                        g_report.status = QP_ADMM_CHOL;
                        return QP_ADMM_CHOL;
                    }
                } else if (dual_admm > 10.0 * (pri_s + 1e-12) && rho_use > 1e-6) {
                    double fct = 2.0;
                    for (p = 0; p < m; ++p)
                        y[p] *= fct;
                    rho_use /= fct;
                    n_rho++;
                    form_k(K, P, A, S, n, m, rho_use, sigma);
                    if (chol_decomp(K, n) != 0) {
                        g_report.status = QP_ADMM_CHOL;
                        return QP_ADMM_CHOL;
                    }
                }
            }
        }
    }

    memcpy(x, xk, sizeof(double) * n);
    *pri_res = pri_unscaled(A, l, u, S, x, Ax, n, m);
    if (n_iter)
        *n_iter = last;
    memcpy(g_warm_x, xk, sizeof(double) * n);
    g_warm_n = n;
    g_have_warm = 1;
    fill_report(P, q, A, l, u, x, lambda, n, m, QP_ADMM_ITER_LIMIT, last, n_rho,
                *pri_res, dual_admm, rho_use, p_fro0, p_fro1);
    dump_qp(P, q, A, l, u, x, n, m, 0, *pri_res, last, rho_use);
    return QP_ADMM_ITER_LIMIT;
}

