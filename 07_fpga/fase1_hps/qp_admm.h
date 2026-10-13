#ifndef QP_ADMM_H
#define QP_ADMM_H

#include "ems_types.h"
#include <stdio.h>

/* min 0.5 x'P x + q'x  s.t. l <= A x <= u   (P n x n, A m x n)
 *
 * Variáveis internas (ver DIAGNOSTICO_ADMM.md):
 *   x  — primal R^n
 *   z  — projeção na caixa escalada  S*l <= z <= S*u
 *   y  — dual da igualdade escalada (S A) x - z = 0
 *   S  — escala de linhas: S_p = 1 / max(1, ||A_p||_inf)
 *   rho, sigma=1e-6
 *
 * lambda do QP (l <= A x <= u): lambda_p = rho * S_p * y_p
 *   (y eh dual escalado; rho corrente apos adaptacao)
 * estacionariedade: Px + q + A^T lambda
 * residual de iteração ADMM: rho (S A)^T (z^k - z^{k-1})
 *
 * Guarda histórica: pri_unscaled < 1. Não é o único critério.
 * n_iter pode ser NULL. */

enum {
    QP_ADMM_CONV = 1,
    QP_ADMM_ITER_LIMIT = 0,
    QP_ADMM_BAD_INPUT = -2,
    QP_ADMM_CHOL = -3,
    QP_ADMM_ALIAS = -4
};

typedef struct {
    int status;
    int n_iter;
    int n_rho_update;
    double pri_unscaled;
    double dual_admm;
    double stat_abs;
    double stat_rel;
    double viol_power_kw;
    double viol_cmd_kw;
    double viol_ramp_kws;
    double viol_soc_pp;
    double cost;
    double u0;
    double rho;
    double p_fro_before;
    double p_fro_after;
    double t_s;
    int n;
    int m;
    double lambda[EMS_NCONS_MAX];
} QpAdmmReport;

int qp_admm_solve(const double *P, const double *q, const double *A,
                  const double *l, const double *u,
                  int n, int m, double rho, int max_iter,
                  double *x, double *pri_res, int *n_iter);

void qp_admm_get_report(QpAdmmReport *r);
void qp_admm_set_trace(FILE *fp);
void qp_admm_reset_warm(void);
void qp_admm_set_dump_dir(const char *dir);
void qp_admm_request_dump(int k, int force);

#endif
