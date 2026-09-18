%% MAIN_ESTUDO_REVISTA
% Estudo completo para artigo (revista média), roda sem interação:
%   1) Foresight ON vs OFF (perda_fonte, V5)
%   2) Sensibilidade Nprep
%   3) Sensibilidade tau_b
%   4) Discussão computacional (tempos QP coletados nos itens acima)
%   5) Falha crítica (Heuristico + V5)
%
% Saídas em: 05_resultados/estudo_revista/
% Log:       05_resultados/estudo_revista/estudo_revista_log.txt

clc;
clear;
close all;

%% Paths

pasta_atual = pwd;
[pasta_pai, nome_pasta] = fileparts(pasta_atual);
if strcmp(nome_pasta, '01_matlab_base')
    pasta_projeto = pasta_pai;
else
    pasta_projeto = pasta_atual;
    addpath(fullfile(pasta_projeto, '01_matlab_base'));
    cd(fullfile(pasta_projeto, '01_matlab_base'));
end

pasta_out = fullfile(pasta_projeto, '05_resultados', 'estudo_revista');
if ~exist(pasta_out, 'dir')
    mkdir(pasta_out);
end

log_file = fullfile(pasta_out, 'estudo_revista_log.txt');
if exist(log_file, 'file')
    delete(log_file);
end
diary(log_file);

fprintf('========================================\n');
fprintf('ESTUDO REVISTA - INICIO %s\n', datestr(now));
fprintf('Saida: %s\n', pasta_out);
fprintf('========================================\n');

param0 = parametros();
resultados_estudo = struct();
t_estudo = tic;

try

%% ========================================================================
%  1) FORESIGHT ON / OFF
% ========================================================================

fprintf('\n\n##### 1) FORESIGHT ON/OFF (perda_fonte, V5) #####\n');

param = param0;
param.Tf = 1200;

param.mpc_foresight_grid = true;
param.mpc_foresight_load = true;
out_on = simular_ems('mpc_qp_v5', 'perda_fonte', param);
fprintf('FORESIGHT ON : Pnao_max=%.2f | FB=%.2f%% | t_wall=%.1fs | t_qp_med=%.4fs\n', ...
    out_on.metricas.Pnao_atendida_max, out_on.percentual_fallback, ...
    out_on.tempo_wall_s, out_on.tempo_qp_medio_s);

param.mpc_foresight_grid = false;
param.mpc_foresight_load = true;  % carga ainda previsível; falha de rede surpresa
out_off = simular_ems('mpc_qp_v5', 'perda_fonte', param);
fprintf('FORESIGHT OFF: Pnao_max=%.2f | FB=%.2f%% | t_wall=%.1fs | t_qp_med=%.4fs\n', ...
    out_off.metricas.Pnao_atendida_max, out_off.percentual_fallback, ...
    out_off.tempo_wall_s, out_off.tempo_qp_medio_s);

