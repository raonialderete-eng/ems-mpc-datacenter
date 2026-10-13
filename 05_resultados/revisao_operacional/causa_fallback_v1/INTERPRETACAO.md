# Interpretação — causa e influência de `exitflag = −6`

Campanha: `05_resultados/revisao_operacional/causa_fallback_v1/` (19/09/2026, MATLAB R2025b).  
**A consolidação oficial `consolidacao_corrigida_20260911_v1` não foi alterada.** Os KPIs do artigo continuam MPC+fallback. Este diretório é diagnóstico.

Critérios pré-registrados em `CRITERIOS.json`. Código isolado em `01_matlab_base/experimentos/causa_fallback/` (não edita `controle_mpc_auditado.m` de produção). Hashes de produção em `status.json`.

## O que foi medido

- **47 passos** V5 com −6: `j00014` (19, t=462–483 s, falta em 500 s) e `j00019` (28, t=352–384 s, evento em 400 s). Instantes iguais à carta R2.6.
- Quatro controlos `exitflag=1` em `j00014` (t=0, 199, 449, 489 s).
- Replay IPM oficial, IPM com α=0,001 em H e f, e active-set no mesmo QP reconstruído no **estado do MAT**.
- Malhas: histórico/MAT, replay oficial, escala 0,001, recuperação QP (sem heurístico se o IPM recusar).

## Causa (Parte A)

Todos os **47** passos:

| Achado | Valor |
|---|---|
| `ef0` reproduz o MAT | 47/47 |
| `chol(H)` | flag 0 (SPD) |
| `λ_min` | +0,00666 (nenhum autovalor negativo) |
| IPM α=0,001 | `exitflag=1` nos 47 |
| active-set em αH | `exitflag=1` nos 47 |
| Etiqueta | **`ipm_falso_nao_convexo` (47/47)** |
| `hessiana_indefinida` | 0 |

O código MATLAB −6 (`nao_convexo`) **não** significa que o QP formulado seja não convexo. A Hessiana reconstruída é definida positiva; o interior-point-convex recusa a solução na escala oficial; a mesma formulação é aceite após reescala positiva do objetivo (equivalente em aritmética exata) e pelo active-set.

Controlos com `exitflag=1`: mesma família de `λ_min` (~0,0067). A falha não é um H indefinido só na janela de preparação.

`condest(H) ≈ 3,33×10^5` é alto, mas comum aos passos −6 e aos controlos OK. A recusa é **sensibilidade numérica do IPM na escala do objetivo**, não inviabilidade física nem Hessiana indefinida.

O IPM ainda devolve um `z` em vários −6 (`u_ipm` finito); a política **descarta** esse ponto e aplica o heurístico. Não confundir ponto interno rejeitado com ausência de candidato.

Não se afirma: “todas as falhas da campanha de 6.254 −6 são falsas”; “a escala resolve o solver em geral”. O gate KKT 13/15 e as faltas longas (−2) continuam a impedir promover α=0,001 a versão oficial.

## Influência na preparação (Partes B2 e B3)

O FB% (1,58% / 2,33%) **não** descreve a janela. Os comandos caem imediatamente antes do evento.

**B1.** `|u_aplicado − u_QP|` médio ~57 kW (`j00014`) e ~51 kW (`j00019`); máximo 298 kW no primeiro −6 de `j00014` (heurístico 0 kW vs QP ~298 kW). O heurístico arranca mais conservador; o QP pede descarga de preparação.

**B2** (só passos −6, resto da trajetória histórica — limite local, não malha pura): ΔSOC no evento −0,064 pp (`j00014`) e −0,083 pp (`j00019`). Pequeno porque os outros passos da janela continuam oficiais.

**B3** (atribuição em malha fechada). Replay oficial **idêntico** ao MAT (pico, energia, 19/28 fallbacks, SOC no evento).

| Caso | Run | FB | Pico kW | SOC no evento | Eprep (descarga) kWh | SOC final |
|---|---|---:|---:|---:|---:|---:|
| j00014 | histórico / replay | 19 | 350,067 | 59,345 | 3,283 | 57,098 |
| j00014 | escala 0,001 | 0 | 350,000 | 58,970 | 5,061 | 56,698 |
| j00014 | QP recovery | 0 | 350,000 | 58,971 | 5,061 | 56,723 |
| j00019 | histórico / replay | 28 | 350,090 | 59,502 | 2,535 | 54,916 |
| j00019 | escala 0,001 | 0 | 350,000 | 58,971 | 5,059 | 54,359 |
| j00019 | QP recovery | 0 | 350,000 | 58,971 | 5,058 | 54,385 |

Números que fecham o comentário:

- **Causa das 47 recusas do paper:** IPM em escala oficial; H SPD; não convexidade matemática não demonstrada.
- **Influência do fallback na preparação (malha):** sem heurístico, a descarga de preparação sobe ~1,8 kWh (`j00014`: 3,28→5,06) e ~2,5 kWh (`j00019`: 2,54→5,06). SOC no instante do evento cai ~0,37 pp (`j00014`) e ~0,53 pp (`j00019`).
- **Pico de Pnão:** permanece no piso ~350 kW com e sem fallback. O piso **não** foi criado pelo heurístico nesses dois casos; a política completa e o QP recuperado coincidem no pico.
- Os KPIs oficiais continuam **MPC+fallback**. Não atribuir o SOC/throughput finais exclusivamente ao QP: o heurístico reduziu a energia de preparação e deixou SOC de evento um pouco mais alto. O pico de continuidade, nestes dois casos principais, seria o mesmo se o QP tivesse sido aceite.

## O que pode ir à carta (quando autorizado)

- Tabela R2.6: manter 19/28 e instantes; acrescentar etiqueta `ipm_falso_nao_convexo` (H SPD, α=0,001 e active-set aceitam).
- Uma frase de influência: ΔEprep e ΔSOC no evento, pico inalterado ~350 kW.
- Não adotar escala como controlador oficial (gate 13/15).

## Arquivos

- `causa_por_passo.csv` / `.mat`
- `influencia_janela.csv`
- `malha_fechada.csv`
- `j00014_*.mat`, `j00019_*.mat`
- `index_passos.json`, `status.json`, `execution.log`
