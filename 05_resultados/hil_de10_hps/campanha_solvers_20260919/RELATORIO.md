# Campanha OSQP / qpOASES — 2026-09-19

Pasta: `05_resultados/hil_de10_hps/campanha_solvers_20260919/`
Fechamento da evidência: `08_fecho/` (avaliador, xref, malha independente, colunas, auditoria C/MATLAB).
A primeira rodada em `04_cold/`, `05_timing/` e `07_loop/` **não** foi sobrescrita.

Access, V5, DE2-115, FIL: **não** alterados. Freeze P1 em `00_freeze/`.

Compilador: gcc/g++ 16.1.0 WinLibs, `-O2`, sem `-ffast-math`.
OSQP 1.0.0 (Apache-2.0) + QDLDL v0.1.8. qpOASES 3.2.1 (LGPL-2.1), ligação estática nesta campanha.

## Parecer

Comportamento em malha no PC é o esperado do controlador (SIL matlab_fpga) com OSQP e qpOASES, com concordância entre as duas bibliotecas. A certificação numérica e a documentação **não** autorizam um “aprovado” sem ressalvas: ainda falta o pacote PC–ARM no mesmo dump. OSQP é o candidato principal **provisório**; qpOASES permanece alternativa e referência.

A substituição do solver eliminou as divergências principais nos quatro cenários. A equivalência completa das restrições C/MATLAB no envelope operacional foi medida nesta noite; resta o teto 1e6 vs `inf` em Pgrid com rede.

Não se adicionou quadprog gerado em C/C++.

## Classificação

| Etapa | ADMM P1 / λ=ρSy | OSQP | qpOASES |
|---|---|---|---|
| Contratos | avaliador recusa KKT no inviável; ADMM não detecta inviável | ok | ok |
| Dumps treino (11, com xref) | app 2/11, KKT 0 | **app 11/11, KKT 11/11** | **app 11/11, KKT 11/11** |
| Hold-out distinto (5, com xref) | app 2/5, KKT 0 | **app 5/5, KKT 3/5** | **app 5/5, KKT 5/5** |
| Malha 4 cenários (nativo **e** `pass_app`) | não entra | **FB 0, app 1200/1200** | **FB 0, app 1200/1200, KKT 1200/1200** |
| Placa PC–ARM | — | não medida | não medida |

Correção em malha: praticamente empatados. Certificação KKT registrada: qpOASES mais completa. Tempo frio no PC: OSQP.

As 2 reprovações KKT do OSQP no reservado são complementaridade ~9e−5 com primal ~1e−9; não se leem como falha primal.

## 1. Dual ADMM

`lambda[p] = rho_use * S[p] * y[p]`. Melhora estacionariedade quando ρ muda. **Não** corrige o primal de 170–200 kW nos QPs de preparação/ilha. O problema avaliado é a implementação/configuração própria, não “ADMM como método”: o OSQP também é ADMM.

## 2. Formulação (mesmo estado)

Spy MATLAB grava `H,f,A,b,Aeq,beq,lb,ub`. Conversão `l≤Ax≤u` inclui bounds.

| caso | \|\|H−P\|\|_F | m_M = m_C | pertinência 200 pts | linhas casadas |
|---|---|---|---|---|
| carga k=0 | 6,0e−14 | 160 | 200/200 | 148/160 (12 = Pgrid ub 1e6 vs inf) |
| perda k=500 | 2,2e−12 | 172 | 200/200 | 172/172 |

Arquivos: `05_resultados/hil_de10_hps/form_same_state/cmp_*.txt` e cópia em `08_fecho/form/`.

## 3. Identidade SHA-256

Treino: 11 hashes distintos. Hold-out usado: ilha prescrita, k0 faixas, SOC min/max, first-div k=389 (sem vazamento do treino).

## 4. Referência e KKT

`--ref-dir 08_fecho/ref`. Procedência em `08_fecho/ref_source.csv`: MATLAB onde `kkt_ok`; qpOASES em k=0, k=488 e nos 5 QPs reservados.

Avaliador: primal por restrição; complementaridade sem limiar de conjunto ativo; dual-cone só com extremo infinito.

## 5. Malha

Aceite OSQP/qpOASES: `qp_engine_accepted` **e** `pass_app`. Coluna `pri` = resíduo primal independente. `t_s` = tempo do solver primário (sombra fora). Sombra nos quatro cenários.

| solver | carga_faixas | limite_fonte | perda_fonte | retorno_fonte |
|---|---|---|---|---|
| SIL matlab_fpga (hist) | 0 | ~0 | ~351,17 | ~351,17 |
| ADMM 80 (campanha anterior) | 11,67 / FB 261 | 11,67 / 1011 | 381,12 / 689 | 381,12 / 789 |
| **OSQP** | **0,0063 kW / FB 0 / SOC 59,06 %** | **0,0003 / 0 / 51,10** | **351,169 / 0 / 57,57** | **351,169 / 0 / 55,23** |
| **qpOASES** | **0,0063 / 0 / 59,06** | **~0 / 0 / 51,10** | **351,169 / 0 / 57,57** | **351,169 / 0 / 55,23** |

E_un perda = 14,584 kWh; retorno = 24,306 kWh.
`|Δ(Δu)|` sombra máx ≪ 0,10 kW (carga 5,8e−5; limite 7,8e−4; ilha 2,4e−8).

Tempo frio k=500, 5+100, `note=ok` só se nativo e `pass_app`: OSQP 3,52 / 4,60 / 5,77 ms; qpOASES 28,52 / 30,71 / 33,38 ms. ADMM `FAIL` (x presente não conta).

## 6. Decisão

- **ADMM próprio:** não segue como solver do QP FPGA.
- **OSQP:** candidato principal provisório (malha + dumps app 16/16 + tempo).
- **qpOASES:** alternativa e referência (KKT mais completa).
- Próximo: equivalência PC–ARM no **mesmo** dump (hash x, J, status), depois ciclo DE10. Software no HPS ≠ FIL.
- Não promover ao Access até o pacote de reprodução e a bancada que se quiser declarar.

Heurístico 90,98 / 592,61 permanece regressão da planta.
