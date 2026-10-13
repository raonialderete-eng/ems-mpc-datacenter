# Fairness síntese (Fase 1) e parâmetros comparáveis (Fase 2)

Consolidação oficial e Tabela 7 **intocadas**.

## Conclusão travada da Fase 2

Harmonizamos os parâmetros diretamente comparáveis e verificamos que a diferença principal persiste; as arquiteturas, contudo, mantêm diferenças estruturais em seus objetivos, incluindo termos de horizonte, terminal, slack e recarga.

English: We harmonized the directly comparable parameters and verified that the main difference persists; the architectures, however, retain structural differences in their objectives, including horizon, terminal, slack and recharge terms.

**Não usar:** “agora a comparação é completamente justa”; objetivos idênticos; fairness integral.

## Escolha do coeficiente Δu

Compensar `/Pbase^2` no míope: `w_mpc_delta_u = 50 * 950^2 = 45125000`, de modo que `w_eff = w_V5 = 50` no termo Δu em modo normal. O V5 **não** recebe a divisão por `Pbase^2`. Terminal, slacks de horizonte e recarga/evento do V5 **não** foram reotimizados. Em modo evento o V5 ainda usa `0.1*w_delta_u` (diferença estrutural restante).

Fill: persistence. `dUmax = dUmax_evento = 400`. `common_slew`. `Pbase=950`, `Rbase=100`. Cenários: `carga_faixas` e `perda_fonte`.

## Fase 1

Janelas ±20 s e conjunto ativo: `C:/Users/Rauni/Documents/MPC_DATACENTER/05_resultados/revisao_operacional/fairness_sintese_v1` (`comando_eventos.csv`, `ativo_por_evento.csv`). Builders separados: `montar_qp_miope_sintese` vs `montar_qp_auditado`. MATs B3 NVML ausentes no disco; âncora NVML 400 kW/s = `j00162`.

## Fase 2 — números

- faixas míope alinhado: P_raw=114.3007 P_filt=114.3007 kW
- faixas V5: P_raw=0.0181 P_filt=0.0000 kW
- faixas FF+FB: P_raw=0.0000 P_filt=0.0000 kW
- faixas heurístico (âncora de rampa, não mesmo custo): P_raw=90.9796 kW
- perda míope alinhado: P_raw=592.6123 kW
- perda V5: P_raw=350.0690 kW
- perda FF+FB: P_raw=355.9501 kW
- perda heurístico (âncora): P_raw=592.6123 kW

Critério pré-registrado: na perda, se o míope alinhado continuar ~593 kW e o V5 ~350 kW, a diferença principal persiste após harmonizar rampa + coeficiente Δu + fill. **Confirmado** (592.61 vs 350.07 kW). Em faixas, o zero filtrado com 400 kW/s no fairness 11/09 era o míope *sem* alinhar o coeficiente; com `w_eff=50` o míope fica em 114.30 kW e V5/FF+FB no zero filtrado — isso **não** contradiz a perda e mostra que o zero da varredura 400 kW/s dependia do `w_du/Pbase²` fraco.

Ativos (Fase 1, `ativo_por_evento.csv`): no degrau 950 kW o míope principal satura `|Δu|=dUmax` (120 kW/s) com slack de carga; o V5 não satura Δu e ativa `source_limit` + `slack_event`. Na falta, ambos aplicam ~400 kW; o míope via `sat_du`, o V5 via `sat_u_max` + slack de evento. Fairness 400 no degrau 950: míope `sat_du` em 400 kW/s; V5 continua sem saturar Δu.

Figuras: SVG em `fairness_sintese_v1/figuras/` (sem GUI MATLAB).

CSV: `C:/Users/Rauni/Documents/MPC_DATACENTER/05_resultados/revisao_operacional/fairness_harm_v1/resumo.csv`.
