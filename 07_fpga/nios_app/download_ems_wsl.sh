#!/bin/bash
# Grava ems.elf no Nios. Programmer fechado; .sof ja na FPGA.
set -eu
export QUARTUS_ROOTDIR=/mnt/d/intel/quartus
export SOPC_KIT_NIOS2=/mnt/d/intel/nios2eds
export PATH="$SOPC_KIT_NIOS2/bin/gnu/H-x86_64-mingw32/bin:$SOPC_KIT_NIOS2/bin:$SOPC_KIT_NIOS2/sdk2/bin:$QUARTUS_ROOTDIR/bin64:/usr/bin:/bin"

ELF=/mnt/c/Users/Rauni/Documents/MPC_DATACENTER/07_fpga/nios_app/ems_wsl/app/ems.elf
if [[ ! -f "$ELF" ]]; then
  echo "ELF missing: $ELF"
  exit 1
fi

exec nios2-download --go "$ELF"
