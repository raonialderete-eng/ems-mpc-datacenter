#include "qp_engine.h"
#include "ems_clock.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <osqp.h>

static OSQPSolver *g_solver;
static int g_n, g_m;
static OSQPInt *g_Pi, *g_Pp, *g_Ai, *g_Ap;
static OSQPFloat *g_Px, *g_Ax, *g_q, *g_l, *g_u;
static OSQPCscMatrix *g_Pcsc, *g_Acsc;

static void free_csc_bufs(void)
{
    free(g_Pi); free(g_Pp); free(g_Px);
    free(g_Ai); free(g_Ap); free(g_Ax);
    free(g_q); free(g_l); free(g_u);
    g_Pi = g_Pp = g_Ai = g_Ap = NULL;
    g_Px = g_Ax = g_q = g_l = g_u = NULL;
    g_Pcsc = NULL;
    g_Acsc = NULL;
}

void qp_osqp_reset(void)
{
    if (g_solver) {
        osqp_cleanup(g_solver);
        g_solver = NULL;
    }
    free_csc_bufs();
    g_n = g_m = 0;
}

static int dense_P_triu_csc(const double *P, int n, OSQPInt **p, OSQPInt **i,
                            OSQPFloat **x, OSQPInt *nnz)
{
    int col, row, k = 0, nz = 0;
    for (col = 0; col < n; ++col)
        for (row = 0; row <= col; ++row)
            if (P[row * n + col] != 0.0 || P[col * n + row] != 0.0)
                nz++;
    if (nz < n)
        nz = n; /* keep diagonal structure */
    *p = (OSQPInt *)malloc(sizeof(OSQPInt) * (size_t)(n + 1));
    *i = (OSQPInt *)malloc(sizeof(OSQPInt) * (size_t)nz);
    *x = (OSQPFloat *)malloc(sizeof(OSQPFloat) * (size_t)nz);
    if (!*p || !*i || !*x)
        return -1;
    k = 0;
    for (col = 0; col < n; ++col) {
        (*p)[col] = k;
        for (row = 0; row <= col; ++row) {
            double v = 0.5 * (P[row * n + col] + P[col * n + row]);
            if (row == col || v != 0.0) {
                (*i)[k] = row;
                (*x)[k] = (OSQPFloat)v;
                k++;
            }
        }
    }
    (*p)[n] = k;
    *nnz = k;
    return 0;
}

static int dense_A_csc(const double *A, int m, int n, OSQPInt **p, OSQPInt **i,
                       OSQPFloat **x, OSQPInt *nnz)
{
    int col, row, k = 0, nz = 0;
    for (col = 0; col < n; ++col)
        for (row = 0; row < m; ++row)
            if (A[row * n + col] != 0.0)
                nz++;
    if (nz < 1)
        nz = 1;
    *p = (OSQPInt *)malloc(sizeof(OSQPInt) * (size_t)(n + 1));
    *i = (OSQPInt *)malloc(sizeof(OSQPInt) * (size_t)nz);
    *x = (OSQPFloat *)malloc(sizeof(OSQPFloat) * (size_t)nz);
    if (!*p || !*i || !*x)
        return -1;
    k = 0;
    for (col = 0; col < n; ++col) {
        (*p)[col] = k;
        for (row = 0; row < m; ++row) {
            if (A[row * n + col] != 0.0) {
                (*i)[k] = row;
                (*x)[k] = (OSQPFloat)A[row * n + col];
                k++;
            }
        }
    }
    (*p)[n] = k;
    *nnz = (k > 0) ? k : 0;
    return 0;
}

static OSQPFloat clip_inf(double v, int lo)
{
    if (!isfinite(v) || v > 1e19)
        return lo ? -OSQP_INFTY : OSQP_INFTY;
    if (v < -1e19)
        return -OSQP_INFTY;
    return (OSQPFloat)v;
}

static void fill_settings(OSQPSettings *s)
{
    osqp_set_default_settings(s);
    s->eps_abs = 1e-6;
    s->eps_rel = 1e-6;
    s->max_iter = 10000;
    s->polishing = 1;
    s->verbose = 0;
    s->warm_starting = 1;
    s->linsys_solver = OSQP_DIRECT_SOLVER;
}

