#include "controle_mpc_fpga.h"
#include "controle_heuristico.h"
#include "qp_admm.h"
#include "ems_work.h"
#include <math.h>
#include <string.h>
#ifdef __hal__
#include "system.h"
#include "altera_avalon_pio_regs.h"
#endif

static double cmin(double a, double b) { return a < b ? a : b; }
static double cmax(double a, double b) { return a > b ? a : b; }

static void gemm_ata_scale_add(double *H, const double *A, int rows, int nvar,
                               double w)
{
    int i, r, c;
    for (r = 0; r < nvar; ++r) {
#ifdef __hal__
        IOWR_ALTERA_AVALON_PIO_DATA(PIO_LED_BASE, 8u | (unsigned)(r & 1));
#endif
        for (c = 0; c < nvar; ++c) {
            double s = 0.0;
            for (i = 0; i < rows; ++i)
                s += A[i * nvar + r] * A[i * nvar + c];
            H[r * nvar + c] += 2.0 * w * s;
        }
    }
}

static void gemv_at_add(double *f, const double *A, const double *b0,
                        int rows, int nvar, double w)
{
    int r, i;
    for (r = 0; r < nvar; ++r) {
        double s = 0.0;
        for (i = 0; i < rows; ++i)
            s += A[i * nvar + r] * b0[i];
        f[r] += 2.0 * w * s;
    }
}

