# Plataforma — EMS-MPC DE2-115

Inventário **S0 — 14/09/2026**, nesta máquina (casa = bancada). A placa estava ligada e o USB-Blaster visível. Isto **não** é HIL nem FIL: só registro de ferramentas e cadeia JTAG.

## Esta máquina (desenvolvimento + bancada)

| Item | Valor |
|------|--------|
| Data do inventário | 2026-09-14 |
| SO | Windows 10 Pro 10.0.19045 |
| MATLAB | R2025b (`25.2.0.2998904`), `C:\Program Files\MATLAB\R2025b\bin\matlab.exe` |
| Optimization Toolbox | sim |
| Simulink / HDL Coder / HDL Verifier / Fixed-Point Designer | sim (licença local; **não usados** no caminho Nios/HIL UART) |
| Quartus (bancada ativa) | Prime Lite **20.1.1.720**, `D:\intel\quartus\bin64\quartus.exe` (Nios II + Cyclone IV) |
| Nios II EDS | 20.1std Build 720, `D:\intel\nios2eds` |
| `nios2-elf-gcc` | `D:\intel\nios2eds\bin\gnu\H-x86_64-mingw32\bin\nios2-elf-gcc.exe` |
| Quartus 25.1 | desinstalado / não usar neste S4 (não tem `nios2_gen2`) |
| gcc Windows (C golden no PC) | pendente após desinstalar o 25.1 (Questa ia em `D:\altera_lite`); S2 usa gcc à parte |
| Python no PATH | ausente; venv do projeto: 3.12.14 (`.venv_revisao`) |
| Qsys | `nios_system.tcl` em API 20.1; HDL gerado |

Campanha MATLAB histórica do artigo (referência): Intel Core i7-4510U @ 2.0 GHz, `quadprog` interior-point-convex (`05_resultados/revisao_ieee_applied/00_plataforma.txt`).

## Kit nesta mesa (S0)

| Item | Valor medido / conferido |
|------|--------------------------|
| Kit | Terasic DE2-115, alvo **EP4CE115F29C7** (Cyclone IV E) |
| Clock da placa | 50 MHz (`CLOCK_50`, PIN_Y2) |
| Clock do Nios (alvo) | 50 MHz no hello; 100 MHz só se o PLL fechar timing |
| USB-Blaster | **OK** — Device Manager: `Altera USB-Blaster`, `USB\VID_09FB&PID_6001\91D28408` |
| Hardware JTAG | `USB-Blaster [USB-0]` (`jtagconfig` / `quartus_pgm --list`) |
| IDCODE lido | `020F70DD` — é o ID do **EP4CE115**. O Quartus 25.1 **rótula** a cadeia como `10CL120(Y\|Z)/EP3C120/..` porque o mesmo código aparece em vários dispositivos. No Programmer, escolher **EP4CE115F29C7**, não 10CL120. |
| UART HIL (RS-232) | **ausente nesta sessão**. Não há porta COM válida. `COM3` (`VID_0000&PID_015E`) está *phantom* e **não** é o USB-Blaster. HIL serial espera cabo RS-232/USB-UART (115200 8N1). |
| Ethernet 0 | NIC do PC (Realtek) ligada; **não** é FIL. Reserva, fora do caminho crítico. |

### Checklist S0

- [x] Quartus 25.1 Lite localizado e versão registrada.
- [x] DE2-115 ligada; USB-Blaster enumerado; cadeia JTAG com ID `020F70DD`.
- [x] Hello LED (S3, 14/09/2026): `hello_led.sof` gravado via JTAG; `LEDR[0]` pisca; HEX mostra **10**. Device no Programmer: **EP4CE115F29C7** (não 10CL120). SRAM: o demo de fábrica some até o próximo power-cycle.
- [ ] Cabo RS-232/USB-UART identificado com COM real (antes do HIL).
- [x] Qsys 20.1: `nios_system.qsys` gerado (`altera_nios2_gen2` Fast, 256 KB, UART 115200). HDL em `07_fpga/quartus/nios_system/synthesis`.
- [x] Quartus 20.1: `ems_de2115` **Successful**. Programmer: `ems_de2115_time_limited.sof` (OpenCore Plus, Nios II/f Lite ~1 h). Device **EP4CE115F29C7**.
- [ ] Cabo RS-232: UGREEN USB–DB9 PL2303 pedido (Prime, ~18/09/2026). Encaixa no **DB9 da placa**, não no USB-Blaster.

## Status da bancada — 14/09/2026 (parar aqui; retomar na sexta)

Casa = bancada. WSL1 Ubuntu (`raoni`). Eclipse Nios 20.1 **não abre**; build/download via scripts.

### O que deu certo

