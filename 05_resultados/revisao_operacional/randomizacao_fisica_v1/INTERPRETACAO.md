# Physical / operational randomization sensitivity

Grupo `physical_operational_sensitivity`. **Não** é extensão informal dos 200 pares Monte Carlo.

Os 200 pares Monte Carlo avaliam incerteza de previsão sob uma trajetória física comum. Este experimento adicional de randomização física avalia a sensibilidade das conclusões a variações de condições operacionais e parâmetros da planta.

Consolidação oficial e Tabela 7 **intocadas**. Previsão alinhada à planta. Erro de previsão fora deste sorteio.

Desenhos: 32 (16 perda / 16 limite). Controladores: V5, míope, FF+FB.

| ctrl | n | med P-bound | p95 P-bound | frac |P-bound|<=1 kW | med E kWh | med SOC_pre | med SOC_final |
|---|---:|---:|---:|---:|---:|---:|---:|
| mpc_qp_v5 | 32 | 0.024 | 0.358 | 0.969 | 3.9557 | 50.277 | 46.389 |
| miope_qp | 32 | 195.323 | 352.244 | 0.000 | 4.2351 | 50.732 | 47.259 |
| ff_feedback | 32 | 2.788 | 228.629 | 0.469 | 4.0092 | 50.358 | 46.861 |

CSV: `resumo.csv`. Amostragem: latin ranks (`lhsdesign` indisponível neste MATLAB). Seed `20260919`.

## Por tipo

### perda (n=16)
- mpc_qp_v5: no bound do caso (P ≈ L_evento−400)
- miope_qp: pico sistematicamente acima do bound (primeiro degrau / dUmax)
- ff_feedback: perto do bound na maioria; em alguns desenhos coincide com o míope (sem preparação suficiente)

### limite (n=16)
- mpc_qp_v5 e ff_feedback: pico filtrado ~0 na quase todos (bound 0 quando L−M≤400)
- miope_qp: residual de rampa (dezenas a ~200 kW)

**Não usar:** IC bootstrap destes 32 como se fossem os 200 pares; população de data centers; mistura com Tabela 7.

## Por tipo

