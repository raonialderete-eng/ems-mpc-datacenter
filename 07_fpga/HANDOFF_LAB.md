# Handoff — EMS-MPC no laboratório (DE2-115)

Documento para abrir **no PC da faculdade**, sem esta conversa do Cursor.
Autor: Raoni. Placa: Terasic DE2-115 (Cyclone IV E **EP4CE115F29C7**).

Leve a pasta inteira `MPC_DATACENTER` (USB, Drive ou Git). O chat do Cursor **não** sincroniza entre PCs.

---

## 0. Ao sentar na banca (5 min)

1. Ligar a DE2-115 (fonte 12 V do kit) e o USB-Blaster (cabo USB da própria placa).
2. Abrir o Quartus que o lab usa (**um** só: Prime Lite 18.1 / 20.1 **ou** Quartus II 13.1 — não misturar).
3. Device Manager: deve aparecer **USB-Blaster**. Se não aparecer, instalar o driver da pasta do Quartus (`drivers`).
4. Copiar o projeto para um caminho **sem acento e sem espaço**, por exemplo `C:\MPC_DATACENTER`.
5. Preencher a tabela vazia em [`00_plataforma_lab.md`](00_plataforma_lab.md) (versão do Quartus, COM da UART, MATLAB da banca).

**Não altere** `01_matlab_base/controle_mpc_qp_v5.m` nem os `.tex` do artigo. O controlador da placa é o horizonte reduzido (`parametros_fpga.m`: Np=12, Nc=4).

---

## 1. O que já está pronto (casa) vs o que só fecha no lab

**Andamento casa 14/09/2026:** SoC + demo EMS heurística na placa **ok**. HIL MATLAB espera cabo USB–DB9 (sexta) e ELF com UART. Detalhe e comandos: [`00_plataforma_lab.md`](00_plataforma_lab.md) (secção *Status da bancada*).

| Pronto neste repositório | Só no lab / sexta |
|--------------------------|-----------|
| MATLAB FPGA-ready + SIL (`hil_loop_de2115`, `backend='matlab_fpga'`) | Cabo RS-232 + COM + `backend=serial` |
| C golden + ADMM (`c_golden/`) | ELF Nios 18/09: 228 KB / 26 KB livres no SOF 256 KB; SW[2]=MPC |
| Qsys 20.1 + `ems_de2115_time_limited.sof` | Regravar `.sof` se desligar a placa |
| Hello Nios (LEDR/HEX) + demo EMS HEX=SOC | Firmware HIL UART |
| Tabela SIL: faixas `Pnao=0`; perda ≈ 351 kW | Coluna **HIL-FPGA** no CSV |

Números de aceite (SIL, já medidos):

- `carga_faixas` / `limite_fonte`: MPC FPGA-ready → **Pnao_max = 0 kW**
- `perda_fonte` / `retorno_fonte`: **≈ 351 kW** (piso da V5 ≈ 350 kW)
- Heurístico: **90,98 kW** (faixas) e **592,61 kW** (perda) — igual à campanha do paper

Se o HIL da placa sair muito diferente disso no heurístico, o pinout/UART está errado, não o MPC.

---

## 2. Sessão A — Hello LED (prova a placa, sem Nios)

Objetivo: `LEDR[0]` pisca ~1 Hz; `SW[0]` acende `LEDR[1]`. `KEY[0]` = reset (solto = 1).

1. Quartus → **Open Project** → `07_fpga/quartus/hello_led.qpf`
2. Processing → Start Compilation (espere **Successful**)
3. Tools → Programmer → Hardware Setup → USB-Blaster → arquivo `output_files/hello_led.sof` → Start
4. Se não piscar: conferir jumper de alimentação, USB-Blaster, e se o device no Programmer é `EP4CE115F29C7`

Só avance se esta sessão passar. Pinout: `quartus/pins_de2_115.tcl`.

---

## 3. Sessão B — C golden no PC da banca (sem FPGA)

Objetivo: o C da planta/heurístico bate o MATLAB. Precisa de **gcc** (MinGW) ou do `nios2-elf-gcc` do Nios EDS.

No cmd / Git Bash, a partir de `07_fpga/c_golden`:

```bat
make
ems_golden --ctrl heur --cenario perda_fonte
ems_golden --ctrl heur --cenario carga_faixas
```

Compare `Pnao_max` com `05_resultados/hil_de2115/03_python_heuristico_kpi.csv` (ou `03_matlab_heuristico_kpi.csv`):

- `carga_faixas` heur ≈ **90.9796**
- `perda_fonte` heur ≈ **592.6123**

Erro aceitável no heurístico: &lt; 1e-3 kW. O MPC em C usa **ADMM**, não `quadprog`: compare **KPI** (`Pnao_max` no piso ~350 kW), não o comando bit a bit.

HIL por pipe (opcional, sem placa):

```bat
ems_golden --hil --ctrl mpc
```

No MATLAB da banca, se o `.exe` existir:

```matlab
cd('C:\MPC_DATACENTER\01_matlab_base')
hil_loop_de2115('backend','c_exe','controle','heur','cenario','perda_fonte')
```

---

## 4. Sessão C — SoC Nios (hello UART)

1. Abrir **Platform Designer / Qsys** no mesmo Quartus da sessão A.
2. Na pasta `07_fpga/quartus`, rodar:

```bat
qsys-script --script=nios_system.tcl
```

