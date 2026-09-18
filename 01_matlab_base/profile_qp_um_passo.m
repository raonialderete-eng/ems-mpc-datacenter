%% PROFILE_QP_UM_PASSO
% Mede tempo de uma chamada do MPC e imprime dimensões do QP.

clc; clear;
param = parametros();
param.Tf = 1200;
t = 0:param.Ts:param.Tf;
[Pload, Pmax, grid] = gera_cenario(t, 'carga_faixas', param);

k = 400;
SOC = 60; PBESS = 0; uref = 0; Ps = 750;
fprintf('Np=%d Nc=%d\n', param.Np_mpc, param.Nc_mpc);
tic;
[u, info] = controle_mpc_qp_v5(k, SOC, PBESS, uref, Ps, Pload, Pmax, grid, param);
tw = toc;
fprintf('1 passo: wall=%.3fs t_qp=%.3fs exit=%d fallback=%d u=%.1f\n', ...
    tw, info.tempo_qp_s, info.exitflag, info.usou_fallback, u);

% Estima nvar
Np = min(param.Np_mpc, numel(Pload)-k+1);
Nc = min(param.Nc_mpc, Np);
nvar = Nc + 7*Np;
fprintf('nvar estimado=%d (Nc+5*Np)\n', Nc + 5*Np);

% 20 passos em sequência
t_tot = tic;
for kk = 400:419
    [u, info] = controle_mpc_qp_v5(kk, SOC, PBESS, u, Ps, Pload, Pmax, grid, param);
    [SOC, PBESS, Ps, ~] = planta_bess(SOC, PBESS, u, Pload(kk), Pmax(kk), grid(kk), param);
end
fprintf('20 passos: wall=%.2fs media=%.3fs/passo\n', toc(t_tot), toc(t_tot)/20);
