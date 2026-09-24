#include "qp_eval.h"
#include "qp_metrics.h"
#include <math.h>
#include <string.h>

#ifndef QP_KKT_TOL
#define QP_KKT_TOL 1e-6
#endif

/* KKT no QP l <= A x <= u, multiplicador combinado y (OSQP):
 *   y = y_u - y_l,  y_u,y_l >= 0.
 * Primal por linha: max(0, Ax-u, l-Ax), relativo a
 *   max(1, |Ax|, |l| se finito, |u| se finito).
 * Complementaridade sempre: y_l * max(Ax-l,0) e y_u * max(u-Ax,0)
 *   (nao classifica conjunto ativo por limiar).
 * Dual-cone so quando um lado e infinito: ambos infinitos => y=0;
 *   so inferior => y<=0; so superior => y>=0; ambos finitos => livre.
 */
static double vmax(double a, double b) { return a > b ? a : b; }
static double vabs(double a) { return a >= 0.0 ? a : -a; }

static int is_pinf(double v) { return !isfinite(v) || v > 1e19; }
static int is_ninf(double v) { return !isfinite(v) || v < -1e19; }

int qp_eval_layout(int n, int m)
{
    return qp_infer_horizon(n, m, NULL, NULL) ? QP_EVAL_LAYOUT_OK : QP_EVAL_LAYOUT_UNKNOWN;
}

int qp_eval(const double *P, const double *q, const double *A,
            const double *l, const double *u, const double *x,
            const double *lambda, int n, int m,
            const double *x_ref, int has_ref, QpEvalOut *o)
{
    int j, p;
    double lam_inf = 0.0, pri = 0.0, pri_rel = 0.0, dual = 0.0, comp = 0.0;
    const double eq_eps = 1e-12;

    memset(o, 0, sizeof(*o));
    o->layout_ok = qp_eval_layout(n, m);
    o->du0 = NAN;
    o->dJ_rel = NAN;
    o->has_ref = 0;
    if (!x) {
        o->x_missing = 1;
        o->pass_app = 0;
        o->pass_kkt = 0;
        return 0;
    }
    o->cost = qp_cost(P, q, x, n);
    o->u0 = (n > 0) ? x[0] : 0.0;

    if (o->layout_ok)
        qp_family_viol(A, l, u, x, n, m,
                       &o->viol_power_kw, &o->viol_cmd_kw,
                       &o->viol_ramp_kws, &o->viol_soc_pp);
    else {
        o->viol_power_kw = NAN;
        o->viol_cmd_kw = NAN;
        o->viol_ramp_kws = NAN;
        o->viol_soc_pp = NAN;
    }

    if (lambda)
        qp_stationarity(P, q, A, lambda, x, n, m, &o->stat_abs, &o->stat_rel);
    else {
        o->stat_abs = NAN;
        o->stat_rel = NAN;
    }

    for (p = 0; p < m; ++p) {
        double ax = 0.0, sl, su, yi, pri_p, scale, yu, yl;
        for (j = 0; j < n; ++j)
            ax += A[p * n + j] * x[j];
        sl = ax - l[p];
        su = u[p] - ax;
        pri_p = 0.0;
        if (sl < 0.0)
            pri_p = vmax(pri_p, -sl);
        if (su < 0.0)
            pri_p = vmax(pri_p, -su);
        pri = vmax(pri, pri_p);
        scale = 1.0;
        scale = vmax(scale, vabs(ax));
        if (!is_ninf(l[p]) && !is_pinf(l[p]))
            scale = vmax(scale, vabs(l[p]));
        if (!is_ninf(u[p]) && !is_pinf(u[p]))
            scale = vmax(scale, vabs(u[p]));
        pri_rel = vmax(pri_rel, pri_p / scale);

        yi = lambda ? lambda[p] : 0.0;
        lam_inf = vmax(lam_inf, vabs(yi));
        if (!lambda)
            continue;
        if (vabs(u[p] - l[p]) < eq_eps)
            continue;
        yu = yi > 0.0 ? yi : 0.0;
        yl = yi < 0.0 ? -yi : 0.0;
        {
            double slp = sl > 0.0 ? sl : 0.0;
            double sup = su > 0.0 ? su : 0.0;
            comp = vmax(comp, yl * slp);
            comp = vmax(comp, yu * sup);
        }
        if (is_ninf(l[p]) && is_pinf(u[p]))
            dual = vmax(dual, vabs(yi));
        else if (is_ninf(l[p])) {
            if (yi < 0.0)
                dual = vmax(dual, -yi);
        } else if (is_pinf(u[p])) {
            if (yi > 0.0)
                dual = vmax(dual, yi);
        }
    }
    o->pri_inf = pri;
    o->pri_rel = pri_rel;
    o->dual_feas_inf = lambda ? dual : NAN;
    o->dual_feas_rel = lambda ? dual / vmax(1.0, lam_inf) : NAN;
    o->comp_inf = lambda ? comp : NAN;
    o->comp_rel = lambda ? comp / vmax(1.0, lam_inf) : NAN;

    o->pass_kkt = 0;
    if (lambda && o->pri_rel <= QP_KKT_TOL && o->stat_rel <= QP_KKT_TOL &&
        o->dual_feas_rel <= QP_KKT_TOL && o->comp_rel <= QP_KKT_TOL)
        o->pass_kkt = 1;

    o->pass_app = 0;
    if (o->layout_ok &&
        o->viol_power_kw <= 1.0 && o->viol_cmd_kw <= 1.0 &&
        o->viol_ramp_kws <= 1.0 && o->viol_soc_pp <= 0.05 &&
        o->stat_rel <= 1e-2)
        o->pass_app = 1;

    if (has_ref && x_ref) {
        double jref = qp_cost(P, q, x_ref, n);
        o->has_ref = 1;
        o->du0 = vabs(x[0] - x_ref[0]);
        o->dJ_rel = vabs(o->cost - jref) / (1.0 + vabs(jref));
        if (!(o->du0 <= 0.10 && o->dJ_rel <= 1e-3))
            o->pass_app = 0;
    }
    return 0;
}
