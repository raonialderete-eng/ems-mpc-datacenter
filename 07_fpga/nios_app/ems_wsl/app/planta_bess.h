#ifndef PLANTA_BESS_H
#define PLANTA_BESS_H

#include "ems_types.h"

PlantaOut planta_bess(double SOC, double PBESS, double PBESS_ref,
                      double Pload, double Psource_max, int grid_status,
                      const EmsParam *param);

#endif
