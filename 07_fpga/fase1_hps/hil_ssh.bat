@echo off
REM Wrapper Windows para MATLAB c_exe via SSH no HPS.
REM Edite HOST e BIN. MATLAB: 'exe' = caminho deste .bat
set HOST=root@192.168.1.10
set BIN=./ems_hps
ssh -T %HOST% "%BIN% --hil --ctrl mpc"