MpcInfo controle_mpc_fpga(int k, double SOC_atual, double PBESS_atual,
                          double PBESS_ref_anterior, double Psource_anterior,
                          const double *Pload, const double *Psource_max,
                          const int *grid_status, int N, const EmsParam *param)
{
    MpcInfo info;
    int Np, Nc, i, j, nvar;
    static double L[EMS_NP], Pmax[EMS_NP];
    static int grid[EMS_NP];
    static double target_evento[EMS_NP], PBESS_min_event[EMS_NP];
    static double Tdu[EMS_NP * EMS_NC];
    static double Su[EMS_NP * EMS_NP], Sx[EMS_NP];
    static double u_livre[EMS_NP], PBESS_livre[EMS_NP], SOC_livre[EMS_NP];
    static double Kstep[EMS_NP];
    double *u_mat = ems_scratch();
    double *PBESS_mat = ems_scratch() + EMS_NP * EMS_NVAR;
    double *SOC_mat = ems_scratch() + 2 * EMS_NP * EMS_NVAR;
    static double Psource_ref[EMS_NP], Psource_min_recharge[EMS_NP], P_recarga_req[EMS_NP];
    double *H = ems_H();
    static double f[EMS_NVAR];
    double *Astack = ems_astack();
    static double lstack[EMS_NCONS_MAX], ustack[EMS_NCONS_MAX];
    static double z[EMS_NVAR];
    static double Arow[EMS_NVAR];
    double dUmax, dUmin, Pbase, Rbase, a, b;
    double Kd, Kc, K0;
    double w_uso, w_du, w_rampa;
    int idx_du0, idx_pg0, idx_sl0, idx_ss0, idx_sr0, idx_se0;
    int modo_evento, i_evento, ncons;
    int idx_fim;
    double pri_res = 1e9;
    int exitflag;
    double PBESS_ref;
    int emergencia, preparando;

    memset(&info, 0, sizeof(info));
    strcpy(info.fallback_causa, "");

    Np = param->Np;
    Nc = param->Nc;
    if (Np > EMS_NP) Np = EMS_NP;
    if (Nc > EMS_NC) Nc = EMS_NC;
    idx_fim = k + Np - 1;
    if (idx_fim > N - 1) {
        Np = N - k;
        if (Nc > Np) Nc = Np;
    }
    if (Np < 1 || Nc < 1) {
        info.PBESS_ref = 0.0;
        info.usou_fallback = 1;
        strcpy(info.fallback_causa, "horizonte_insuficiente");
        return info;
    }

    nvar = Nc + 5 * Np;
    idx_du0 = 0;
    idx_pg0 = Nc;
    idx_sl0 = Nc + Np;
    idx_ss0 = Nc + 2 * Np;
    idx_sr0 = Nc + 3 * Np;
    idx_se0 = Nc + 4 * Np;

    Pbase = 1.0;
    for (i = 0; i < Np; ++i) {
        L[i] = Pload[k + i];
        Pmax[i] = Psource_max[k + i];
        grid[i] = grid_status[k + i];
        if (fabs(L[i]) > Pbase) Pbase = fabs(L[i]);
        if (fabs(Pmax[i]) > Pbase) Pbase = fabs(Pmax[i]);
    }
    if (fabs(param->PBESS_max) > Pbase) Pbase = fabs(param->PBESS_max);
    if (fabs(param->PBESS_min) > Pbase) Pbase = fabs(param->PBESS_min);
    Rbase = cmax(param->Rsource_max, 1.0);

    if (!param->foresight_grid && Np >= 2) {
        for (i = 1; i < Np; ++i) {
            grid[i] = 1;
            Pmax[i] = param->Psource_max_nominal;
        }
    }
    if (!param->foresight_load && Np >= 2) {
        for (i = 1; i < Np; ++i)
            L[i] = L[0];
    }

    i_evento = -1;
    for (i = 0; i < Np; ++i) {
        if (grid[i] == 0)
            target_evento[i] = cmin(L[i], param->PBESS_max);
        else if (L[i] > Pmax[i])
            target_evento[i] = cmin(cmax(L[i] - Pmax[i], 0.0), param->PBESS_max);
        else
            target_evento[i] = 0.0;
        if (i_evento < 0 && target_evento[i] > 0.0)
            i_evento = i;
    }
    modo_evento = (i_evento >= 0);
    info.modo_evento = modo_evento;

    for (i = 0; i < Np; ++i)
        PBESS_min_event[i] = 0.0;
    if (modo_evento) {
        double target_prep = target_evento[i_evento];
        for (i = 0; i < Np; ++i) {
            if (i >= i_evento)
                PBESS_min_event[i] = target_evento[i];
            else {
                int dist = i_evento - i;
                if (dist <= param->Nprep) {
                    double alpha = (param->Nprep - dist + 1.0) / (double)param->Nprep;
                    PBESS_min_event[i] = alpha * target_prep;
                }
            }
        }
    }

    dUmax = modo_evento ? param->dPBESS_ref_max_evento : param->dPBESS_ref_max;
    dUmin = -dUmax;
    w_uso = param->w_uso_bess;
    w_du = param->w_delta_u;
    w_rampa = param->w_rampa;
    if (modo_evento) {
        w_uso *= 0.1;
        w_du *= 0.1;
        w_rampa *= 0.25;
    }

    memset(Tdu, 0, sizeof(Tdu));
    for (i = 0; i < Np; ++i)
        for (j = 0; j < Nc; ++j)
            if (j <= i)
                Tdu[i * Nc + j] = 1.0;

    a = param->ab;
    b = param->bb;
    memset(Su, 0, sizeof(Su));
    for (i = 0; i < Np; ++i) {
        Sx[i] = pow(a, i + 1);
        for (j = 0; j <= i; ++j)
            Su[i * Np + j] = b * pow(a, i - j);
        u_livre[i] = PBESS_ref_anterior;
    }
    for (i = 0; i < Np; ++i) {
        double s = Sx[i] * PBESS_atual;
        for (j = 0; j < Np; ++j)
            s += Su[i * Np + j] * u_livre[j];
        PBESS_livre[i] = s;
    }

    memset(u_mat, 0, sizeof(double) * EMS_NP * EMS_NVAR);
    memset(PBESS_mat, 0, sizeof(double) * EMS_NP * EMS_NVAR);
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < Nc; ++j)
            u_mat[i * nvar + idx_du0 + j] = Tdu[i * Nc + j];
        for (j = 0; j < Nc; ++j) {
            double s = 0.0;
            int t;
            for (t = 0; t < Np; ++t)
                s += Su[i * Np + t] * Tdu[t * Nc + j];
            PBESS_mat[i * nvar + idx_du0 + j] = s;
        }
    }

    K0 = (param->Ts / 3600.0) / param->Ebat * 100.0;
    Kd = K0 / param->eta_descarga;
    Kc = K0 * param->eta_carga;
    for (i = 0; i < Np; ++i)
        Kstep[i] = (PBESS_livre[i] < 0.0) ? Kc : Kd;

    for (i = 0; i < Np; ++i) {
        double acc = 0.0;
        for (j = 0; j <= i; ++j)
            acc += Kstep[j] * PBESS_livre[j];
        SOC_livre[i] = SOC_atual - acc;
    }
    memset(SOC_mat, 0, sizeof(double) * EMS_NP * EMS_NVAR);
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < nvar; ++j) {
            double acc = 0.0;
            int t;
            for (t = 0; t <= i; ++t)
                acc += Kstep[t] * PBESS_mat[t * nvar + j];
            SOC_mat[i * nvar + j] = -acc;
        }
    }

    /* Identidades Pgrid/S* nao sao armazenadas (cabem no scratch so 3 mats densas). */

    for (i = 0; i < Np; ++i) {
        P_recarga_req[i] = 0.0;
        Psource_min_recharge[i] = 0.0;
        if (grid[i] == 0) {
            Psource_ref[i] = 0.0;
        } else if (PBESS_min_event[i] > 0.0) {
            Psource_ref[i] = cmax(0.0, L[i] - PBESS_min_event[i]);
        } else if (L[i] > Pmax[i]) {
            Psource_ref[i] = Pmax[i];
        } else {
            Psource_ref[i] = L[i];
            if (SOC_atual < (param->SOC_ref - param->banda_SOC_mpc) &&
                (Pmax[i] - L[i]) > 0.0 && !modo_evento) {
                double folga = Pmax[i] - L[i];
                P_recarga_req[i] = folga;
                if (P_recarga_req[i] > param->P_recarga_mpc_max)
                    P_recarga_req[i] = param->P_recarga_mpc_max;
                if (P_recarga_req[i] > -param->PBESS_min)
                    P_recarga_req[i] = -param->PBESS_min;
                Psource_ref[i] = L[i] + P_recarga_req[i];
                Psource_min_recharge[i] = Psource_ref[i];
            }
        }
    }

    memset(H, 0, sizeof(double) * nvar * nvar);
    memset(f, 0, sizeof(double) * nvar);

    {
        double *A = Astack;
        double b0[EMS_NP];
        for (i = 0; i < Np; ++i) {
            memset(&A[i * nvar], 0, sizeof(double) * nvar);
            A[i * nvar + idx_pg0 + i] = 1.0 / Pbase;
            b0[i] = -Psource_ref[i] / Pbase;
        }
        gemm_ata_scale_add(H, A, Np, nvar, param->w_source_tracking);
        gemv_at_add(f, A, b0, Np, nvar, param->w_source_tracking);

        for (i = 0; i < Np; ++i) {
            memset(&A[i * nvar], 0, sizeof(double) * nvar);
            A[i * nvar + idx_sl0 + i] = 1.0 / Pbase;
            b0[i] = 0.0;
        }
        gemm_ata_scale_add(H, A, Np, nvar, param->w_slack_load);
        gemv_at_add(f, A, b0, Np, nvar, param->w_slack_load);

        for (i = 0; i < Np; ++i) {
            memset(&A[i * nvar], 0, sizeof(double) * nvar);
            A[i * nvar + idx_ss0 + i] = 1.0 / Pbase;
        }
        gemm_ata_scale_add(H, A, Np, nvar, param->w_slack_source);

        for (i = 0; i < Np; ++i) {
            memset(&A[i * nvar], 0, sizeof(double) * nvar);
            A[i * nvar + idx_sr0 + i] = 1.0 / Pbase;
        }
        gemm_ata_scale_add(H, A, Np, nvar, param->w_slack_recharge);

        for (i = 0; i < Np; ++i) {
            memset(&A[i * nvar], 0, sizeof(double) * nvar);
            A[i * nvar + idx_se0 + i] = 1.0 / Pbase;
        }
        gemm_ata_scale_add(H, A, Np, nvar, param->w_slack_event);

        memset(A, 0, sizeof(double) * EMS_NP * EMS_NVAR);
        for (i = 0; i < Np; ++i) {
            if (i == 0) {
                A[i * nvar + idx_pg0 + i] = 1.0 / Rbase;
                b0[i] = -Psource_anterior / Rbase;
            } else {
                A[i * nvar + idx_pg0 + i] = 1.0 / Rbase;
                A[i * nvar + idx_pg0 + (i - 1)] = -1.0 / Rbase;
                b0[i] = 0.0;
            }
        }
        gemm_ata_scale_add(H, A, Np, nvar, w_rampa);
        gemv_at_add(f, A, b0, Np, nvar, w_rampa);

        for (i = 0; i < Np; ++i) {
            for (j = 0; j < nvar; ++j)
                A[i * nvar + j] = SOC_mat[i * nvar + j] / 100.0;
            b0[i] = (SOC_livre[i] - param->SOC_ref) / 100.0;
        }
        gemm_ata_scale_add(H, A, Np, nvar, param->w_soc);
        gemv_at_add(f, A, b0, Np, nvar, param->w_soc);

        for (j = 0; j < nvar; ++j)
            Arow[j] = SOC_mat[(Np - 1) * nvar + j] / 100.0;
        {
            double bt = (SOC_livre[Np - 1] - param->SOC_ref) / 100.0;
            for (i = 0; i < nvar; ++i)
                for (j = 0; j < nvar; ++j)
                    H[i * nvar + j] += 2.0 * param->w_soc_terminal * Arow[i] * Arow[j];
            for (j = 0; j < nvar; ++j)
                f[j] += 2.0 * param->w_soc_terminal * Arow[j] * bt;
        }

        for (i = 0; i < Np; ++i) {
            for (j = 0; j < nvar; ++j)
                A[i * nvar + j] = PBESS_mat[i * nvar + j] / Pbase;
            b0[i] = PBESS_livre[i] / Pbase;
        }
        gemm_ata_scale_add(H, A, Np, nvar, w_uso);
        gemv_at_add(f, A, b0, Np, nvar, w_uso);

        memset(A, 0, sizeof(double) * EMS_NP * EMS_NVAR);
        for (i = 0; i < Nc; ++i)
            A[i * nvar + idx_du0 + i] = 1.0;
        gemm_ata_scale_add(H, A, Nc, nvar, w_du);
    }

    for (i = 0; i < nvar; ++i)
        H[i * nvar + i] += 1e-6;

    /* Empilha igualdades, desigualdades e bounds em l <= A x <= u */
    ncons = 0;
    memset(Astack, 0, sizeof(double) * EMS_NCONS_MAX * EMS_NVAR);

    /* Pgrid + PBESS + Sload = L - PBESS_livre */
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = PBESS_mat[i * nvar + j];
        Astack[ncons * nvar + idx_pg0 + i] += 1.0;
        Astack[ncons * nvar + idx_sl0 + i] += 1.0;
        lstack[ncons] = L[i] - PBESS_livre[i];
        ustack[ncons] = lstack[ncons];
        ncons++;
    }

    for (i = 0; i < Np; ++i) { /* u <= PBESS_max */
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = u_mat[i * nvar + j];
        lstack[ncons] = -1e9;
        ustack[ncons] = param->PBESS_max - u_livre[i];
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        double umin = (grid[i] == 0) ? 0.0 : param->PBESS_min;
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = -u_mat[i * nvar + j];
        lstack[ncons] = -1e9;
        ustack[ncons] = u_livre[i] - umin;
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = PBESS_mat[i * nvar + j];
        lstack[ncons] = -1e9;
        ustack[ncons] = param->PBESS_max - PBESS_livre[i];
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = -PBESS_mat[i * nvar + j];
        lstack[ncons] = -1e9;
        ustack[ncons] = PBESS_livre[i] - param->PBESS_min;
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = SOC_mat[i * nvar + j];
        lstack[ncons] = -1e9;
        ustack[ncons] = param->SOC_max - SOC_livre[i];
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = -SOC_mat[i * nvar + j];
        lstack[ncons] = -1e9;
        ustack[ncons] = SOC_livre[i] - param->SOC_min;
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        memset(&Astack[ncons * nvar], 0, sizeof(double) * nvar);
        Astack[ncons * nvar + idx_pg0 + i] = 1.0;
        Astack[ncons * nvar + idx_ss0 + i] = -1.0;
        lstack[ncons] = -1e9;
        ustack[ncons] = Pmax[i];
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        if (Psource_min_recharge[i] <= 0.0)
            continue;
        memset(&Astack[ncons * nvar], 0, sizeof(double) * nvar);
        Astack[ncons * nvar + idx_pg0 + i] = -1.0;
        Astack[ncons * nvar + idx_sr0 + i] = -1.0;
        lstack[ncons] = -1e9;
        ustack[ncons] = -Psource_min_recharge[i];
        ncons++;
    }
    for (i = 0; i < Np; ++i) {
        if (PBESS_min_event[i] <= 0.0)
            continue;
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = -PBESS_mat[i * nvar + j];
        Astack[ncons * nvar + idx_se0 + i] -= 1.0;
        lstack[ncons] = -1e9;
        ustack[ncons] = PBESS_livre[i] - PBESS_min_event[i];
        ncons++;
    }

    /* bounds as identity rows */
    for (i = 0; i < nvar; ++i) {
        for (j = 0; j < nvar; ++j)
            Astack[ncons * nvar + j] = (i == j) ? 1.0 : 0.0;
        lstack[ncons] = -1e9;
        ustack[ncons] = 1e9;
        if (i < Nc) {
            lstack[ncons] = dUmin;
            ustack[ncons] = dUmax;
        } else if (i >= idx_pg0 && i < idx_sl0) {
            int gi = i - idx_pg0;
            lstack[ncons] = 0.0;
            ustack[ncons] = (grid[gi] == 0) ? 0.0 : 1e6;
        } else if (i >= idx_sl0) {
            lstack[ncons] = 0.0;
            {
                int gi;
                if (i >= idx_ss0 && i < idx_sr0) {
                    gi = i - idx_ss0;
                    if (grid[gi] == 0)
                        ustack[ncons] = 0.0;
                } else if (i >= idx_sr0 && i < idx_se0) {
                    gi = i - idx_sr0;
                    if (grid[gi] == 0 || Psource_min_recharge[gi] == 0.0)
                        ustack[ncons] = 0.0;
                } else if (i >= idx_se0) {
                    gi = i - idx_se0;
                    if (PBESS_min_event[gi] == 0.0)
                        ustack[ncons] = 0.0;
                }
            }
        }
        ncons++;
    }

    exitflag = qp_admm_solve(H, f, Astack, lstack, ustack, nvar, ncons,
                             param->admm_rho, param->admm_max_iter, z, &pri_res);
    info.tempo_qp_s = 0.0;
    info.exitflag = exitflag;

    emergencia = (grid_status[k] == 0);
    preparando = (PBESS_min_event[0] > 0.0);

    if (exitflag <= 0) {
        info.usou_fallback = 1;
        strcpy(info.fallback_causa, (exitflag == 0) ? "limite_iteracoes" : "qp_inviavel");
        if (emergencia) {
            PBESS_ref = cmin(Pload[k], param->PBESS_max);
            PBESS_ref = cmax(PBESS_ref, 0.0);
        } else if (preparando) {
            PBESS_ref = cmin(PBESS_min_event[0], param->PBESS_max);
            PBESS_ref = cmax(PBESS_ref, 0.0);
            PBESS_ref = cmin(PBESS_ref, PBESS_ref_anterior + dUmax);
            PBESS_ref = cmax(PBESS_ref, PBESS_ref_anterior + dUmin);
        } else {
            PBESS_ref = controle_heuristico(Pload[k], Psource_max[k],
                                            grid_status[k], SOC_atual, param);
            PBESS_ref = cmin(PBESS_ref, PBESS_ref_anterior + dUmax);
            PBESS_ref = cmax(PBESS_ref, PBESS_ref_anterior + dUmin);
        }
    } else {
        info.usou_fallback = 0;
        PBESS_ref = PBESS_ref_anterior + z[idx_du0];
    }

    if (SOC_atual <= param->SOC_min && PBESS_ref > 0.0)
        PBESS_ref = 0.0;
    if (SOC_atual >= param->SOC_max && PBESS_ref < 0.0)
        PBESS_ref = 0.0;
    if (grid_status[k] == 0 && PBESS_ref < 0.0)
        PBESS_ref = 0.0;
    PBESS_ref = cmin(PBESS_ref, param->PBESS_max);
    PBESS_ref = cmax(PBESS_ref, param->PBESS_min);
    if (!(grid_status[k] == 0 && info.usou_fallback)) {
        PBESS_ref = cmin(PBESS_ref, PBESS_ref_anterior + dUmax);
        PBESS_ref = cmax(PBESS_ref, PBESS_ref_anterior + dUmin);
    }

    info.PBESS_ref = PBESS_ref;
    return info;
}
