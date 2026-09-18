%% TESTE_RAPIDO_V5_PERDA_FONTE
% Validação rápida do MPC-QP-V5 no cenário perda_fonte (sem gráficos).

clc;
clear;
close all;

cd('c:/Users/Rauni/Documents/MPC_DATACENTER/01_matlab_base');

param = parametros();
param.Tf = 1200;

t = 0:param.Ts:param.Tf;
N = length(t);

[Pload, Psource_max, grid_status, nome_cenario] = ...
    gera_cenario(t, 'perda_fonte', param);

SOC = zeros(1,N);
PBESS = zeros(1,N);
PBESS_ref = zeros(1,N);
Psource = zeros(1,N);
Pnao_atendida = zeros(1,N);

SOC(1) = param.SOC_ref;
PBESS(1) = 0;
PBESS_ref(1) = 0;

contador_qp_ok = 0;
contador_fallback = 0;
contador_modo_evento = 0;

fprintf('TESTE RAPIDO V5 - %s\n', char(nome_cenario));
fprintf('N = %d passos\n\n', N-1);

tic;
t_bloco = tic;

for k = 1:N-1

    if k == 1
        PBESS_ref_anterior = 0;
        Psource_anterior = Pload(k);
    else
        PBESS_ref_anterior = PBESS_ref(k-1);
        Psource_anterior = Psource(k-1);
    end

    [PBESS_ref(k), info_mpc_k] = controle_mpc_qp_v5( ...
        k, ...
        SOC(k), ...
        PBESS(k), ...
        PBESS_ref_anterior, ...
        Psource_anterior, ...
        Pload, ...
        Psource_max, ...
        grid_status, ...
        param);

    if info_mpc_k.usou_fallback
        contador_fallback = contador_fallback + 1;
    else
        contador_qp_ok = contador_qp_ok + 1;
    end

    if isfield(info_mpc_k, 'modo_evento') && info_mpc_k.modo_evento
        contador_modo_evento = contador_modo_evento + 1;
    end

    [SOC(k+1), PBESS(k+1), Psource(k), Pnao_atendida(k)] = planta_bess( ...
        SOC(k), ...
        PBESS(k), ...
        PBESS_ref(k), ...
        Pload(k), ...
        Psource_max(k), ...
        grid_status(k), ...
        param);

    if mod(k, 100) == 0
        fprintf('k=%4d | t=%.0fs | PBESS=%.1f | Pref=%.1f | Pnao=%.1f | SOC=%.2f | dt_bloco=%.1fs\n', ...
            k, t(k), PBESS(k), PBESS_ref(k), Pnao_atendida(k), SOC(k), toc(t_bloco));
        t_bloco = tic;
    end

end

PBESS_ref(N) = PBESS_ref(N-1);
if grid_status(N) == 1
    Psource(N) = min(Pload(N) - PBESS(N), Psource_max(N));
else
    Psource(N) = 0;
end
Psource(N) = max(Psource(N), 0);
Pnao_atendida(N) = max(0, Pload(N) - Psource(N) - PBESS(N));

tempo_total = toc;

fprintf('\nTempo total: %.1f s\n', tempo_total);
fprintf('QP OK: %d | Fallback: %d (%.2f%%) | Modo evento: %d\n', ...
    contador_qp_ok, contador_fallback, 100*contador_fallback/(N-1), contador_modo_evento);

% Janela da falha
idx_falha = find(grid_status == 0);
k0 = idx_falha(1);
k1 = idx_falha(end);

fprintf('\n--- Janela da falha (t=%.0f a %.0f s) ---\n', t(k0), t(k1));
fprintf('PBESS em t_falha-5: %.2f kW\n', PBESS(max(1,k0-5)));
fprintf('PBESS em t_falha-1: %.2f kW\n', PBESS(max(1,k0-1)));
fprintf('PBESS em t_falha  : %.2f kW\n', PBESS(k0));
fprintf('PBESS max na falha: %.2f kW\n', max(PBESS(k0:k1)));
fprintf('Pnao max global   : %.2f kW\n', max(Pnao_atendida));
fprintf('Pnao max na falha : %.2f kW\n', max(Pnao_atendida(k0:k1)));
fprintf('Alvo fisico (~350): %.2f kW\n', param.Pload_media - param.PBESS_max);
fprintf('SOC final         : %.2f %%\n', SOC(end));

metricas = calcula_metricas(t, Pload, Psource, PBESS, SOC, Psource_max, Pnao_atendida, param);

pasta_saida = fullfile('c:/Users/Rauni/Documents/MPC_DATACENTER', '05_resultados');
if ~exist(pasta_saida, 'dir'); mkdir(pasta_saida); end
save(fullfile(pasta_saida, 'teste_rapido_v5_perda_fonte.mat'), ...
    't','Pload','Psource','PBESS','PBESS_ref','SOC','Pnao_atendida','metricas', ...
    'contador_qp_ok','contador_fallback','contador_modo_evento','tempo_total');

fprintf('\nTESTE RAPIDO V5 CONCLUIDO\n');
