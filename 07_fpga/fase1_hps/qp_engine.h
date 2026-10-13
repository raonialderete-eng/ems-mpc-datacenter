#ifndef QP_ENGINE_H
#define QP_ENGINE_H

#include "qp_admm.h"
#include "qp_eval.h"

#ifdef __cplusplus
extern "C" {
#endif

enum {
    QP_ENG_ADMM = 0,
    QP_ENG_ADMM_HIST = 1,
    QP_ENG_OSQP = 2,
    QP_ENG_QPOASES = 3
};

enum {
    QP_INIT_COLD = 0,
    QP_INIT_WARM = 1
};

typedef struct {
    int engine;
    int native_status;
    char native_name[48];
    int n_iter;
    int x_missing;
    double x[EMS_NVAR];
    double lambda[EMS_NCONS_MAX];
    double t_setup;
    double t_update;
    double t_solve;
    double t_total;
    double obj;
} QpSolveOut;

void qp_engine_set(int engine);
int qp_engine_get(void);
void qp_engine_set_shadow(int engine);
int qp_engine_get_shadow(void);
const char *qp_engine_name(int engine);
int qp_engine_accepted(const QpSolveOut *o);

int qp_engine_solve(const double *P, const double *q, const double *A,
                    const double *l, const double *u, int n, int m,
                    int init_policy, QpSolveOut *out);

void qp_engine_reset(void);

int qp_admm_hist_solve(const double *P, const double *q, const double *A,
                       const double *l, const double *u,
                       int n, int m, double rho, int max_iter,
                       double *x, double *pri_res, int *n_iter);
void qp_admm_hist_get_report(QpAdmmReport *r);
void qp_admm_hist_reset_warm(void);

int qp_osqp_solve(const double *P, const double *q, const double *A,
                  const double *l, const double *u, int n, int m,
                  int init_policy, QpSolveOut *out);
void qp_osqp_reset(void);

int qp_qpoases_solve(const double *P, const double *q, const double *A,
                     const double *l, const double *u, int n, int m,
                     int init_policy, QpSolveOut *out);
void qp_qpoases_reset(void);

#ifdef __cplusplus
}
#endif

#endif
