%% Diagnostico: MPC curto com progresso (detecta crash)
param = parametros();
param.Tf = 300;
param.mpc_foresight_grid = true;
param.mpc_foresight_load = true;
fprintf('diag start Tf=%d mem=%.1fMB\n', param.Tf, memory_used_mb());
t = 0:param.Ts:param.Tf;
N = numel(t);
[Pload, Pmax, grid] = gera_cenario(t, 'carga_faixas', param);
SOC = zeros(1,N); PBESS = zeros(1,N); Pref = zeros(1,N);
SOC(1) = param.SOC_ref;
for k = 1:N-1
    if k == 1
        pref_ant = 0; psrc_ant = Pload(k);
    else
        pref_ant = Pref(k-1); psrc_ant = Pload(k-1); % approx
    end
    [Pref(k), info] = controle_mpc_qp_v5(k, SOC(k), PBESS(k), pref_ant, psrc_ant, Pload, Pmax, grid, param);
    [SOC(k+1), PBESS(k+1)] = planta_bess(SOC(k), PBESS(k), Pref(k), Pload(k), Pmax(k), grid(k), param);
    if mod(k, 25) == 0 || k == 1
        fprintf('k=%d/%d exit=%d tqp=%.3f fb=%d mem=%.1fMB\n', k, N-1, info.exitflag, info.tempo_qp_s, info.usou_fallback, memory_used_mb());
        drawnow;
    end
end
fprintf('diag OK final SOC=%.2f mem=%.1fMB\n', SOC(end), memory_used_mb());

function mb = memory_used_mb()
try
    m = memory;
    mb = m.MemUsedMATLAB / 1e6;
catch
    mb = NaN;
end
end
