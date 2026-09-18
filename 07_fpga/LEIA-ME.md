# EMS-MPC na DE2-115

**Estado 14/09/2026 (casa):** Quartus 20.1 em `D:\intel`. Demo EMS na DE2-115 ok (HEX=SOC). HIL MATLAB na sexta, com cabo USB–DB9. Texto completo: [00_plataforma_lab.md](00_plataforma_lab.md).

**No lab / ao reabrir:** [HANDOFF_LAB.md](HANDOFF_LAB.md).

## Ordem no laboratorio

1. Preencher a tabela vazia em `00_plataforma_lab.md`.
2. `quartus` → abrir `quartus/hello_led.qpf` → Compile → Programmer (USB-Blaster). `LEDR[0]` pisca; `SW[0]` em `LEDR[1]`.
3. Platform Designer: `qsys-script --script=nios_system.tcl` (se a versao do Qsys reclamar do `package require`, ajuste o numero). Generate → compile `ems_de2115.qpf`.
4. Nios EDS: projeto hello (`nios_app/hello/hello_main.c`) → eco no nios2-terminal.
5. `c_golden`: `make test` (MinGW/gcc da banca) e conferir KPI vs `05_resultados/hil_de2115/03_matlab_heuristico_kpi.csv`.
6. Firmware EMS (`nios_app/ems`) com fontes de `c_golden`.
7. MATLAB da banca: `hil_loop_de2115('backend','serial','porta','COMx')`.

## MATLAB neste PC (sem placa)

```matlab
cd 01_matlab_base
main_validar_mpc_fpga   % V5 vs horizonte 12/4
teste_c_golden          % CSV de referencia do heuristico
main_sil_hil_fpga       % SIL do protocolo HIL + tabela
```
