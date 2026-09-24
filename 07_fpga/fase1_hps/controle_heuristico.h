#ifndef CONTROLE_HEURISTICO_H
#define CONTROLE_HEURISTICO_H

#include "ems_types.h"

double controle_heuristico(double Pload, double Psource_max, int grid_status,
                           double SOC, const EmsParam *param);

double controle_heuristico_foresight(int k, double SOC, double PBESS_ref_anterior,
                                     const double *Pload, const double *Psource_max,
                                     const int *grid_status, int N,
                                     const EmsParam *param);

#endif
