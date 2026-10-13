#!/bin/sh
# Wrapper MATLAB c_exe: HIL via SSH no HPS da DE10-Standard.
# Edite HOST e BIN. O MATLAB chama este script como 'exe'.
# Uso: hil_loop_de2115('backend','c_exe','exe','.../hil_ssh.sh','controle','mpc',...)

HOST="${EMS_HPS_HOST:-root@192.168.1.10}"
BIN="${EMS_HPS_BIN:-./ems_hps}"
CTRL="${1:-mpc}"
if [ "$1" = "--hil" ]; then
    shift
fi
if [ "$1" = "--ctrl" ]; then
    CTRL="$2"
fi
exec ssh -T "$HOST" "$BIN --hil --ctrl $CTRL"
