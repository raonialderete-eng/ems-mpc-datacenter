# Fechamento Codex — 2026-10-01

Registro dos cinco pontos. Sem nova campanha. Números só de CSVs/MATs já no disco.

Fontes canónicas: `04_artigo/ieee_access/artigo_ems_mpc_datacenter_access.tex`, `response_to_reviewers.tex`, `cover_letter_access.tex`.

## Ponto 1 — HIL fallback

**Fontes:** `05_resultados/hil_de10_hps/hil_ssh_20260924/02_hil_resultados.csv`; `07_fpga/fase1_hps/controle_mpc_fpga.c` (`exitflag = qp_engine_accepted && pass_app`); `01_matlab_base/hil_loop_de2115.m` (`t_us` da RSP; overrun se `t_us > 1e6 Ts`).

| Ensaio SSH | FB campanha | FB na interrupção | Janela no CSV MATLAB |
|---|---|---|---|
| Perda | 139/1200 = 11,58% | 139/150 = 92,67% | 500–649 s |
| Retorno | 239/1200 = 19,92% | 239/250 = 95,60% | 400–649 s |

Pico 351,169 kW e E_un 14,584 / 24,306 kWh = SIL. Batch ARM FB 0.

**Diagnóstico ARM vs SSH:** não esclarecido por passo. Firmware marca fallback quando o OSQP nativo ou `eval_app` falha; na ilha o ramo de emergência descarrega `min(Pload, PBESS_max)`, o que reproduz o bound ~350 kW. A sessão SSH de 24/09 não deixou `trace-csv` nem MAT com `causa` por k. Não foi timeout de parse (1200 RSP). Não se afirma que o OSQP resolveu os QPs da interrupção no SSH. Batch ARM (planta no HPS) e malha PC OSQP tiveram FB 0; a diferença de planta MATLAB–SSH vs planta C não foi isolada.

**Overrun:** só `t_us` do solver na RSP vs 1 s. Wall ~12–13 s / 1200 passos = malha acelerada. Frase no abstract/Embedded/conclusão/carta: *No measured solver execution exceeded the 1 s sampling interval. End-to-end real-time deadline compliance was not assessed.*

## Ponto 2 — MC e bruto HIL

`montecarlo_resumo.csv`: V5 mean 359,052 / median 350,157 / p95 384,820 / max 580,324. 3-cen mean 350,009 / median 350,000 / p95 350,027 / max 350,673.

`montecarlo_diferencas_pareadas.csv` (3-cen vs V5, P_raw): mean_diff −9,043 kW; median_diff −0,157 kW; ci95 [−14,017; −4,791]; 188 lower, 12 ties.

`tab:hil_osqp`: todas as colunas no pico bruto do CSV. HIL SSH Group A `Pnao_max=0.000`; PC/ARM carga 0,0063 kW. Nota de filtro 1 kW. Não é ganho de placa. FB na tabela = campanha / janela.

## Ponto 3 — Actions (quatro etiquetas)

| Item | Âncora | Etiqueta |
|---|---|---|
| R1.1, R4.C2, R4.C7, R1.10 | Sec. Embedded + Tab. HIL + frase 1 Hz | no paper |
| R1.7, R3.4 | `tab:tau` V5-only | no paper |
| R2.5 | 2–3 frases B4 (estudos adicionais + RQ3); CSV GitHub | no paper + suplemento GitHub |
| R2.6 | implementação desktop + nota HIL ≠ desktop | no paper + só na carta (tabela 47 QPs) |
| R2.7 | 100/8353 e 0,044 pp em Implementation | no paper |
| R2.8 | fairness no RQ2; síntese comando GitHub | no paper + suplemento GitHub |
| R2.13 | iterações 10/12/14/15 no computational | no paper |
| R3.2 | média/mediana/p95/max + IC bootstrap + ECDF | no paper |
| R5.1 | janela [−20,+4] s junto da tabela de timing | no paper |
| R1.8 genset co-opt | não simulado | não realizado |
| FIL / EMT / α=0,001 | fora de escopo | não realizado |
| Formulário IEEE mudança de autores | portal | não realizado (Cursor) |

Apagado: “CSVs were left unread”.

## Ponto 4 — Figura

ECDF TikZ/pgfplots dos 200 picos brutos V5 vs 3-cenários (`grupo_montecarlo.csv` → `figuras/ecdf_v5.dat`, `ecdf_3cen.dat`). Legendas das Figs. load/limit/loss: custos, fill e supervisão diferem; não isolar horizonte.

## Ponto 5 — PDFs

Gerados 2026-10-01. Artigo limpo e `_FINAL.pdf` com o mesmo SHA-256 `816CF7C820F23F07EB62A9183CE454C871B49C7ABF994773B32B6939F666A669`. Destacado via `_latexdiff_work/regen_pack.ps1` (`old.tex` da submissão original vs TeX atual, dois autores, título novo). Cover PDF bate com o `.tex` (título + Batista). Pacote em `04_artigo/resubmissao_20260918/`. Formulário IEEE de mudança de autores: **portal IEEE; não cumprível pelo Cursor**.

## GitHub / Zenodo (não publicado nesta sessão)

TeX/PDF mudaram relativamente a `v1.0.5-ieee-access-rev` / DOI `10.5281/zenodo.22943792`. Quando o autor pedir:

1. Commit + tag `v1.0.6-ieee-access-rev`.
2. Nova versão Zenodo; **só então** actualizar Data Availability. Até lá o texto continua no 22943792.
3. `main` pode ainda estar em `58b5088`; merge `v104-onto-origin` / `145f075` se PR #1 continuar aberto.
4. Não reenviar MATs de 1755 jobs; addendum só se CSVs/figuras novas (os `.dat` ECDF e o TeX).
