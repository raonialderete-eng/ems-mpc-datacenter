# Reproduction package (IEEE Access revision)

This file is the draft README for the public GitHub + Zenodo release.
The article Data Availability section points here. Do not treat SIL as a MW facility test.

## What this release will contain

- MATLAB campaign (`01_matlab_base/`, Optimization Toolbox, R2025b).
- Consolidation CSVs: `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/`.
- SIL / UART HIL logs: `05_resultados/hil_de2115/`.
- FPGA-ready C, Qsys Tcl, UART protocol: `07_fpga/` (not the time-limited `.sof` if Intel license forbids it; publish the hash).
- Derived traces + `manifest.json` hashes. Raw ~1 GB DIPLOEE/NVML is **not** uploaded; cite the official sources.

## What it will not claim

- FIL (HDL Verifier / Ethernet) was not implemented.
- UART HIL of ADMM is execution evidence, not a 1200-step KPI table (OpenCore Plus ~1 h, Nios soft-float).
- UART HIL of the **heuristic** on four short scenarios matches SIL.
- Stochastic MPC is desktop-only.

## Reproduce desktop KPIs

```matlab
cd('01_matlab_base')
% campaign runner used for the 11 Sep consolidation; see
% 04_artigo/revisao_operacional/preparacao_artigo_20260911_v1/
```

SIL (no board):

```matlab
hil_loop_de2115('backend','matlab_fpga','controle','mpc','cenario','carga_faixas')
```

UART HIL requires DE2-115, Quartus 20.1 Lite bitstream, `ems.elf`, COM port, SW[0]=1.

## Tag

`v1.0.0-ieee-access-rev` after the private GitHub repo is created (not in this working tree until the author opens the remote).
