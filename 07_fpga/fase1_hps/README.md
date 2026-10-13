# Fase 1 — OSQP no ARM (DE10-Standard)

**Não é FIL.** Solver primário = **OSQP** em C (`qp_osqp.c`, `qp_engine.c` com `QP_DEFAULT_OSQP`). Makefile empilha OSQP + QDLDL **sem CMake**. Planta e cenário no MATLAB. qpOASES (C++) fica no PC (`build_campaign.ps1`); na placa o stub recusa `--qp-solver qpoases` a menos que `QP_WITH_QPOASES`.

Isto **não** é a campanha `main_revisao_fase1.m`. **Não** é FIL do QP — `07_fpga/fil_fase2_admm/` **nunca foi criada**.

Não mexer: `01_matlab_base/controle_mpc_qp_v5.m`, Quartus/Nios da DE2-115, `.tex` Access.

ADMM permanece no tree. Auditoria histórica: [`DIAGNOSTICO_ADMM.md`](DIAGNOSTICO_ADMM.md), [`VALIDACAO_ADMM.md`](VALIDACAO_ADMM.md) — **ADMM C não passou** Grupo A ~0 (`c_exe` faixas ≈11.68 kW / perda ≈381). Não reescrever essas seções como sucesso. Zip ADMM **`fase1_hps-P1-20260919-r2` não é** o binário OSQP.

Pacote da banca: `EMS_FASE1_DE10_NOTEBOOK/` (zip irmão na raiz do repo).

## O que é casa vs universidade

| Onde | O quê |
|------|--------|
| Casa | `make` host / campanha Windows; golden OSQP no PC |
| Universidade | Linux no HPS da **DE10-Standard**, `make` → `ems_hps` + `qp_campaign`, UART 115200 ou SSH |
| Fora | FIL-do-solver, HDL, Bishop, MPC Toolbox, V5 `Np=60`, `ems_hps.exe` no ARM |

## Compilar (casa / WSL / HPS)

```
cd 07_fpga/fase1_hps
make
make test
```

Cross ARM (se existir `arm-linux-gnueabihf-gcc`):

```
make arm
```

No Linux da Standard, o mesmo `make` com o `gcc` da placa gera o binário nativo. Windows `make` pode falhar por tamanho da linha — o ensaio é o `make` no HPS.

## Golden (sem placa)

```
ems_hps --ctrl heur --cenario carga_faixas
ems_hps --ctrl mpc --qp-solver osqp --cenario carga_faixas
```

Heurístico: `Pnao_max ≈ 90.98` (faixas). **OSQP PC:** carga **0.0063 kW** FB 0 SOC **59.06 %**; limite **~0**; perda/retorno **351.169 kW** FB 0; Eun **14.584 / 24.306 kWh**. Se **11.67 / 381**, compilou ADMM antigo.

MATLAB (casa, path do repo):

```matlab
cd 01_matlab_base
main_fase1_hps
```

## HIL na DE10-Standard

Protocolo: [`../protocolo/uart_hil.md`](../protocolo/uart_hil.md).

```
./ems_hps --hil --ctrl mpc --qp-solver osqp
./ems_hps --hil-uart /dev/ttyS0 --ctrl mpc --qp-solver osqp
```

Passo a passo: [`PASSO_LAB_DE10.txt`](PASSO_LAB_DE10.txt). Inventário: [`ENSAIO_DE10.md`](ENSAIO_DE10.md). Wrapper SSH: [`hil_ssh.sh`](hil_ssh.sh).

## Portão

Casa PC OSQP: heurístico ok; Grupo A ~0; contingência ~351.169. **Tempos ARM não inventar.** Placa: tabela em `ENSAIO_DE10.md`. Access congelado. Kit banca **`EMS_FASE1_DE10_NOTEBOOK-OSQP-20260922`**.
