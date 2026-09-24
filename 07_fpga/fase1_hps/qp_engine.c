#include "qp_engine.h"
#include "ems_param.h"
#include "ems_clock.h"
#include "qp_metrics.h"
#include <math.h>
#include <string.h>

#ifdef QP_DEFAULT_OSQP
static int g_engine = QP_ENG_OSQP;
#else
static int g_engine = QP_ENG_ADMM;
#endif
static int g_shadow = -1;

#ifndef QP_WITH_QPOASES
int qp_qpoases_solve(const double *P, const double *q, const double *A,
                     const double *l, const double *u, int n, int m,
                     int init_policy, QpSolveOut *out)
{
    (void)P; (void)q; (void)A; (void)l; (void)u;
    (void)n; (void)m; (void)init_policy;
    memset(out, 0, sizeof(*out));
    out->engine = QP_ENG_QPOASES;
    out->x_missing = 1;
    strncpy(out->native_name, "nao_compilado", sizeof(out->native_name) - 1);
    return -1;
}

void qp_qpoases_reset(void) {}
#endif

void qp_engine_set(int engine) { g_engine = engine; }
int qp_engine_get(void) { return g_engine; }
void qp_engine_set_shadow(int engine) { g_shadow = engine; }
int qp_engine_get_shadow(void) { return g_shadow; }

const char *qp_engine_name(int engine)
{
    if (engine == QP_ENG_ADMM) return "admm";
    if (engine == QP_ENG_ADMM_HIST) return "admm_hist";
    if (engine == QP_ENG_OSQP) return "osqp";
    if (engine == QP_ENG_QPOASES) return "qpoases";
    return "unknown";
}

void qp_engine_reset(void)
{
    qp_admm_reset_warm();
    qp_admm_hist_reset_warm();
    qp_osqp_reset();
    qp_qpoases_reset();
}

int qp_engine_accepted(const QpSolveOut *o)
{
    if (!o || o->x_missing)
        return 0;
    if (o->engine == QP_ENG_ADMM || o->engine == QP_ENG_ADMM_HIST)
        return o->native_status == QP_ADMM_CONV;
    if (o->engine == QP_ENG_OSQP)
        return o->native_status == 1;
    if (o->engine == QP_ENG_QPOASES)
        return o->native_status == 0;
    return 0;
}

static void from_admm(int hist, const double *P, const double *q,
                      const double *A, const double *l, const double *u,
                      int n, int m, int init_policy, QpSolveOut *out)
{
    QpAdmmReport r;
    double pri = 0.0;
    int n_iter = 0, rc;
    EmsParam p;
    double t0;
    memset(out, 0, sizeof(*out));
    out->engine = hist ? QP_ENG_ADMM_HIST : QP_ENG_ADMM;
    ems_param_fpga(&p);
    if (init_policy == QP_INIT_COLD) {
        if (hist)
            qp_admm_hist_reset_warm();
        else
            qp_admm_reset_warm();
    }
    t0 = ems_now_s();
    if (hist)
        rc = qp_admm_hist_solve(P, q, A, l, u, n, m, p.admm_rho, p.admm_max_iter,
                                out->x, &pri, &n_iter);
    else
        rc = qp_admm_solve(P, q, A, l, u, n, m, p.admm_rho, p.admm_max_iter,
                           out->x, &pri, &n_iter);
    out->t_solve = ems_now_s() - t0;
    out->t_total = out->t_solve;
    if (hist)
        qp_admm_hist_get_report(&r);
    else
        qp_admm_get_report(&r);
    out->native_status = rc;
    out->n_iter = n_iter;
    out->obj = r.cost;
    out->x_missing = (rc == QP_ADMM_BAD_INPUT);
    if (rc == QP_ADMM_CONV)
        strncpy(out->native_name, "convergencia", sizeof(out->native_name) - 1);
    else if (rc == QP_ADMM_ITER_LIMIT)
        strncpy(out->native_name, "limite_iter", sizeof(out->native_name) - 1);
    else if (rc == QP_ADMM_CHOL)
        strncpy(out->native_name, "falha_fatoracao", sizeof(out->native_name) - 1);
    else if (rc == QP_ADMM_BAD_INPUT) {
        strncpy(out->native_name, "entrada_invalida", sizeof(out->native_name) - 1);
        out->x_missing = 1;
    } else if (rc == QP_ADMM_ALIAS)
        strncpy(out->native_name, "alias_HK", sizeof(out->native_name) - 1);
    else
        strncpy(out->native_name, "desconhecido", sizeof(out->native_name) - 1);
    if (r.m > 0 && r.m <= EMS_NCONS_MAX)
        memcpy(out->lambda, r.lambda, sizeof(double) * (size_t)r.m);
    out->obj = r.cost;
}

int qp_engine_solve(const double *P, const double *q, const double *A,
                    const double *l, const double *u, int n, int m,
                    int init_policy, QpSolveOut *out)
{
    if (g_engine == QP_ENG_OSQP)
        return qp_osqp_solve(P, q, A, l, u, n, m, init_policy, out);
    if (g_engine == QP_ENG_QPOASES)
        return qp_qpoases_solve(P, q, A, l, u, n, m, init_policy, out);
    from_admm(g_engine == QP_ENG_ADMM_HIST, P, q, A, l, u, n, m, init_policy, out);
    return out->native_status;
}