static const char *osqp_name(OSQPInt v)
{
    if (v == OSQP_SOLVED) return "solved";
    if (v == OSQP_SOLVED_INACCURATE) return "solved_inaccurate";
    if (v == OSQP_PRIMAL_INFEASIBLE) return "primal_infeasible";
    if (v == OSQP_PRIMAL_INFEASIBLE_INACCURATE) return "primal_infeasible_inaccurate";
    if (v == OSQP_DUAL_INFEASIBLE) return "dual_infeasible";
    if (v == OSQP_MAX_ITER_REACHED) return "max_iter";
    if (v == OSQP_NON_CVX) return "non_cvx";
    if (v == OSQP_UNSOLVED) return "unsolved";
    return "other";
}

int qp_osqp_solve(const double *P, const double *q, const double *A,
                  const double *l, const double *u, int n, int m,
                  int init_policy, QpSolveOut *out)
{
    OSQPInt nnzP = 0, nnzA = 0, rc;
    OSQPSettings settings;
    int i, rebuild;
    double t0, t1;

    memset(out, 0, sizeof(*out));
    out->engine = QP_ENG_OSQP;
    out->x_missing = 1;
    strncpy(out->native_name, "setup_fail", sizeof(out->native_name) - 1);

    rebuild = (g_solver == NULL) || (g_n != n) || (g_m != m) ||
              (init_policy == QP_INIT_COLD);
    t0 = ems_now_s();
    if (rebuild) {
        qp_osqp_reset();
        if (dense_P_triu_csc(P, n, &g_Pp, &g_Pi, &g_Px, &nnzP) != 0)
            return -1;
        if (dense_A_csc(A, m, n, &g_Ap, &g_Ai, &g_Ax, &nnzA) != 0)
            return -1;
        g_q = (OSQPFloat *)malloc(sizeof(OSQPFloat) * (size_t)n);
        g_l = (OSQPFloat *)malloc(sizeof(OSQPFloat) * (size_t)m);
        g_u = (OSQPFloat *)malloc(sizeof(OSQPFloat) * (size_t)m);
        if (!g_q || !g_l || !g_u)
            return -1;
        for (i = 0; i < n; ++i)
            g_q[i] = (OSQPFloat)q[i];
        for (i = 0; i < m; ++i) {
            g_l[i] = clip_inf(l[i], 1);
            g_u[i] = clip_inf(u[i], 0);
        }
        g_Pcsc = OSQPCscMatrix_new(n, n, nnzP, g_Px, g_Pi, g_Pp);
        g_Acsc = OSQPCscMatrix_new(m, n, nnzA, g_Ax, g_Ai, g_Ap);
        if (!g_Pcsc || !g_Acsc)
            return -1;
        fill_settings(&settings);
        rc = osqp_setup(&g_solver, g_Pcsc, g_q, g_Acsc, g_l, g_u, m, n, &settings);
        out->t_setup = ems_now_s() - t0;
        if (rc != 0 || !g_solver) {
            out->native_status = (int)rc;
            strncpy(out->native_name, "setup_fail", sizeof(out->native_name) - 1);
            return (int)rc;
        }
        g_n = n;
        g_m = m;
    } else {
        for (i = 0; i < n; ++i)
            g_q[i] = (OSQPFloat)q[i];
        for (i = 0; i < m; ++i) {
            g_l[i] = clip_inf(l[i], 1);
            g_u[i] = clip_inf(u[i], 0);
        }
        osqp_update_data_vec(g_solver, g_q, g_l, g_u);
        out->t_update = ems_now_s() - t0;
    }

    t1 = ems_now_s();
    rc = osqp_solve(g_solver);
    out->t_solve = ems_now_s() - t1;
    out->t_total = ems_now_s() - t0;
    out->native_status = g_solver->info ? (int)g_solver->info->status_val : (int)rc;
    strncpy(out->native_name, osqp_name(out->native_status), sizeof(out->native_name) - 1);
    out->n_iter = g_solver->info ? (int)g_solver->info->iter : 0;
    if (g_solver->solution && g_solver->solution->x &&
        (out->native_status == OSQP_SOLVED ||
         out->native_status == OSQP_SOLVED_INACCURATE)) {
        out->x_missing = 0;
        for (i = 0; i < n; ++i)
            out->x[i] = (double)g_solver->solution->x[i];
        if (g_solver->solution->y) {
            for (i = 0; i < m; ++i)
                out->lambda[i] = (double)g_solver->solution->y[i];
        }
        out->obj = g_solver->info ? (double)g_solver->info->obj_val : 0.0;
    }
    return 0;
}
