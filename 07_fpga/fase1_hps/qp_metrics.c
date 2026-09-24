#include "qp_metrics.h"
#include "ems_types.h"
#include <math.h>

double qp_cost(const double *P, const double *q, const double *x, int n)
{
    int i, j;
    double s = 0.0;
    for (i = 0; i < n; ++i) {
        s += q[i] * x[i];
        for (j = 0; j < n; ++j)
            s += 0.5 * x[i] * P[i * n + j] * x[j];
    }
    return s;
}

static double row_viol(const double *A, const double *l, const double *u,
                       const double *x, int n, int p)
{
    int j;
    double ax = 0.0;
    for (j = 0; j < n; ++j)
        ax += A[p * n + j] * x[j];
    {
        double hi = ax - u[p];
        double lo = l[p] - ax;
        if (hi < 0.0) hi = 0.0;
        if (lo < 0.0) lo = 0.0;
        return (hi > lo) ? hi : lo;
    }
}

int qp_infer_horizon(int n, int m, int *Np, int *Nc)
{
    int np, nc;
    for (np = EMS_NP; np >= 1; --np) {
        nc = n - 5 * np;
        if (nc >= 1 && nc <= EMS_NC && nc <= np &&
            m >= 8 * np + n && m <= EMS_NCONS_MAX) {
            if (Np) *Np = np;
            if (Nc) *Nc = nc;
            return 1;
        }
    }
    return 0;
}

void qp_family_viol(const double *A, const double *l, const double *u,
                    const double *x, int n, int m,
                    double *power_kw, double *cmd_kw,
                    double *ramp_kws, double *soc_pp)
{
    int p, Np, Nc, extra, b0;
    double vp = 0.0, vc = 0.0, vr = 0.0, vs = 0.0;

    *power_kw = 0.0;
    *cmd_kw = 0.0;
    *ramp_kws = 0.0;
    *soc_pp = 0.0;
    if (!qp_infer_horizon(n, m, &Np, &Nc))
        return;
    extra = m - 8 * Np - n;
    if (extra < 0)
        extra = 0;
    b0 = 8 * Np + extra;

    for (p = 0; p < Np; ++p) {
        double v = row_viol(A, l, u, x, n, p);
        if (v > vp) vp = v;
    }
    for (p = Np; p < 5 * Np; ++p) {
        double v = row_viol(A, l, u, x, n, p);
        if (v > vc) vc = v;
    }
    for (p = 5 * Np; p < 7 * Np; ++p) {
        double v = row_viol(A, l, u, x, n, p);
        if (v > vs) vs = v;
    }
    for (p = 7 * Np; p < 8 * Np; ++p) {
        double v = row_viol(A, l, u, x, n, p);
        if (v > vc) vc = v;
    }
    for (p = 8 * Np; p < b0; ++p) {
        double v = row_viol(A, l, u, x, n, p);
        if (v > vc) vc = v;
    }
    for (p = 0; p < Nc && b0 + p < m; ++p) {
        double v = row_viol(A, l, u, x, n, b0 + p);
        if (v > vr) vr = v;
    }
    for (p = Nc; p < n && b0 + p < m; ++p) {
        double v = row_viol(A, l, u, x, n, b0 + p);
        if (p < Nc + Np) {
            if (v > vc) vc = v;
        }
    }
    *power_kw = vp;
    *cmd_kw = vc;
    *ramp_kws = vr;
    *soc_pp = vs;
}

void qp_stationarity(const double *P, const double *q, const double *A,
                     const double *lambda, const double *x,
                     int n, int m, double *stat_abs, double *stat_rel)
{
    int i, j, p;
    double num = 0.0, den = 0.0, qn = 0.0, pxn = 0.0;
    for (i = 0; i < n; ++i) {
        double px = 0.0, at = 0.0;
        for (j = 0; j < n; ++j)
            px += P[i * n + j] * x[j];
        for (p = 0; p < m; ++p)
            at += A[p * n + i] * lambda[p];
        {
            double g = px + q[i] + at;
            num += g * g;
        }
        qn += q[i] * q[i];
        pxn += px * px;
    }
    *stat_abs = sqrt(num);
    den = sqrt(qn) + sqrt(pxn);
    *stat_rel = (den > 1e-16) ? (*stat_abs / den) : *stat_abs;
}
