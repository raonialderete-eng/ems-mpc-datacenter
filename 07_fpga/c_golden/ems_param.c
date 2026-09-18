#include "ems_param.h"
#include <math.h>

void ems_param_fpga(EmsParam *p)
{
    p->Ts = 1.0;
    p->Tf = 1200.0;
    p->Psource_max_nominal = 800.0;
    p->Rsource_max = 100.0;
    p->Pload_base = 600.0;
    p->Pload_media = 750.0;
    p->Pload_alta = 950.0;
    p->Ebat = 500.0;
    p->SOC_min = 20.0;
    p->SOC_max = 90.0;
    p->SOC_ref = 60.0;
    p->PBESS_max = 400.0;
    p->PBESS_min = -250.0;
    p->tau_b = 2.0;
    p->ab = exp(-p->Ts / p->tau_b);
    p->bb = 1.0 - p->ab;
    p->eta_descarga = 0.95;
    p->eta_carga = 0.95;
    p->Np = EMS_NP;
    p->Nc = EMS_NC;
    p->dPBESS_ref_max = 120.0;
    p->dPBESS_ref_max_evento = 400.0;
    p->Nprep = 12;
    p->w_source_tracking = 3000.0;
    p->w_slack_load = 1e9;
    p->w_slack_source = 1e8;
    p->w_slack_event = 1e9;
    p->w_slack_recharge = 1e6;
    p->w_rampa = 300.0;
    p->w_soc = 1200.0;
    p->w_soc_terminal = 12000.0;
    p->w_uso_bess = 20.0;
    p->w_delta_u = 50.0;
    p->P_recarga_mpc_max = 50.0;
    p->banda_SOC_mpc = 0.3;
    p->foresight_grid = 1;
    p->foresight_load = 1;
    p->admm_max_iter = 40;
    p->admm_rho = 1.0;
    p->timeout_qp_s = 0.20;
}
