# HIL Fase 1 HPS (ADMM C, golden PC / DE10-Standard)

Nao e FIL. Nao misturar com `05_resultados/hil_de2115` (UART heuristico DE2-115).

Versao: **fase1_hps-P1-20260919** (Hessiana e KKT em buffers distintos).
Gerado por `01_matlab_base/main_fase1_hps.m` em 2026-09-19 (backend `c_exe`, binario `07_fpga/fase1_hps/ems_hps.exe` **pos-P1**, default 80 iter, `pri_tol=1.0`).

## Alvos SIL quadprog (ja medidos — nao inventar)

- Grupo A `carga_faixas` / `limite_fonte`: `Pnao_max = 0`
- `perda_fonte` / `retorno_fonte`: `Pnao_max ≈ 351 kW`
- Heuristico: 90.98 (faixas) / 592.61 (perda)

## Golden C neste PC (ADMM pos-P1, 2026-09-19)

| controle | cenario | Pnao_max | fallback % | t_us p50 | p95 | max | overrun |
|----------|---------|----------|------------|----------|-----|-----|---------|
| heur | carga_faixas | **90.98** | 0 | 0 | 0 | 0 | 0 |
| heur | perda_fonte | **592.61** | 0 | 0 | 0 | 0 | 0 |
| mpc | carga_faixas | **11.68** (nao 0) | **1.00** | 1349 | 1745 | 3996 | 0 |
| mpc | limite_fonte | **11.67** (nao 0) | **1.00** | 1350 | 1761 | 3262 | 0 |
| mpc | perda_fonte | **381.12** (nao 351) | 57.33 | 2958 | 4929 | 6505 | 0 |
| mpc | retorno_fonte | **381.12** (nao 351) | 65.67 | 2988 | 4930 | 6061 | 0 |

`t_us` no MPC **nao** e 0 (relogio ok). Overrun vs `Ts=1 s`: nenhum neste host. O 1º QP do C bate o `quadprog`; o ADMM ainda para em `pri<1`. **Nao entra no Access** ate o HIL na DE10-Standard e um KPI aceitavel (zero no Grupo A). Nao tratar 11.68 como o zero pedido pelos revisores.
