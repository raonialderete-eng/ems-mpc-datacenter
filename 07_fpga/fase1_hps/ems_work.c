#include "ems_work.h"

static double ems_pool[EMS_ASTACK_N + EMS_H_N + EMS_K_N + EMS_SCRATCH_N];

double *ems_astack(void)
{
    return ems_pool;
}

double *ems_H(void)
{
    return ems_pool + EMS_ASTACK_N;
}

double *ems_K(void)
{
    return ems_pool + EMS_ASTACK_N + EMS_H_N;
}

double *ems_scratch(void)
{
    return ems_pool + EMS_ASTACK_N + EMS_H_N + EMS_K_N;
}
