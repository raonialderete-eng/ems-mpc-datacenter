#ifndef QP_ADMM_H
#define QP_ADMM_H

#include "ems_types.h"

/* min 0.5 x'P x + q'x  s.t. l <= A x <= u   (P n x n, A m x n) */
int qp_admm_solve(const double *P, const double *q, const double *A,
                  const double *l, const double *u,
                  int n, int m, double rho, int max_iter,
                  double *x, double *pri_res);

#endif
