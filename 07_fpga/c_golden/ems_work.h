#ifndef EMS_WORK_H
#define EMS_WORK_H

#include "ems_types.h"

/* Pool unico: Astack + H/K (mesmo buffer) + scratch (AtA, depois vetores ADMM). */
#define EMS_ASTACK_N (EMS_NCONS_MAX * EMS_NVAR)
#define EMS_H_N      (EMS_NVAR * EMS_NVAR)
#define EMS_SCRATCH_N (EMS_NVAR * EMS_NVAR)

double *ems_astack(void);
double *ems_H(void);
double *ems_K(void);
double *ems_scratch(void);

#endif
