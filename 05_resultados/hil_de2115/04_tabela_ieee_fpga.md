# Evidencia embarcada (rascunho IEEE)

Setup alvo: DE2-115, Nios II, UART 115200, Ts = 1 s, Np=12, Nc=4.

Limitacoes honestas: horizonte menor que a V5; solver na placa e ADMM (nao `quadprog`);
planta ainda agregada; bitstream Quartus so no laboratorio. A coluna SIL deste PC
usa a **mesma formulacao FPGA-ready** (`controle_mpc_qp_fpga`) e o **mesmo protocolo**
do HIL fisico.

## MATLAB-V5 | MATLAB-reduzido (SIL) | heuristico

| cenario | Heuristico Pnao_max | V5 Np=60 Pnao_max | FPGA Np=12 Pnao_max | V5 t_qp_max_s | FPGA t_qp_max_s |
|---------|---------------------:|------------------:|--------------------:|--------------:|----------------:|
| carga_faixas | 90.98 | **0** | **0** | 0.322 | 0.517 (1o passo) |
| limite_fonte | 90.98 | **0** | **0** | 0.131 | 0.097 |
| perda_fonte | 592.61 | **350.08** | **351.17** | 0.192 | 0.041 |
| retorno_fonte | 592.61 | **350.05** | **351.17** | 0.194 | 0.019 |

Foresight OFF na V5 (`perda_fonte`) = 592.57 kW (pior que ON). O SIL FPGA-ON ficou no piso fisico (~350 kW), como a V5.

Fonte V5: `05_resultados/revisao_ieee_applied/01_comparacao_controladores.csv`.
Fonte FPGA/heur: SIL `hil_loop_de2115` (`02_hil_resultados.csv`).

## SIL / protocolo HIL

| backend | controle | cenario | Pnao_max | t_us_max | overrun | pct_fallback |
|---------|----------|---------|----------|----------|---------|--------------|
| matlab_fpga | heur | carga_faixas | 90.980 | 0 | 0 | 0.00 |
| matlab_fpga | mpc | carga_faixas | 0.000 | 517275 | 0 | 0.00 |
| matlab_fpga | heur | limite_fonte | 90.980 | 0 | 0 | 0.00 |
| matlab_fpga | mpc | limite_fonte | 0.000 | 97316 | 0 | 0.00 |
| matlab_fpga | heur | perda_fonte | 592.612 | 0 | 0 | 0.00 |
| matlab_fpga | mpc | perda_fonte | 351.169 | 41210 | 0 | 0.00 |
| matlab_fpga | heur | retorno_fonte | 592.612 | 0 | 0 | 0.00 |
| matlab_fpga | mpc | retorno_fonte | 351.169 | 19059 | 0 | 0.00 |

Nenhum overrun em Ts = 1 s. No lab: `hil_loop_de2115('backend','serial','porta','COMx')` para preencher a coluna da placa.

## WCET

Rode `python 07_fpga/scripts/gerar_figura_wcet.py`. O pico de 0,52 s em `carga_faixas` e o primeiro `quadprog` (aquecimento); p99 fica em dezenas de ms.

## Varredura Np/Nc

Script pronto: `01_matlab_base/main_validar_mpc_fpga.m` (flag `FAZER_VARREDURA`). Horizonte congelado **12/4** ja passou o aceite qualitativo das claims do artigo.
