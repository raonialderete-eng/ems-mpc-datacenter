#include "qp_admm.h"
#include "ems_work.h"
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

static void matvec(const double *M, const double *x, double *y, int rows, int cols)
{
    int i, j;
    for (i = 0; i < rows; ++i) {
        double s = 0.0;
        for (j = 0; j < cols; ++j)
            s += M[i * cols + j] * x[j];
        y[i] = s;
    }
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

int qp_admm_solve(const double *P, const double *q, const double *A,
                  const double *l, const double *u,
                  int n, int m, double rho, int max_iter,
                  double *x, double *pri_res)
{
    double *K = ems_K();
    double *AtA = ems_scratch();
    double *z, *y, *Ax, *rhs, *xk, *At_term;
    int i, j, p, iter;
    const double sigma = 1e-6;

    if (n > EMS_NVAR || m > EMS_NCONS_MAX)
        return -2;

    memset(AtA, 0, sizeof(double) * n * n);
    for (i = 0; i < n; ++i) {
        admm_beat(8u | (unsigned)(i & 1));
        for (j = 0; j < n; ++j) {
            double s = 0.0;
            for (p = 0; p < m; ++p)
                s += A[p * n + i] * A[p * n + j];
            AtA[i * n + j] = s;
        }
    }

    for (i = 0; i < n; ++i) {
        for (j = 0; j < n; ++j)
            K[i * n + j] = P[i * n + j] + rho * AtA[i * n + j];
        K[i * n + i] += sigma;
    }

    if (chol_decomp(K, n) != 0)
        return -3;

    /* AtA ja foi absorvido em K: reusa scratch para os vetores iterativos. */
    z = AtA;
    y = z + m;
    Ax = y + m;
    rhs = Ax + m;
    xk = rhs + n;
    At_term = xk + n;
    memset(xk, 0, sizeof(double) * n);
    memset(z, 0, sizeof(double) * m);
    memset(y, 0, sizeof(double) * m);

    for (iter = 0; iter < max_iter; ++iter) {
        admm_beat(8u | ((iter & 1u) ? 4u : 0u));
        /* rhs = sigma*x + rho*A'(z - y) - q */
        for (i = 0; i < n; ++i) {
            double s = 0.0;
            for (p = 0; p < m; ++p)
                s += A[p * n + i] * (z[p] - y[p]);
            At_term[i] = s;
            rhs[i] = sigma * xk[i] + rho * At_term[i] - q[i];
        }
        chol_solve(K, rhs, xk, n);
        matvec(A, xk, Ax, m, n);
        for (p = 0; p < m; ++p) {
            z[p] = clip(Ax[p] + y[p], l[p], u[p]);
            y[p] = y[p] + Ax[p] - z[p];
        }
    }

    memcpy(x, xk, sizeof(double) * n);
    {
        double r = 0.0;
        matvec(A, x, Ax, m, n);
        for (p = 0; p < m; ++p) {
            double d = Ax[p] - clip(Ax[p], l[p], u[p]);
            r += d * d;
        }
        *pri_res = sqrt(r);
    }
    return (*pri_res < 1.0) ? 1 : 0;
}
