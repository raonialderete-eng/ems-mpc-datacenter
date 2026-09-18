# Checklist comentário → secção TeX → CSV

Produto interno (não IEEE). Fonte: `PARECER_ITEM_A_ITEM.md`. Manuscrito: `04_artigo/ieee_access/artigo_ems_mpc_datacenter_access.tex`. Consolidação: `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/`. HIL: `05_resultados/hil_de2115/02_hil_resultados.csv`.

Páginas PDF após compile ainda não numeradas aqui; a carta cita **secção/tabela**, não página IEEE.

| ID | Pedido (paráfrase) | Secção / tabela TeX | CSV / evidência | Estado na carta |
|---|---|---|---|---|
| R1.1 | HIL / ensaio físico | §Embedded (`sec:embedded`), Tab.~`tab:sil` | `02_hil_resultados.csv` heurístico 4 cenários; ADMM UART parcial | Delimita: HIL heurístico sim; MPC serial 1200 não; FIL não |
| R1.2 | Traces AI/HPC | §Scenarios public traces | `dataset_v1/manifest.json` | NVML medido GPU; DIPLOEE simulado; errata `raw_*_W` |
| R1.3 | Timing / incerteza | §Forecast error, Tab.~`tab:err_time` | `grupo_timing.csv` V5 −10=350.00, +10=355.57, +20=511.76 | Substitui 699 kW; arm8 não mitigação |
| R1.4 | Timing probabilístico | mesmo + MC | MC 200 pares em consolidação | Delay de detecção ≠ lei MC; delimitar |
| R1.5 | Tuning comparável | §Control + fairness | fairness dU 120/200/400 | Heurístico não reotimizado; Δu nomes ≠ custos |
| R1.6 | Pesos | Tab.~`tab:weights`, §Information policy | sweep univariado 5 pesos | Não cobre todos os pesos; prioridade aproximada |
| R1.7 | τ / eficiências vs hardware | §Sensitivity Tab.~`tab:tau` | grupo tau/SOC | τ não valida célula/UPS |
| R1.8 | Multi-UPS | §Related Work | discussão só | Não implementado |
| R1.9 | Criticidade / shedding | §Related + §BESS dynamics + App.~`sec:appqp` | — | 100% crítica; QP z=315 |
| R1.10 | Headroom / ciclo | §Computational + §Embedded | cycle p50/p95 i7; DE2-115 separado | Não RT ADMM Lite 1 s |
| R1.11 | Falta longa | §Prolonged, Tab.~`tab:outage` | j01754/j01755; E 1309.95/1312.33; SOC_f 24.75/24.73 | MPC pior ~2.38 kWh |
| R1.12 | Literatura | Tab.~`tab:lit` | refs no `thebibliography` | Sem papers inventados |
| R1.13 | Reprodução | §Data Availability + GitHub | `jobs.json`, hashes | URL na carta R2.17 |
| R1.14 | Conclusões limitadas | título, abstract, §Conclusion | — | Eventos detectáveis; planta agregada |
| R2.1 | QP completo | App.~`sec:appqp` | FORMULACAO_QP.md / assembler | P_base=950, R_base=100, n_z=315 |
| R2.2 | Degraus vs dados | §Group A + traces | dataset_v1 | Sintéticos não calibrados pelo dataset |
| R2.3 | Informação causal | §`sec:infopol` | — | no_preview = retorno-ao-normal |
| R2.4 | Ablações / FF+FB | fairness + infopol | ablacao_isolada | FF+FB não acrescentado (justificado) |
| R2.5 | Timing amplo / gate | Tab.~`tab:err_time` | grupo_timing 41 pts | Gate arm8 não mitigação; FA repetidos não |
| R2.6 | Fallback / exitflag | §Implementation | FB% nas tabelas | Parte da política |
| R2.7 | SOC preditor | §Foresight | 100/8353; 0.044 pp | Sem violação da ref. por trechos |
| R2.8 | Míope fairness | fairness parágrafo | dU 120/200/400 | Coeficientes Δu desiguais |
| R2.9 | Normalização / cond(H) | infopol + §Computational | hess ~3.3e5; gram condest | Não “cond(C)” |
| R2.10 | 350 kW específico | Group B, (8), 14.5833 kWh | — | scenario-specific bound |
| R2.11 | UPS dinâmica | Related + model | — | Só continuidade de carga |
| R2.12 | Randomização | MC texto | 200 pares, 1 trajetória | Sem pop. de DCs |
| R2.13 | Ciclo p50/p95 / warm-start | §Computational | cycle_p50/p95; X0 vazio | Sem warm-start |
| R2.14 | SOC_f falta longa | Tab.~`tab:outage` | [600,7800) s; T_f=9600 | 24.75 / 24.73 não ~37% |
| R2.15 | Métricas extras | §Metrics | EFC proxy; T_gt1 | Prep. energy / reversões não consolidadas |
| R2.16 | Refs retratadas | `thebibliography` | sem sheng2026 | Auditoria online residual |
| R2.17 | Repo permanente | §`sec:data` | GitHub + Zenodo DOI TBD | Privado até submissão |
| R3.1 | Tabela [4]–[7],[22]–[24] | Tab.~`tab:lit` | Parisio, Wang, Nair, Sepehrzad, Iqbal | Qualitativa |
| R3.2 | IC previsão | MC parágrafo | média −9.04; IC [−14.02,−4.79] | Trajetória física fixa |
| R3.3 | Pesos | Tab.~`tab:weights` + infopol | — | Univariado |
| R3.4 | 1ª ordem altera ranking? | Tab.~`tab:tau` | ranking preservado | Não valida dinâmica rica |
| R3.5 | Picos 90.98 iguais | §Metrics | 150 e^{−1/2} | 400 s vs 200 s |
| R4.C1 | Novidade | §Related + intro | protocolo comparativo | Sem teoria nova; sem 699 como novidade |
| R4.C2 | Validação além sim | §Embedded | HIL heur 4 cenários | Placa = controlador, não UPS MW |
| R4.C3 | Dataset público | traces | NVML/DIPLOEE | Não feeder 600–950 medido |
| R4.C4 | Timing probabilístico | timing + MC | grupo_timing auditado | −10 s ≠ 699 |
| R4.C5 | EMS preditivo estocástico | §Stochastic | 3 cenários π=1/3 | Classe do projeto, não benchmark publicado |
| R4.C6 | Pesos ordens | Tab.~`tab:weights` | — | Prioridade aproximada |
| R4.C7 | RT hardware | §Embedded | i7 vs DE2-115 | Sem Ts=1 s ADMM Lite |
| R4.C8 | Degradação bateria | métricas + conclusion | EFC | Recusa: proxy, não lifetime |
| R4.C9 | Dinâmica rica | model + limitations | — | Escopo agregado |
| R4.C10 | Robustez estatística | MC | janelas sobrepostas | Sem representatividade populacional |
| R4.C11 | Especificidade DC | intro + traces + 100% crítica | — | Planta genérica + cargas AI mapeadas |
| R4.C12 | Conclusões qualificadas | conclusion | Tab.~outage MPC pior energia | Sem zero universal |
| R5.1 | Precisão timing | Tab.~`tab:err_time` | ≤351 kW em [−20,+4] s | Critério descritivo |
| R5.2 | Míope pior | fairness | 102.78→0 com dU | Não só horizonte |
| R5.3 | Título/abstract | title, abstract | — | Aggregated load; detectable events |
| R5.4 | SOC / gerador | Tab.~outage + Related | gerador não simulado | Discussão só |
| R5.5 | Parâmetros não ID / ruído | conclusion | — | Sem ruído de medição; sem ID de campo |
