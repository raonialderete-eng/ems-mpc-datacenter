#include "controle_heuristico.h"

static double hmin(double a, double b) { return a < b ? a : b; }
static double hmax(double a, double b) { return a > b ? a : b; }

double controle_heuristico(double Pload, double Psource_max, int grid_status,
                           double SOC, const EmsParam *param)
{
    const double banda_SOC = 0.5;
    const double P_carga_heuristica_max = hmin(-param->PBESS_min, 150.0);
    double PBESS_ref;
    double folga_fonte;
    double P_carga;

    if (grid_status == 0) {
        PBESS_ref = Pload;
    } else if (Pload > Psource_max) {
        PBESS_ref = Pload - Psource_max;
    } else {
        folga_fonte = Psource_max - Pload;
        if (SOC < (param->SOC_ref - banda_SOC) && folga_fonte > 0.0) {
            P_carga = hmin(folga_fonte, P_carga_heuristica_max);
            PBESS_ref = -P_carga;
        } else {
            PBESS_ref = 0.0;
        }
    }

    if (SOC <= param->SOC_min && PBESS_ref > 0.0)
        PBESS_ref = 0.0;
    if (SOC >= param->SOC_max && PBESS_ref < 0.0)
        PBESS_ref = 0.0;

    PBESS_ref = hmin(PBESS_ref, param->PBESS_max);
    PBESS_ref = hmax(PBESS_ref, param->PBESS_min);
    return PBESS_ref;
}

double controle_heuristico_foresight(int k, double SOC, double PBESS_ref_anterior,
                                     const double *Pload, const double *Psource_max,
                                     const int *grid_status, int N,
                                     const EmsParam *param)
{
    int Nprep = param->Nprep;
    double dUmax = param->dPBESS_ref_max;
    double dUmax_evento = param->dPBESS_ref_max_evento;
    int idx_fim = k + (Nprep > 1 ? Nprep : 1) - 1;
    int i;
    double target = 0.0;
    int i_rel = -1;
    int modo_evento;
    double PBESS_ref;
    double dU;
    double dist;
    double alpha;
    double u_prep;

    if (idx_fim > N - 1)
        idx_fim = N - 1;

    for (i = k; i <= idx_fim; ++i) {
        if (grid_status[i] == 0) {
            target = hmin(Pload[i], param->PBESS_max);
            i_rel = i;
            break;
        }
        if (Pload[i] > Psource_max[i]) {
            target = hmin(hmax(Pload[i] - Psource_max[i], 0.0), param->PBESS_max);
            i_rel = i;
            break;
        }
    }

    modo_evento = (i_rel >= 0 && target > 0.0);
    if (modo_evento) {
        dist = (double)(i_rel - k);
        if (dist <= (double)Nprep) {
            alpha = (Nprep - dist + 1.0) / (double)Nprep;
            u_prep = alpha * target;
        } else {
            u_prep = 0.0;
        }
        if (grid_status[k] == 0 || Pload[k] > Psource_max[k]) {
            PBESS_ref = controle_heuristico(Pload[k], Psource_max[k],
                                            grid_status[k], SOC, param);
        } else {
            PBESS_ref = hmax(u_prep, 0.0);
        }
        dU = dUmax_evento;
    } else {
        PBESS_ref = controle_heuristico(Pload[k], Psource_max[k],
                                        grid_status[k], SOC, param);
        dU = dUmax;
    }

    PBESS_ref = hmin(PBESS_ref, PBESS_ref_anterior + dU);
    PBESS_ref = hmax(PBESS_ref, PBESS_ref_anterior - dU);

    if (SOC <= param->SOC_min && PBESS_ref > 0.0)
        PBESS_ref = 0.0;
    if (SOC >= param->SOC_max && PBESS_ref < 0.0)
        PBESS_ref = 0.0;
    if (grid_status[k] == 0 && PBESS_ref < 0.0)
        PBESS_ref = 0.0;

    PBESS_ref = hmin(hmax(PBESS_ref, param->PBESS_min), param->PBESS_max);
    return PBESS_ref;
}
