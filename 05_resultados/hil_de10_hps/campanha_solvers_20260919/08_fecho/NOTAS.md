# Fechamento 2026-09-19 — lacunas da revisão

Não sobrescreve `04_cold/`, `05_timing/` nem `07_loop/` da primeira rodada.
Binários: `07_fpga/fase1_hps/qp_campaign.exe`, `ems_hps.exe` após `build_campaign.ps1`.

## A. Referências nos 16 QPs

`--ref-dir 08_fecho/ref`. Sidecar `DIR/basename.xref`.
`ref_source.csv`: MATLAB (`keep_existing`) nos treinos com `kkt_ok`; qpOASES em `qp_k0000_exit1`, `qp_k0488_exit1` e nos 5 reservados.
Reavaliação: `has_ref=1` em todas as linhas de `04_cold/treino_all.csv` e `holdout_unique.csv`. Δu0 e ΔJ_rel entram no `pass_app`.

## B. Malha: nativo e avaliador

`exitflag` OSQP/qpOASES exige `qp_engine_accepted` **e** `pass_app`.
`pri` no CSV é `pri_inf` do avaliador, não o custo.
`t_s` é `so.t_total` do solver primário; a sombra corre depois.
Sombra qpOASES nos quatro cenários OSQP. `|Δ(Δu)|` ≪ 0,10 kW.
Layout do avaliador infere Np/Nc quando o horizonte encolhe no fim da simulação (antes isso gerava 10 `eval_app` falsos).

## C. Avaliador KKT

`qp_eval.c`: complementaridade `y_l·(Ax−l)+` e `y_u·(u−Ax)+` em todas as linhas; dual-cone só com extremo infinito; primal relativo por restrição.
Após o ajuste: OSQP treino **11/11 KKT** (antes 10/11). Hold-out OSQP **3/5**: `faixas` e `socmax` com `comp_rel≈9,2e−5` (primal ~4e−9). qpOASES 16/16. Não se atribui as 2 falhas a erro primal do OSQP.

## D. Restrições C/MATLAB

Spy grava `lb,ub`. `matlab_to_lu` empilha bounds finitos.
carga: m 160=160, pertinência 200/200, 12 linhas Pgrid ub 1e6 vs inf.
perda/ilha: m 172=172, 172/172 linhas, 200/200.

## E. Registros

- Tempo OSQP na malha não inclui a sombra.
- `pri` = residual primal.
- Timing k=500: `note=ok` só com nativo e `pass_app`. ADMM = `FAIL`.
- OSQP frio: 3,52 / 4,60 / 5,77 ms. qpOASES: 28,52 / 30,71 / 33,38 ms.
- A coluna `solve` do qpOASES ~1e−7 s é o tempo após `init` (quase tudo está em `setup`); o total é o número a usar.

## Malha `08_fecho/07_loop`

| solver | cenário | Pnao_max kW | E_un kWh | FB | eval_app | eval_kkt |
|---|---|---|---|---|---|---|
| OSQP | carga | 0,006312 | ~0 | 0 | 1200 | 980 |
| OSQP | limite | 0,000305 | ~0 | 0 | 1200 | 1191 |
| OSQP | perda | 351,169 | 14,584 | 0 | 1200 | 1200 |
| OSQP | retorno | 351,169 | 24,306 | 0 | 1200 | 1200 |
| qpOASES | carga | 0,006312 | ~0 | 0 | 1200 | 1200 |
| qpOASES | limite | ~0 | ~0 | 0 | 1200 | 1200 |
| qpOASES | perda | 351,169 | 14,584 | 0 | 1200 | 1200 |
| qpOASES | retorno | 351,169 | 24,306 | 0 | 1200 | 1200 |

SOC final OSQP/qpOASES: 59,060 / 51,103 / 57,573 / 55,234 %.
