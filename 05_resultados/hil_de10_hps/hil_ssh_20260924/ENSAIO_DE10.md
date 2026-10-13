# Ensaio Fase 1 — DE10-Standard (HPS / Cortex-A9) — OSQP

**Nao e FIL.** OSQP em C no ARM, planta MATLAB, `t_us` medido. Artigo Access: so se o portao da **placa** fechar com Grupo A ~0 kW (OSQP, nao ADMM).

Versao deste kit: **`EMS_FASE1_DE10_NOTEBOOK-OSQP-20260922`**. Solver primario **OSQP**. `make` na placa (sem CMake, sem qpOASES).

| Campo | Valor |
|-------|--------|
| Status casa | **Golden PC OSQP.** Heuristico bate SIL (~90.98). MPC OSQP: carga 0.0063 kW FB 0 SOC 59.06 %; limite ~0; perda/retorno 351.169 kW FB 0; Eun 14.584 / 24.306 kWh. |
| Status placa | **Golden ARM + qp_campaign + HIL SSH (casa, 2026-09-24).** LXDE, eth0 `192.168.1.147`. UART COM5 ainda mudo. HIL = MATLAB `c_exe` + `hil_ssh.bat` → `ems_hps --hil` (nao `--hil-uart`). CSV/MAT em `../06_resultados_banca/`. Nao Access. |
| Data pacote | 2026-09-22 |
| Binario host | `ems_hps.exe` existe em casa — **nao** esta neste zip e **nao** vai para o ARM. |
| Placa | Terasic DE10-Standard (HPS A9). **Nao** DE10-Lite. |
| Protocolo | `../03_protocolo/uart_hil.md` — 115200 8N1 ou stdin SSH |
| MATLAB | `../02_matlab_pc/` (`rodar_hil_banca.m` + `hil_loop_de2115.m`) |
| Dumps | `../04_dumps_pc/` + `treino_all.csv` (PC) |
| Nios / DE2-115 | intocado |
| Artigo | **nao** atualizar. Magri 0.6 tambem nao entra. |
| FIL solver | **nao existe** (`fil_fase2_admm/` nunca criada) |

## Golden casa OSQP (PC) — alvo da placa, sem tempos ARM

| controle | cenario | Pnao_max | fallback | notas |
|----------|---------|----------|----------|-------|
| heur | carga_faixas | 90.98 | 0 | SIL |
| mpc osqp | carga_faixas | **0.0063** | **0** | SOC 59.06 % |
| mpc osqp | limite_fonte | **~0** | **0** | |
| mpc osqp | perda_fonte | **351.169** | **0** | Eun 14.584 kWh |
| mpc osqp | retorno_fonte | **351.169** | **0** | Eun 24.306 kWh |

Se a placa der **~11.67 / ~381**, compilou o ADMM antigo — ensaio **falhou**. Historico ADMM (nao alvo): `VALIDACAO_ADMM.md`.

## Inventario na 1a sessao (preencher na banca)

| Item | Anotar aqui |
|------|-------------|
| Confirmar Standard (HPS + UART, nao Lite) | Sim. DE10-Standard, `root@DE10-Standard`, 7-seg 888888 |
| Linux no SD (imagem Terasic) sim/nao | Sim. LXDE `4.5.0-00198-g6b20a29` 2017-04-27 `armv7l` |
| `gcc -v` no HPS | `arm-linux-gnueabihf` **5.4.0** 20160609 (Ubuntu/Linaro 5.4.0-6ubuntu1~16.04.4) |
| UART-USB = COMx no PC Windows | COM5 FT232, 0 bytes (LXDE no VGA). HIL desta sessao **nao** usa UART. |
| IP Ethernet / SSH | **192.168.1.147/24** (`dhclient eth0`). sshd no ar. chave `%USERPROFILE%\.ssh\de10_hps`. BatchMode `uname` OK. |
| `clock_gettime` ok (`t_us` ≠ 0 no 1o RSP MPC) | Sim. Smoke `RSP ... t_us=1234`. HIL p50 ~2.4–2.5 ms. |
| `VERSION.txt` = `EMS_FASE1_DE10_NOTEBOOK-OSQP-20260922` | Sim. |
| Quartus da banca (so se for Magri 0.6) | nao |

## Golden ARM (planta no HPS, 2026-09-24; nao e HIL)

| Cenario | `Pnao_max` | fallback | `t_us` p50 | max |
|---------|------------|----------|------------|-----|
| carga_faixas | **0.006312** SOC 59.060 | 0 | 3844 | 195378 |
| limite_fonte | **0.000305** | 0 | 2459 | 44510 |
| perda_fonte | **351.169** | 0 | 3187 | 78069 |
| retorno_fonte | **351.169** | 0 | 3317 | 78400 |

Campanha `/root/06_resultados_banca/arm_osqp.csv`: 11 dumps, native=solved, kkt=1, app=1.

## Portao HIL SSH (planta MATLAB, OSQP no ARM, 2026-09-24)

Backend `c_exe` / `hil_ssh.bat` / `ems_hps --hil --ctrl mpc --qp-solver osqp`. `t_us` so da RSP. MAT: `06_resultados_banca/hil_c_exe_mpc_*.mat`. CSV: `06_resultados_banca/02_hil_resultados.csv`.

| Cenario | `Pnao_max` alvo PC OSQP | Medido HIL | `t_us` p50 | p95 | max | overrun | fallback % |
|---------|-------------------------|------------|------------|-----|-----|---------|------------|
| carga_faixas | ~0.0063 | **0.000** SOC 59.07 | 2488 | 7220 | 211681 | 0 | 0.000 |
| limite_fonte | ~0 | **0.000** SOC 51.10 | 2526 | 4194 | 30967 | 0 | 0.000 |
| perda_fonte | ~351.169 (nao 381, nao 592) | **351.169** Eun 14.584 | 2418 | 5686 | 89007 | 0 | 11.583 |
| retorno_fonte | ~351.169 (nao 381, nao 592) | **351.169** Eun 24.306 | 2416 | 5298 | 83120 | 0 | 19.917 |

`Ts = 1 s` ok: max(`t_us`) = 211681 < 1e6, overrun 0 nos 4. Pnao nao e 11.67/381 (nao e ADMM antigo). Fallback HIL em perda/retorno **nao** e 0 (golden ARM em batch era 0). Nao inventar numero. Nao gravar `.sof` Nios da DE2-115. **Nao** escrever no Access.

Opcional no mesmo dia: FIL Magri Fase 0.6 (nao e pre-requisito; nao e Fase 2).
