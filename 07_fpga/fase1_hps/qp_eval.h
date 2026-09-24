#ifndef QP_EVAL_H
#define QP_EVAL_H

#include "ems_types.h"

enum {
    QP_EVAL_LAYOUT_OK = 1,
    QP_EVAL_LAYOUT_UNKNOWN = 0
};

typedef struct {
    int layout_ok;
    int x_missing;
    int pass_app;
    int pass_kkt;
    double cost;
    double u0;
    double pri_inf;
    double pri_rel;
    double stat_abs;
    double stat_rel;
    double dual_feas_inf;
    double dual_feas_rel;
    double comp_inf;
    double comp_rel;
    double viol_power_kw;
    double viol_cmd_kw;
    double viol_ramp_kws;
    double viol_soc_pp;
    double du0;
    double dJ_rel;
    int has_ref;
} QpEvalOut;

/* Independent KKT + family violations. Does not call any solver.
 * If x is NULL, x_missing=1 and numeric fields are left unused.
 *
 * Multiplicador combinado y (convencao OSQP): y = y_u - y_l, y_u,y_l >= 0.
 * Primal relativo por restricao: viol / max(1, |Ax|, |l| finito, |u| finito).
 * Complementaridade: y_l * max(Ax-l,0) e y_u * max(u-Ax,0) em todas as
 * linhas (sem classificar conjunto ativo por limiar). Dual-cone so quando
 * um extremo e infinito. */
int qp_eval(const double *P, const double *q, const double *A,
            const double *l, const double *u, const double *x,
            const double *lambda, int n, int m,
            const double *x_ref, int has_ref, QpEvalOut *o);

int qp_eval_layout(int n, int m);

#endif
