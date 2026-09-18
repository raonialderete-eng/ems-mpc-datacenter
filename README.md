# EMS-MPC for an aggregated AI/HPC data-center load with BESS

Reproduction package for the IEEE Access manuscript on predictive energy management of an aggregated critical load with battery energy storage.

- **Code:** https://github.com/raonialderete-eng/ems-mpc-datacenter
- **Archive (DOI):** https://doi.org/10.5281/zenodo.22835283

Please cite the published article (title and DOI as printed) together with the Zenodo record.

## Scope of the evidence

| Item | In this repository |
|---|---|
| Desktop campaign (MATLAB R2025b, Optimization Toolbox) | Yes — consolidation of 11 Sep 2026 |
| FPGA-ready C, ADMM, UART protocol | Yes — `07_fpga/` |
| SIL (`backend=matlab_fpga`, \(N_p=12\), \(N_c=4\)) | Yes — `05_resultados/hil_de2115/` |
| UART HIL of the **heuristic** (four short scenarios) | Yes — matches SIL |
| UART HIL of ADMM / 1200-step serial MPC | No (OpenCore Plus ~1 h; QP ≫ \(T_s\) on Nios) |
| FIL (HDL Verifier) | Not implemented |
| Real-time ADMM at \(T_s=1\) s on Cyclone IV Lite | Not claimed |
| MW facility or UPS inner-loop / EMT tests | Not this plant |
| Stochastic three-scenario MPC on FPGA | Desktop only |
| Warm-start | Not used |

SIL is not a facility test. UART HIL validates the embedded controller on the same aggregated model used in simulation.

## Layout

- `01_matlab_base/` — plant, controllers, audited QP (`revisao_operacional/`), UART loop. The revision assembler is `revisao_operacional/`, not the historical `controle_mpc_qp_v5.m` used as a frozen reference.
- `04_artigo/ieee_access/` — manuscript and response letter (TeX).
- `04_artigo/revisao_operacional/` — `jobs.json`, campaign scripts, formulation notes.
- `05_resultados/revisao_operacional/dataset_v1/` — derived 1200 s traces and `manifest.json` hashes (seed 20260909).
- `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/` — campaign CSVs.
- `05_resultados/hil_de2115/` — SIL and UART HIL logs.
- `07_fpga/` — Qsys Tcl, Verilog top, C sources. Time-limited `.sof` bitstreams are not distributed; see `07_fpga/SOF_HASH.md`.

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

## License

MIT (`LICENSE`). No warranty. Not certified for field deployment or detailed UPS control.
