@echo off
setlocal
set PATH=D:\intel\nios2eds\sdk2\bin;D:\intel\nios2eds\bin;D:\intel\nios2eds\bin\gnu\H-x86_64-mingw32\bin;D:\intel\quartus\bin64;%PATH%
set QUARTUS_ROOTDIR=D:\intel\quartus
set SOPC_KIT_NIOS2=D:\intel\nios2eds
cd /d C:\Users\Rauni\Documents\MPC_DATACENTER\07_fpga\nios_app\ems_wsl\app
if not exist ems_main.c (
  echo SEVERE: ems_main.c missing
  exit /b 1
)
nios2-app-generate-makefile.exe --bsp-dir C:/Users/Rauni/Documents/MPC_DATACENTER/07_fpga/nios_app/hello_wsl/bsp --elf-name ems.elf --app-dir C:/Users/Rauni/Documents/MPC_DATACENTER/07_fpga/nios_app/ems_wsl/app --set APP_CFLAGS_OPTIMIZATION -O2 --set APP_CFLAGS_DEBUG_LEVEL -g0 --set APP_LDFLAGS_USER -msmallc --src-files ems_main.c ems_param.c planta_bess.c controle_heuristico.c gera_cenario.c ems_protocol.c qp_admm.c controle_mpc_fpga.c ems_work.c
exit /b %ERRORLEVEL%