tab_foresight = table( ...
    ["ON"; "OFF"], ...
    [out_on.metricas.Pnao_atendida_max; out_off.metricas.Pnao_atendida_max], ...
    [out_on.metricas.Energia_nao_atendida_kWh; out_off.metricas.Energia_nao_atendida_kWh], ...
    [out_on.metricas.SOC_final; out_off.metricas.SOC_final], ...
    [out_on.percentual_fallback; out_off.percentual_fallback], ...
    [out_on.tempo_qp_medio_s; out_off.tempo_qp_medio_s], ...
    [out_on.tempo_qp_max_s; out_off.tempo_qp_max_s], ...
    [out_on.tempo_wall_s; out_off.tempo_wall_s], ...
    'VariableNames', {'Foresight','Pnao_max_kW','Energia_nao_kWh','SOC_final', ...
    'Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});

writetable(tab_foresight, fullfile(pasta_out, '01_foresight_on_off.csv'));
save(fullfile(pasta_out, '01_foresight_on_off.mat'), 'out_on', 'out_off', 'tab_foresight');
resultados_estudo.foresight = tab_foresight;

%% ========================================================================
%  2) SENSIBILIDADE Nprep
% ========================================================================

fprintf('\n\n##### 2) SENSIBILIDADE Nprep (perda_fonte, V5, foresight ON) #####\n');

lista_Nprep = [0, 10, 20, 30, 45];
nN = numel(lista_Nprep);
Pnao = zeros(nN,1); Enao = zeros(nN,1); SOCf = zeros(nN,1);
FBp = zeros(nN,1); tmed = zeros(nN,1); tmax = zeros(nN,1); twall = zeros(nN,1);
outs_Nprep = cell(nN,1);

for i = 1:nN
    param = param0;
    param.Tf = 1200;
    param.mpc_foresight_grid = true;
    param.mpc_foresight_load = true;
    param.Nprep_evento_mpc = lista_Nprep(i);

    fprintf('Nprep = %d ...\n', lista_Nprep(i));
    out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
    outs_Nprep{i} = out;

    Pnao(i) = out.metricas.Pnao_atendida_max;
    Enao(i) = out.metricas.Energia_nao_atendida_kWh;
    SOCf(i) = out.metricas.SOC_final;
    FBp(i) = out.percentual_fallback;
    tmed(i) = out.tempo_qp_medio_s;
    tmax(i) = out.tempo_qp_max_s;
    twall(i) = out.tempo_wall_s;

    fprintf('  Pnao_max=%.2f | FB=%.2f%% | t_wall=%.1fs\n', Pnao(i), FBp(i), twall(i));
end

tab_Nprep = table(lista_Nprep(:), Pnao, Enao, SOCf, FBp, tmed, tmax, twall, ...
    'VariableNames', {'Nprep','Pnao_max_kW','Energia_nao_kWh','SOC_final', ...
    'Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});

writetable(tab_Nprep, fullfile(pasta_out, '02_sensibilidade_Nprep.csv'));
save(fullfile(pasta_out, '02_sensibilidade_Nprep.mat'), 'outs_Nprep', 'tab_Nprep', 'lista_Nprep');
resultados_estudo.Nprep = tab_Nprep;

%% ========================================================================
%  3) SENSIBILIDADE tau_b
% ========================================================================

fprintf('\n\n##### 3) SENSIBILIDADE tau_b (perda_fonte, V5, foresight ON) #####\n');

lista_tau = [1, 2, 4];
nT = numel(lista_tau);
Pnao = zeros(nT,1); Enao = zeros(nT,1); SOCf = zeros(nT,1);
FBp = zeros(nT,1); tmed = zeros(nT,1); tmax = zeros(nT,1); twall = zeros(nT,1);
outs_tau = cell(nT,1);

for i = 1:nT
    param = param0;
    param.Tf = 1200;
    param.mpc_foresight_grid = true;
    param.mpc_foresight_load = true;
    param.Nprep_evento_mpc = 30;
    param.tau_b = lista_tau(i);
    param.ab = exp(-param.Ts / param.tau_b);
    param.bb = 1 - param.ab;

    fprintf('tau_b = %g s ...\n', lista_tau(i));
    out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
    outs_tau{i} = out;

    Pnao(i) = out.metricas.Pnao_atendida_max;
    Enao(i) = out.metricas.Energia_nao_atendida_kWh;
    SOCf(i) = out.metricas.SOC_final;
    FBp(i) = out.percentual_fallback;
    tmed(i) = out.tempo_qp_medio_s;
    tmax(i) = out.tempo_qp_max_s;
    twall(i) = out.tempo_wall_s;

    fprintf('  Pnao_max=%.2f | FB=%.2f%% | t_wall=%.1fs\n', Pnao(i), FBp(i), twall(i));
end

tab_tau = table(lista_tau(:), Pnao, Enao, SOCf, FBp, tmed, tmax, twall, ...
    'VariableNames', {'tau_b_s','Pnao_max_kW','Energia_nao_kWh','SOC_final', ...
    'Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});

writetable(tab_tau, fullfile(pasta_out, '03_sensibilidade_tau.csv'));
save(fullfile(pasta_out, '03_sensibilidade_tau.mat'), 'outs_tau', 'tab_tau', 'lista_tau');
resultados_estudo.tau = tab_tau;

%% ========================================================================
%  4) DISCUSSÃO COMPUTACIONAL (resumo)
% ========================================================================

fprintf('\n\n##### 4) RESUMO COMPUTACIONAL #####\n');

% Agrega tempos do foresight ON (caso base) e modo evento
qp = out_on.tempos_qp;
qp = qp(~isnan(qp));
evt = out_on.modos_evento(1:numel(out_on.tempos_qp));
evt = evt(~isnan(out_on.tempos_qp));
qp_evt = qp(evt);
qp_norm = qp(~evt);

tab_comp = table( ...
    mean(qp), max(qp), prctile(qp,95), ...
    mean(qp_norm), max(qp_norm), ...
    mean(qp_evt), max(qp_evt), ...
    out_on.tempo_wall_s, numel(qp), ...
    'VariableNames', { ...
    't_qp_med_s','t_qp_max_s','t_qp_p95_s', ...
    't_qp_med_normal_s','t_qp_max_normal_s', ...
    't_qp_med_evento_s','t_qp_max_evento_s', ...
    't_wall_perda_fonte_s','n_passos_qp'});

writetable(tab_comp, fullfile(pasta_out, '04_computacional_resumo.csv'));
save(fullfile(pasta_out, '04_computacional_resumo.mat'), 'tab_comp', 'out_on');
resultados_estudo.computacional = tab_comp;
disp(tab_comp);

%% ========================================================================
%  5) FALHA CRÍTICA (Heuristico + V5)
% ========================================================================

fprintf('\n\n##### 5) FALHA CRITICA (Heuristico + V5) #####\n');
fprintf('ATENCAO: este bloco e longo (Tf=14400 s).\n');

param = param0;
param.Tf = 14400;
param.mpc_foresight_grid = true;
param.mpc_foresight_load = true;
param.Nprep_evento_mpc = 30;

fprintf('Heuristico falha_critica ...\n');
out_fc_h = simular_ems('heuristico', 'falha_critica', param);
fprintf('  Pnao_max=%.2f | E_nao=%.2f | SOC_min=%.2f | t_wall=%.1fs\n', ...
    out_fc_h.metricas.Pnao_atendida_max, ...
    out_fc_h.metricas.Energia_nao_atendida_kWh, ...
    out_fc_h.metricas.SOC_minimo, out_fc_h.tempo_wall_s);

fprintf('V5 falha_critica ...\n');
out_fc_v5 = simular_ems('mpc_qp_v5', 'falha_critica', param);
fprintf('  Pnao_max=%.2f | E_nao=%.2f | SOC_min=%.2f | FB=%.2f%% | t_wall=%.1fs\n', ...
    out_fc_v5.metricas.Pnao_atendida_max, ...
    out_fc_v5.metricas.Energia_nao_atendida_kWh, ...
    out_fc_v5.metricas.SOC_minimo, ...
    out_fc_v5.percentual_fallback, out_fc_v5.tempo_wall_s);

tab_fc = table( ...
    ["Heuristico"; "MPC-QP-V5"], ...
    [out_fc_h.metricas.Pnao_atendida_max; out_fc_v5.metricas.Pnao_atendida_max], ...
    [out_fc_h.metricas.Energia_nao_atendida_kWh; out_fc_v5.metricas.Energia_nao_atendida_kWh], ...
    [out_fc_h.metricas.SOC_final; out_fc_v5.metricas.SOC_final], ...
    [out_fc_h.metricas.SOC_minimo; out_fc_v5.metricas.SOC_minimo], ...
    [out_fc_h.metricas.tempo_com_carga_nao_atendida_s; out_fc_v5.metricas.tempo_com_carga_nao_atendida_s], ...
    [out_fc_h.percentual_fallback; out_fc_v5.percentual_fallback], ...
    [out_fc_h.tempo_wall_s; out_fc_v5.tempo_wall_s], ...
    'VariableNames', {'Controle','Pnao_max_kW','Energia_nao_kWh','SOC_final', ...
    'SOC_min','Tempo_nao_atendida_s','Fallback_pct','t_wall_s'});

writetable(tab_fc, fullfile(pasta_out, '05_falha_critica.csv'));
save(fullfile(pasta_out, '05_falha_critica.mat'), 'out_fc_h', 'out_fc_v5', 'tab_fc');
resultados_estudo.falha_critica = tab_fc;

%% ========================================================================
%  FECHAMENTO
% ========================================================================

tempo_total_estudo_s = toc(t_estudo);
save(fullfile(pasta_out, 'estudo_revista_completo.mat'), 'resultados_estudo', 'tempo_total_estudo_s');

% Marcador de conclusão para monitoramento externo
fid = fopen(fullfile(pasta_out, 'ESTUDO_CONCLUIDO.txt'), 'w');
fprintf(fid, 'Estudo revista concluido em %s\n', datestr(now));
fprintf(fid, 'Tempo total: %.1f s (%.1f min)\n', tempo_total_estudo_s, tempo_total_estudo_s/60);
fclose(fid);

fprintf('\n========================================\n');
fprintf('ESTUDO REVISTA CONCLUIDO em %.1f min\n', tempo_total_estudo_s/60);
fprintf('Arquivos em: %s\n', pasta_out);
fprintf('========================================\n');

catch ME
    fprintf('\n**** ERRO NO ESTUDO ****\n%s\n', getReport(ME, 'extended'));
    fid = fopen(fullfile(pasta_out, 'ESTUDO_ERRO.txt'), 'w');
    fprintf(fid, '%s\n', getReport(ME, 'extended'));
    fclose(fid);
    diary off;
    rethrow(ME);
end

diary off;
