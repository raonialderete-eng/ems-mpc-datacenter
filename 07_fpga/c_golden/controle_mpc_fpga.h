#ifndef CONTROLE_MPC_FPGA_H
#define CONTROLE_MPC_FPGA_H

#include "ems_types.h"

MpcInfo controle_mpc_fpga(int k, double SOC_atual, double PBESS_atual,
                          double PBESS_ref_anterior, double Psource_anterior,
                          const double *Pload, const double *Psource_max,
                          const int *grid_status, int N, const EmsParam *param);

#endif
