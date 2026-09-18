# Resultados HIL / SIL — DE2-115

Gerados neste PC (MATLAB SIL). Bitstream e UART da placa so no laboratorio.

| Arquivo | Conteudo |
|---------|----------|
| `00_plataforma.txt` | apos `main_validar_mpc_fpga` |
| `01_matlab_v5_vs_fpga.csv` | V5 vs horizonte 12/4 vs varredura |
| `02_hil_resultados.csv` | SIL (`matlab_fpga`); no lab acresce `serial` |
| `03_matlab_heuristico_*.csv` | referencia bit-a-bit do C golden |
| `03_python_heuristico_kpi.csv` | conferiu Pnao do heuristico = campanha do artigo |
| `04_tabela_ieee_fpga.md` | rascunho da tabela do paper |

Aceite ja observado no SIL (`Np=12`, `Nc=4`):

- `carga_faixas` / `limite_fonte`: `Pnao_max = 0` (igual V5)
- `perda_fonte` / `retorno_fonte`: `Pnao_max ≈ 351 kW` (piso V5 ≈ 350 kW)
- heuristico: `90.98` / `592.61` kW (bate o CSV da revisao IEEE)
