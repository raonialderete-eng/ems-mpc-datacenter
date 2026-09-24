#ifndef GERA_CENARIO_H
#define GERA_CENARIO_H

#include "ems_types.h"

int gera_n(const EmsParam *param);
void gera_amostra(const char *tipo, const EmsParam *param, int i,
                  double *Pload, double *Psource_max, int *grid_status);
int gera_cenario(const char *tipo, const EmsParam *param,
                 double *Pload, double *Psource_max, int *grid_status, int *N);

#endif