Se reclamar de `package require -exact qsys 16.1`, edite **só essa linha** no `.tcl` para a versão do lab (ex.: 13.1, 18.1) e rode de novo.

3. Generate HDL → o Qsys cria `nios_system/`.
4. Quartus → abrir `ems_de2115.qpf` → Compile → gravar `ems_de2115.sof`.
5. Nios Software Build Tools / Eclipse Nios:
   - Application: `07_fpga/nios_app/hello/hello_main.c`
   - BSP no Qsys gerado (on-chip memory 256 KB)
   - Run → nios2-terminal: deve imprimir `hello EMS DE2-115 UART+timer` e os LEDs contarem

UART da placa: **115200 8N1**. Conector RS-232 da DE2-115 (não é o USB-Blaster). No Windows, anote a porta **COM** (adaptador USB-serial se o PC não tiver DB9).

---

## 5. Sessão D — Firmware EMS + HIL MATLAB

### Switches (vale para o firmware EMS)

| SW | 0 | 1 |
|----|---|---|
| **SW[0]** | demo na placa (planta+cenário no Nios) | **HIL** (MATLAB manda medidas) |
| **SW[1]** | demo: `carga_faixas` | demo: `perda_fonte` |
| **SW[2]** | heurístico | MPC-ADMM |

**KEY[0]** = reset (pressionado = 0). Depois de mudar SW, dê reset.

LEDs (firmware EMS): `LEDR[0]` rede OK, `[1]` fallback, `[2]` modo evento, `[3]` Pnao &gt; 1 kW. HEX0/HEX1 ≈ SOC.

### Compilar o EMS no Nios EDS

Inclua as fontes de `07_fpga/c_golden` (veja `nios_app/ems/Makefile.fragment`):

- `ems_param.c`, `planta_bess.c`, `controle_heuristico.c`, `gera_cenario.c`
- `qp_admm.c`, `controle_mpc_fpga.c`, `ems_protocol.c`
- `nios_app/ems/ems_main.c`
- `-I../../c_golden`

Grave o ELF no Nios (Run). Demo: SW[0]=0, SW[1] escolhe cenário, SW[2]=0 primeiro (heurístico, mais fácil). A demo está **acelerada** (~20 ms/passo) só para o olho; **não** use esse tempo no paper.

### HIL de verdade (o que entra no IEEE)

1. SW[0] = **1** (HIL), SW[2] = 0 (heurístico) na primeira passagem.
2. Cabo serial PC ↔ RS-232 da DE2-115.
3. MATLAB:

```matlab
cd('C:\MPC_DATACENTER\01_matlab_base')
hil_loop_de2115('backend','serial','porta','COM3', ...
    'controle','heur','cenario','carga_faixas')
```

Troque `COM3` pelo valor do Device Manager.

4. Se o heurístico HIL bater o SIL (~91 kW / ~593 kW), suba SW[2]=1 e rode de novo com `'controle','mpc'` nos quatro cenários: `carga_faixas`, `limite_fonte`, `perda_fonte`, `retorno_fonte`.

5. Os resultados **acrescentam** linhas em `05_resultados/hil_de2115/02_hil_resultados.csv` (`backend=serial`). Isso vira a coluna da placa na tabela do paper.

Protocolo (PuTTY, se o MATLAB falhar): uma linha `REQ ...` e a placa responde `RSP ...`. Detalhe em [`protocolo/uart_hil.md`](protocolo/uart_hil.md).

**Ts do paper = 1 s.** O MATLAB espera ~1 s por amostra no HIL. Não acelere o laço serial.

---

## 6. MATLAB da banca (se tiver Optimization Toolbox)

```matlab
cd('C:\MPC_DATACENTER\01_matlab_base')
% Sem placa (reproduz casa):
hil_loop_de2115('backend','matlab_fpga','controle','mpc','cenario','perda_fonte')

% Varredura Np/Nc (opcional, demora):
main_validar_mpc_fpga
```

Se a banca **não** tiver `quadprog`, use só o HIL `serial` + os CSV já gravados em `05_resultados/hil_de2115/`.

---

## 7. Se travar

| Sintoma | O que checar |
|---------|----------------|
| Programmer não vê a placa | USB-Blaster, cabo USB da DE2-115 (não o HSMC), jumper de alimentação |
| Compila hello e não pisca | Device `EP4CE115F29C7`, `.sof` certo, KEY[0] não preso |
| Qsys `package require` | Versão no topo de `nios_system.tcl` |
| Nios não linka | Memória on-chip 256 KB; incluir todos os `.c` do golden |
| MATLAB `serialport` timeout | COM, 115200, SW[0]=1, firmware EMS (não o hello) rodando |
| Pnao HIL absurdo | Cabo TX/RX invertido; primeiro teste com `'controle','heur'` |
| MPC estoura 1 s no Nios | Manter heurístico no paper; ou reduzir ADMM `admm_max_iter` em `ems_param.c` e revalidar KPI |

---

## 8. O que fotografar / guardar para o artigo

- Foto da DE2-115 com LEDs no cenário `perda_fonte` (demo).
- Print do Programmer (device + `.sof`).
- CSV `02_hil_resultados.csv` **depois** das rodadas `serial`.
- Uma linha em `00_plataforma_lab.md`: Quartus, Nios, COM, MATLAB.

Não afirme no texto que a placa roda o QP de 315 variáveis da V5. Afirme: HIL do EMS com horizonte embarcável 12/4, mesma planta e métricas.
