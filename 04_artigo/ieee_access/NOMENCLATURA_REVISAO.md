# Nomenclatura congelada — revisão IEEE Access

Usar estes termos no manuscrito, no response letter e nos CSVs. Não misturar.

| Termo | O que é | O que **não** é |
|-------|---------|-----------------|
| **Planta agregada** | Fonte + carga crítica + BESS/UPS de 1ª ordem (`τ_b`), SOC com `η_d/η_c`. | EMT, LCL, PLL, malhas internas de corrente/tensão. |
| **Golden V5** | MPC-QP MATLAB `quadprog`, `Np=60`, `Nc=15`. Campanha do artigo. | Firmware da placa. |
| **SIL** | Software-in-the-loop: mesma formulação FPGA-ready (`Np=12`,`Nc=4`) e o mesmo protocolo UART, planta em MATLAB (`backend='matlab_fpga'`). Já medido em `05_resultados/hil_de2115/`. | Placa física. |
| **FIL** | FPGA-in-the-loop via HDL Verifier / Ethernet da DE2-115 (licença de casa existe; lab a confirmar). Controlador na FPGA, planta no Simulink/MATLAB. | Data center real. |
| **HIL UART** | Hardware-in-the-loop: Nios na DE2-115, planta em MATLAB via RS-232 (`hil_loop_de2115`, `backend='serial'`). Fallback se FIL não estiver na banca. | Instalação de MW. |
| **Piso de potência (deste caso)** | `max(P_load − P_BESS^max, 0)`. No cenário de perda a 750 kW: `750−400=350` kW. | Lei universal / “physical floor” de qualquer planta. |
| **Foresight** | Vetores futuros (carga, limite, `g`) visíveis no horizonte. | Robustez a falta aleatória sem sinal. |
| **Confirmação / arm-horizon** | Só arma preparação agressiva quando o evento previsto está a ≤ `event_arm_horizon` passos **ou** o evento já ocorreu. | Foresight OFF. |
| **Trace NREL/Vercellino** | Potência medida (H100, 0,1 s) ou perfil facility-scaled com o método bottom-up do paper, reamostrado a `Ts=1 s` e afinizado à faixa 600–950 kW. | Degrau sintético Group A. |
| **Trace Alibaba** | Utilização GPU → `P = P_idle + (P_high−P_idle)·u`. | Medição elétrica de feeder. |

Claims permitidas após Fase 1–2:
- SIL (e FIL/HIL se o lab fechar) **validam o controlador embarcado** no modelo agregado.
- Traces públicos **substituem/complementam** os degraus sintéticos no Group A; não afirmam medição em feeder de data center próprio.
