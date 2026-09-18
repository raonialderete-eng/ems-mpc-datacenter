#ifndef EMS_TYPES_H
#define EMS_TYPES_H

#include <stdint.h>

#ifndef EMS_NP
#define EMS_NP 12
#endif
#ifndef EMS_NC
#define EMS_NC 4
#endif

#define EMS_NVAR (EMS_NC + 5 * EMS_NP)
#define EMS_NINEQ_MAX (7 * EMS_NP + 2 * EMS_NP)
#define EMS_NCONS_MAX (EMS_NP + EMS_NINEQ_MAX + EMS_NVAR)

typedef struct {
    double Ts;
    double Tf;
    double Psource_max_nominal;
    double Rsource_max;
    double Pload_base;
    double Pload_media;
    double Pload_alta;
    double Ebat;
    double SOC_min;
    double SOC_max;
    double SOC_ref;
    double PBESS_max;
    double PBESS_min;
    double tau_b;
    double ab;
    double bb;
    double eta_descarga;
    double eta_carga;
    int Np;
    int Nc;
    double dPBESS_ref_max;
    double dPBESS_ref_max_evento;
    int Nprep;
    double w_source_tracking;
    double w_slack_load;
    double w_slack_source;
    double w_slack_event;
    double w_slack_recharge;
    double w_rampa;
    double w_soc;
    double w_soc_terminal;
    double w_uso_bess;
    double w_delta_u;
    double P_recarga_mpc_max;
    double banda_SOC_mpc;
    int foresight_grid;
    int foresight_load;
    int admm_max_iter;
    double admm_rho;
    double timeout_qp_s;
} EmsParam;

typedef struct {
    double SOC_next;
    double PBESS_next;
    double Psource;
    double Pnao;
} PlantaOut;

typedef struct {
    double PBESS_ref;
    int exitflag;
    int usou_fallback;
    int modo_evento;
    double tempo_qp_s;
    char fallback_causa[48];
} MpcInfo;

#endif
