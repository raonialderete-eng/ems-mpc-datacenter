function [PBESS_ref, info_mpc] = controle_mpc_qp_fpga( ...
    k, ...
    SOC_atual, ...
    PBESS_atual, ...
    PBESS_ref_anterior, ...
    Psource_anterior, ...
    Pload, ...
    Psource_max, ...
    grid_status, ...
    param)
% CONTROLE_MPC_QP_FPGA
% Mesma formulacao da V5 (quadprog), com horizonte embarcavel.
% Nao duplica o IPM: injeta Np/Nc/Nprep de parametros_fpga e reusa V5.
%
% z = [dU(Nc) ; Pgrid(Np) ; Sload ; Ssource ; Srecharge ; Sevent]
% nvar = Nc + 5*Np  (12/4 -> 64)

if nargin < 10 || isempty(param)
    param = parametros_fpga();
else
    param = aplicar_horizonte_fpga(param);
end

[PBESS_ref, info_mpc] = controle_mpc_qp_v5( ...
    k, SOC_atual, PBESS_atual, PBESS_ref_anterior, Psource_anterior, ...
    Pload, Psource_max, grid_status, param);

info_mpc.controlador = 'mpc_qp_fpga';
info_mpc.Np = param.Np_mpc;
info_mpc.Nc = param.Nc_mpc;
end

function param = aplicar_horizonte_fpga(param)
base = parametros_fpga();
if ~isfield(param, 'Np_mpc') || isempty(param.Np_mpc)
    param.Np_mpc = base.Np_mpc;
end
if ~isfield(param, 'Nc_mpc') || isempty(param.Nc_mpc)
    param.Nc_mpc = base.Nc_mpc;
end
if ~isfield(param, 'Nprep_evento_mpc') || isempty(param.Nprep_evento_mpc)
    param.Nprep_evento_mpc = min(base.Nprep_evento_mpc, param.Np_mpc);
end
end
