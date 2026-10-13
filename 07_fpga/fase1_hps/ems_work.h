#ifndef EMS_WORK_H
#define EMS_WORK_H

#include "ems_types.h"

/* Pool unico: Astack + Hessiana P + KKT/Cholesky K + scratch ADMM.
 * H e K NAO podem aliasar: form_k zera K e chol_decomp escreve in-place. */
#define EMS_ASTACK_N (EMS_NCONS_MAX * EMS_NVAR)
#define EMS_H_N      (EMS_NVAR * EMS_NVAR)
#define EMS_K_N      (EMS_NVAR * EMS_NVAR)
#define EMS_SCRATCH_N (EMS_NVAR * EMS_NVAR)

double *ems_astack(void);
double *ems_H(void);
double *ems_K(void);
double *ems_scratch(void);

#endif
