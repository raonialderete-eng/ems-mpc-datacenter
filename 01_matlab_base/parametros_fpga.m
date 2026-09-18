function param = parametros_fpga()
% PARAMETROS_FPGA
% Premissas do EMS-MPC para o SoC Nios II na DE2-115.
% Nao altera parametros.m / V5 do artigo.

param = parametros();

% Horizonte cabivel no Cyclone IV / Nios (nvar = Nc + 5*Np = 64)
param.Np_mpc = 12;
param.Nc_mpc = 4;

% Janela de preparacao nao pode exceder Np (senao o evento some do horizonte)
param.Nprep_evento_mpc = 12;

param.fpga.nvar = param.Nc_mpc + 5 * param.Np_mpc;
param.fpga.placa = 'DE2-115';
param.fpga.solver_matlab = 'quadprog';
param.fpga.solver_embarcado = 'admm_denso';
param.fpga.admm_max_iter = 40;
param.fpga.admm_rho = 1.0;
param.fpga.timeout_qp_s = 0.20;
end
