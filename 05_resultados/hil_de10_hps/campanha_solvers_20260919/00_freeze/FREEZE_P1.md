# Freeze P1 — ADMM PC (2026-09-19)

Não alterar Access / V5 / Nios / FIL.

## Configuração congelada

- `VERSION.txt`: `fase1_hps-P1-20260919-r2`
- `pri_tol = 1.0` (unidades originais)
- `admm_rho = 1.0`
- `admm_max_iter = 80`
- \(\sigma = 10^{-6}\)
- Fill: `foresight_grid=1`, `foresight_load=1` (`ems_param.c`)

## SHA256 dos dumps de treino (`qp_fixtures/perda80`)

Ver `FREEZE_perda80_sha256.txt`. Não regenerar esses txt até o runner existir e o hash bater.

## Baseline a reproduzir (não é portão de sucesso)

`ems_hps.exe` host, `--max-iter 80`:

| ctrl | cenário | Pnao_max | fallback |
|---|---|---|---|
| heur | carga_faixas | 90.979599 | 0 |
| heur | perda_fonte | 592.61 | 0 |
| mpc | carga_faixas | 11.679759 | 12 |
| mpc | limite_fonte | 11.67 | 12 |
| mpc | perda_fonte | 381.12 | ~687 |
| mpc | retorno_fonte | 381.12 | ~787 |

SIL `matlab_fpga` / `quadprog`: Grupo A 0 kW; perda ~351 kW.
