#!/bin/bash
# Firmware EMS no mesmo BSP do hello (sem timer HAL / sem JTAG stdio).
set -eu
export QUARTUS_ROOTDIR=/mnt/d/intel/quartus
export SOPC_KIT_NIOS2=/mnt/d/intel/nios2eds
export PATH="$SOPC_KIT_NIOS2/bin/gnu/H-x86_64-mingw32/bin:$SOPC_KIT_NIOS2/bin:$SOPC_KIT_NIOS2/sdk2/bin:$QUARTUS_ROOTDIR/bin64:/usr/bin:/bin"

ROOT=/mnt/c/Users/Rauni/Documents/MPC_DATACENTER/07_fpga
APP=$ROOT/nios_app/ems_wsl/app
GOLD=$ROOT/c_golden
WRAP=$ROOT/nios_app/hello_wsl/winbin

mkdir -p "$APP"
cp -f "$ROOT/nios_app/ems/ems_main.c" "$APP/ems_main.c"
cp -f "$GOLD/ems_param.c" "$GOLD/planta_bess.c" "$GOLD/controle_heuristico.c" \
      "$GOLD/gera_cenario.c" "$GOLD/ems_protocol.c" "$GOLD/qp_admm.c" \
      "$GOLD/controle_mpc_fpga.c" "$GOLD/ems_work.c" "$APP/"
cp -f "$GOLD/"*.h "$APP/"

echo "== app makefile =="
/mnt/c/Windows/System32/cmd.exe /c 'C:\Users\Rauni\Documents\MPC_DATACENTER\07_fpga\nios_app\ems_wsl\winbin\gen_app_makefile.bat'

dos2unix "$WRAP/path_conv.sh" "$WRAP/gcc_wrap.sh" "$WRAP/ar_wrap.sh" "$WRAP/gxx_wrap.sh" >/dev/null 2>&1 || true
chmod +x "$WRAP/gcc_wrap.sh" "$WRAP/ar_wrap.sh" "$WRAP/gxx_wrap.sh"
MAKE_CC="$WRAP/gcc_wrap.sh -xc"
MAKE_CXX="$WRAP/gcc_wrap.sh -xc++"
MAKE_AS="$WRAP/gcc_wrap.sh"
MAKE_AR="$WRAP/ar_wrap.sh"
MAKE_LD="$WRAP/gxx_wrap.sh"

echo "== make EMS =="
make -C "$APP" CC="$MAKE_CC" CXX="$MAKE_CXX" AS="$MAKE_AS" AR="$MAKE_AR" LD="$MAKE_LD"
ls -l "$APP/ems.elf"
