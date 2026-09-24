#ifndef QP_METRICS_H
#define QP_METRICS_H

#include "qp_admm.h"

double qp_cost(const double *P, const double *q, const double *x, int n);

/* Violações nas unidades originais. Infere Np/Nc de n=Nc+5*Np (encaixe FPGA). */
int qp_infer_horizon(int n, int m, int *Np, int *Nc);

void qp_family_viol(const double *A, const double *l, const double *u,
                    const double *x, int n, int m,
                    double *power_kw, double *cmd_kw,
                    double *ramp_kws, double *soc_pp);

void qp_stationarity(const double *P, const double *q, const double *A,
                     const double *lambda, const double *x,
                     int n, int m, double *stat_abs, double *stat_rel);

#endif
