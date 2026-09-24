#ifndef QP_DUMP_IO_H
#define QP_DUMP_IO_H

#include "ems_types.h"

typedef struct {
    int k, n, m, ex, n_iter;
    double pri, rho, cost;
    double P[EMS_NVAR * EMS_NVAR];
    double q[EMS_NVAR];
    double A[EMS_NCONS_MAX * EMS_NVAR];
    double l[EMS_NCONS_MAX];
    double u[EMS_NCONS_MAX];
    double x[EMS_NVAR];
} QpDump;

int qp_dump_load(const char *path, QpDump *d);
unsigned long qp_dump_hash(const QpDump *d);

#endif
