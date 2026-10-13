# EMS-MPC for an aggregated AI/HPC data-center load with BESS

Reproduction package for the IEEE Access manuscript on predictive energy management of an aggregated critical load with battery energy storage.

- **Code:** https://github.com/raonialderete-eng/ems-mpc-datacenter — tag `v1.0.5-ieee-access-rev`.
- **Zenodo (previous code snapshot, tag v1.0.4):** https://doi.org/10.5281/zenodo.22846250 — MATLAB/TeX tree; **not** the campaign job MATs and **not** the 24 Sep 2026 DE10 HIL CSVs.
- **Experimental packs (public):** `07_Experimental_Pack.zip` on tag `v1.0.4` (job MATs, `dataset_v1`, B2–B6 including `B2_ff_0005`, audited MATLAB); `08_Experimental_Addendum.zip` on tag `v1.0.5` (OSQP/DE10 HIL CSVs, diagnostic CSVs).
- **Do not use** https://doi.org/10.5281/zenodo.22837544 (tag `v1.0.2`).

Please cite the published article (title and DOI as printed). Cite GitHub tag `v1.0.5` for this revision’s tree; cite the Zenodo record above only as the frozen v1.0.4 snapshot.

## Scope of the evidence

| Item | In this repository |
|---|---|
| Desktop campaign (MATLAB R2025b, Optimization Toolbox) | Yes — consolidation of 11 Sep 2026 |
| Nios C/ADMM, UART protocol | Yes — `07_fpga/` (demonstration, not a 1200-step KPI table) |
| SIL (`backend=matlab_fpga`, \(N_p=12\), \(N_c=4\)) | Yes — `05_resultados/hil_de2115/` |
| UART HIL of the **heuristic** (four short scenarios, DE2-115) | Yes — matches SIL; firmware `t_us=0` |
| UART HIL of ADMM / 1200-step serial ADMM | No (OpenCore Plus ~1 h; QP ≫ \(T_s\) on Nios) |
| OSQP PC loop + qpOASES reference (19 Sep 2026) | Yes — `05_resultados/hil_de10_hps/campanha_solvers_20260919/` |
| Linux HIL OSQP-MPC on DE10-Standard HPS (24 Sep 2026) | Yes — plant in MATLAB, solver on Cortex-A9, **SSH not UART** |
| FIL (HDL Verifier of the EMS QP) | Not implemented |
| Real-time ADMM at \(T_s=1\) s on Cyclone IV Lite | Not claimed |
| MW facility or UPS inner-loop / EMT tests | Not this plant |
| Stochastic three-scenario MPC on FPGA/HPS | Desktop only |
| Golden V5 (\(N_p=60\)) on the board | Not ported |
| Warm-start | Not used |

SIL (`matlab_fpga`) is in-process MATLAB/`quadprog`; it does not exercise UART. UART HIL closed the heuristic on four short DE2-115 scenarios without a recorded timeout. Linux HIL closed 1200 OSQP-MPC steps on the DE10 HPS: Group A \(0\) kW, source loss \(351.169\) kW, ARM \(t_{\mathrm{us}}\) p50 \(\approx 2.4\) ms, max \(0.212\) s, 0 overruns versus \(T_s=1\) s. HIL fallback is 0 on Group A and \(11.6\%/19.9\%\) on loss/return (ARM batch with the plant on the HPS had 0 fallback).

## Layout

- `01_matlab_base/` — plant, controllers, audited QP (`revisao_operacional/`), HIL loop. The revision assembler is `revisao_operacional/`, not the historical `controle_mpc_qp_v5.m` used as a frozen reference.
- `04_artigo/ieee_access/` — manuscript and response letter (TeX).
- `04_artigo/revisao_operacional/` — `jobs.json`, campaign scripts, formulation notes.
- `05_resultados/revisao_operacional/dataset_v1/` — derived 1200 s traces and `manifest.json` hashes (seed 20260909).
- `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/` — campaign CSVs.
- `05_resultados/hil_de2115/` — SIL and UART HIL logs.
- `05_resultados/hil_de10_hps/` — OSQP/qpOASES PC campaign and DE10 artefacts.
- `EMS_FASE1_DE10_NOTEBOOK/06_resultados_banca/` — 24 Sep Linux HIL CSV/log (`02_hil_resultados.csv`, `hil_ssh_matlab.log`).
- `07_fpga/` — Qsys Tcl, Verilog top, C sources. Time-limited `.sof` bitstreams are not distributed; see `07_fpga/SOF_HASH.md` if present.

Raw DIPLOEE/NVML drops (~1 GB) are not redistributed. Rebuild derived traces with `04_artigo/revisao_operacional/preparar_dataset.py` from the official sources and check `manifest.json`. NVML metadata fields named `raw_min_W` / `raw_max_W` are mislabelled (stored after W→kW); the mapped 600–950 kW profiles used in the paper are unaffected.

## Desktop reproduction

MATLAB R2025b and Optimization Toolbox (campaign host: Intel Core i7-4510U):

```matlab
cd('01_matlab_base')
% Jobs and seeds: 04_artigo/revisao_operacional/jobs.json
% Tables in the paper follow the consolidation CSVs.
```

SIL (no FPGA):

```matlab
hil_loop_de2115('backend','matlab_fpga','controle','mpc','cenario','carga_faixas')
```

UART HIL requires a Terasic DE2-115, Quartus Prime Lite 20.1.1, `ems.elf`, serial port (lab: COM4, 115200 8N1), SW[0]=1, SW[2] for MPC versus heuristic. OpenCore Plus IP is time-limited (~1 h).

Linux HIL of OSQP-MPC requires a Terasic DE10-Standard (not Lite), Linux on the HPS, `make` in `EMS_FASE1_DE10_NOTEBOOK/01_placa_hps`, and MATLAB `run_hil_ssh.m`. Do not copy `ems_hps.exe` (Windows) onto the ARM.

## License

MIT (`LICENSE`). OSQP is Apache-2.0; qpOASES (PC reference only) is LGPL-2.1. No warranty. Not certified for field deployment or detailed UPS control.
