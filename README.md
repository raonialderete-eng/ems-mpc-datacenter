# Reproduction package — IEEE Access revision
# EMS-MPC for an aggregated AI/HPC data-center load with BESS
# Tag: v1.0.0-ieee-access-rev

This repository accompanies the IEEE Access resubmission
(`https://github.com/raonialderete-eng/ems-mpc-datacenter`).
It is **private until acceptance**. Cite the printed article (and the Zenodo DOI
once minted from the GitHub Release).

## Honest scope (read before citing hardware)

| Claim | Status in this tag |
|---|---|
| Desktop SIL campaign (MATLAB R2025b + Optimization Toolbox) | Yes — 11 Sep 2026 consolidation |
| FPGA-ready C copy, ADMM, UART protocol | Yes — sources in `07_fpga/` |
| SIL (`backend=matlab_fpga`, \(N_p=12\), \(N_c=4\)) | Yes — `05_resultados/hil_de2115/` |
| UART HIL of the **heuristic** on four short scenarios | Yes — matches SIL digits |
| UART HIL of ADMM / serial MPC, 1200 steps | **No.** Tens of RSP frames until OpenCore Plus (~1 h) expired; each QP ≫ \(T_s\) on Nios soft-float |
| FIL (HDL Verifier / Ethernet) | **Not implemented** (DUT is C on Nios, not generated HDL) |
| \(T_s=1\) s real-time ADMM on Cyclone IV Lite | **Not claimed** |
| MW facility / UPS inner loops / EMT | **Not this plant** (aggregated first-order BESS + critical load) |
| Stochastic 3-scenario MPC on FPGA | Desktop only |
| Warm-start | Not used (`X0` empty) |

SIL is **not** a MW installation test. UART HIL validates the **embedded controller** on the same aggregated model, not a UPS.

## Layout

- `01_matlab_base/` — plant, controllers, audited QP (`revisao_operacional/`), UART HIL loop. Do **not** treat historical `controle_mpc_qp_v5.m` as the revision assembler; the audited maps are in `revisao_operacional/`.
- `04_artigo/revisao_operacional/` — `jobs.json`, `criar_jobs.py`, formulation notes, dataset script.
- `04_artigo/ieee_access/` — manuscript TeX (revision).
- `05_resultados/revisao_operacional/dataset_v1/` — derived 1200 s traces + `manifest.json` hashes (seed 20260909).
- `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/` — campaign CSVs.
- `05_resultados/hil_de2115/` — SIL and UART HIL logs.
- `07_fpga/` — Qsys Tcl, Verilog top, C golden / Nios app sources. Quartus `output_files` and time-limited `.sof` are **not** in git; see `07_fpga/SOF_HASH.md` if present.

Raw ~1 GB DIPLOEE/NVML drops are **not** redistributed. Rebuild derived traces with `04_artigo/revisao_operacional/preparar_dataset.py` from the official sources, then check `manifest.json`. NVML metadata fields named `raw_min_W` / `raw_max_W` are a **unit-label errata** (values are stored after W→kW); the 600–950 kW mapped profiles used in the paper are unaffected.

## Reproduce desktop KPIs

Requires MATLAB R2025b and Optimization Toolbox on Windows (campaign host: Intel Core i7-4510U).

```matlab
cd('01_matlab_base')
% Jobs and seeds: 04_artigo/revisao_operacional/jobs.json
% Consolidation CSVs are the numerical source of the tables.
```

SIL (no board):

```matlab
hil_loop_de2115('backend','matlab_fpga','controle','mpc','cenario','carga_faixas')
```

UART HIL requires a Terasic DE2-115, Quartus Prime Lite 20.1.1 bitstream, `ems.elf`, COM port (lab: COM4, 115200 8N1), SW[0]=1 for HIL, SW[2] for MPC vs heuristic. OpenCore Plus IP is time-limited (~1 h).

## What is not in this git tree

- `.venv_revisao` and other local Python venvs
- Quartus `output_files`, `db`, `incremental_db`
- Per-job `.mat` of the 1 755-run campaign (CSVs suffice; MATs optional on Zenodo later)
- Intel time-limited `.sof` bitstream (license); publish SHA-256 instead
- Credentials, Overleaf build junk, unrelated personal folders

## Zenodo DOI (author step; not done from this machine)

1. Sign in at https://zenodo.org with the **same** GitHub account that owns this private repo.
2. GitHub → Settings → Applications → Zenodo authorized; on Zenodo: GitHub → enable this repository.
3. On GitHub create Release from tag `v1.0.0-ieee-access-rev` if not already created.
4. Zenodo → the repo → **Publish**. Copy the DOI (`10.5281/zenodo.XXXXXXXX`).
5. Paste the DOI into `04_artigo/ieee_access/artigo_ems_mpc_datacenter_access.tex` (Data Availability) and into the response letter item R2.17.

A GitHub URL is versioned code. A Zenodo DOI is the archival cite. Both are required for the letter; only GitHub is created in the engineering session.

## License

MIT (see `LICENSE`). No warranty. Not certified for real-time field control.