1. **Hello LED** (`hello_led.sof`): `LEDR[0]` pisca; HEX **10**.
2. **SoC Nios** gravado: `quartus/output_files/ems_de2115_time_limited.sof` (não usar `hello_led.sof` neste passo).
3. **Toolchain WSL:** `nios2-elf-gcc.exe` não acha `cc1` se chamado direto do WSL. Compilar com wrap `hello_wsl/winbin` (`cmd.exe`). Makefile do app: gerar **dentro** da pasta `app` (`--src-files`, não `--src-dir .` a partir de `C:\Users\Rauni`).
4. **Download ELF:** `nios2-download` é script bash — só via WSL (`download_hello_wsl.sh` / `download_ems_wsl.sh`). PATH do PowerShell quebra com `(x86)`. `nios2-terminal` no PowerShell conecta, mas `alt_printf` **trava** o CPU se o terminal não estiver lendo.
5. **Hello Nios (LEDs):** BSP sem `hal.sys_clk_timer` (timer Qsys em **1 µs** matava o `main`) e sem JTAG stdio. HEX 88 = PIO em reset (7-seg ativo-baixo). Hello que **pisca HEX+LEDR** = `hello_wsl/app/hello_ems.elf`.
6. **Demo EMS na placa (sem MATLAB):** `ems_wsl/app/ems.elf` (~20 KB). HEX **SOC** (60 → 58 → 59 → 60). LEDR0 = rede. SW[0] baixo, SW[1] baixo = `carga_faixas`. Voltar a 60 e repetir = fim de uma passagem (o `main` recomeça).
7. **ADMM no mesmo SOF 256 KB (18/09/2026):** ELF `ems_wsl/app/ems.elf` com `qp_admm.c` + `controle_mpc_fpga.c` + pool `ems_work` (H/K overlay). Link **-O2 -msmallc**: **228 KB** programa, **26 KB** stack+heap. **Não** foi preciso subir on-chip nem recompilar o `.sof`. SW[2]=1 chama MPC; SW[2]=0 continua heurístico. Download desta sessão: JTAG ausente nesta máquina — gravar na placa com o Blaster ligado.

### O que falta (sexta / cabo)

- Adaptador **USB–RS-232 DB9** no conector serial da DE2-115 (não Ethernet, não VGA, não o segundo USB, não o Blaster).
- Device Manager: `COMx` real (não `COM3` VID_0000).
- ELF HIL: UART + heurístico (e ADMM se couber: overlay de buffers ou mais on-chip + novo `.sof`).
- MATLAB: `hil_loop_de2115('backend','serial','porta','COMx',...)`.

### Comandos (PowerShell). Enter depois da linha. Switch da placa em **RUN**.

Programmer fechado. Se a placa **desligou**, Programmer → `ems_de2115_time_limited.sof` → 100%, USB-Blaster ligado (OpenCore Plus).

```
wsl.exe -d Ubuntu -u raoni -- bash /mnt/c/Users/Rauni/Documents/MPC_DATACENTER/07_fpga/nios_app/download_ems_wsl.sh
```

Rebuild EMS (se mexer no C):

```
wsl.exe -d Ubuntu -u raoni -- bash /mnt/c/Users/Rauni/Documents/MPC_DATACENTER/07_fpga/nios_app/build_ems_wsl.sh
```

Hello LEDs (regressão): `download_hello_wsl.sh` + `hello_ems.elf`.

Quartus só: `D:\intel` (20.1). Não misturar com 25.1 / `D:\altera_lite`.

## Parâmetros congelados do controlador FPGA

Definidos em `01_matlab_base/parametros_fpga.m` (não alterar a V5 do artigo):

- `Ts = 1 s` (HIL e paper). Demo standalone pode acelerar o *display*, nunca o tempo de solve reportado.
- `Np = 12`, `Nc = 4` → `nvar = Nc + 5*Np = 64`
- `Nprep = 12` (cabe no horizonte; `dUmax_evento = 400 kW/passo` ainda permite subir o BESS a tempo da dinâmica `τ_b = 2 s`)
- Fallback heurístico se o QP/ADMM falhar
- UART 115200 8N1, protocolo em `07_fpga/protocolo/uart_hil.md`

## O que este PC consegue gerar agora

- Campanha MATLAB V5 vs MPC reduzido vs heurístico → CSV em `05_resultados/hil_de2115/`
- Software-in-the-loop (`hil_loop_de2115.m`, `backend='matlab_fpga'`) com o **mesmo protocolo** do HIL
- Compilação Quartus / gravação `.sof` **nesta máquina** (S3 em diante)
- Fontes C, Verilog, Qsys TCL e firmware Nios; C golden no PC via gcc do Questa
- HIL UART: só depois de existir COM real e firmware EMS
