function clear_mpc_qp_v5_cache()
% CLEAR_MPC_QP_V5_CACHE
% Limpa persistents (qp_options, z_warm) de controle_mpc_qp_v5.
% Chamar no início de cada cenário para não herdar warm-start entre runs.
clear controle_mpc_qp_v5
end
