%% MAIN_REVISAO_FASE1
% Campanha enxuta da revisao IEEE Access (timing, traces, pesos, fairness).
% Checkpoint incremental em 05_resultados/revisao_fase1/
% Uso: cd 01_matlab_base; main_revisao_fase1

clc;
clear;
close all;

pasta_atual = pwd;
[pasta_pai, nome_pasta] = fileparts(pasta_atual);
if strcmp(nome_pasta, '01_matlab_base')
    pasta_projeto = pasta_pai;
else
    pasta_projeto = pasta_atual;
    addpath(fullfile(pasta_projeto, '01_matlab_base'));
    cd(fullfile(pasta_projeto, '01_matlab_base'));
end

pasta_out = fullfile(pasta_projeto, '05_resultados', 'revisao_fase1');
if ~exist(pasta_out, 'dir'), mkdir(pasta_out); end

gerar_traces_revisao();

param0 = parametros();
param0.Tf = 1200;
param0.report_hess_cond = true;

checkpoint = fullfile(pasta_out, 'checkpoint_fase1.mat');
if exist(checkpoint, 'file')
    S = load(checkpoint);
    feitos = S.feitos;
else
    feitos = {};
end

diary(fullfile(pasta_out, 'fase1_log.txt'));
fprintf('FASE1 INICIO %s\n', datestr(now));

%% 1) Timing sweep (perda_fonte, MPC, gate OFF = artigo)
shifts = -20:5:20;
linhas = {};
for sh = shifts
    tag = sprintf('timing_ungated_%+d', sh);
    if any(strcmp(feitos, tag)), continue; end
    [out, m] = run_shift(param0, sh, inf);
    linhas(end+1,:) = {sh, 'ungated', m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
        m.SOC_no_evento, m.T_pnao_gt_350_s, m.t_recovery_s, out.percentual_fallback}; %#ok<SAGROW>
    feitos{end+1} = tag; %#ok<SAGROW>
    save(checkpoint, 'feitos');
    fprintf('%s Pnao=%.2f\n', tag, m.Pnao_atendida_max);
end
if ~isempty(linhas)
    tab = cell2table(linhas, 'VariableNames', ...
        {'Shift_s','Gate','Pnao_max_kW','Energia_nao_kWh','SOC_evento','T_gt350_s','t_rec_s','FB_pct'});
    writetable(tab, fullfile(pasta_out, '02_timing_sweep.csv'));
end

%% 2) Gated vs ungated at -10/0/+10
linhas_g = {};
for sh = [-10, 0, 10]
    for Narm = [inf, 8]
        if isinf(Narm), gname = 'ungated'; else, gname = 'arm8'; end
        tag = sprintf('gate_%s_%+d', gname, sh);
        if any(strcmp(feitos, tag)), continue; end
        [out, m] = run_shift(param0, sh, Narm);
        linhas_g(end+1,:) = {sh, gname, Narm, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
            m.SOC_no_evento, m.T_pnao_gt_350_s, out.percentual_fallback}; %#ok<SAGROW>
        feitos{end+1} = tag; %#ok<SAGROW>
        save(checkpoint, 'feitos');
        fprintf('%s Pnao=%.2f\n', tag, m.Pnao_atendida_max);
    end
end
if ~isempty(linhas_g)
    tabg = cell2table(linhas_g, 'VariableNames', ...
        {'Shift_s','Gate','Narm','Pnao_max_kW','Energia_nao_kWh','SOC_evento','T_gt350_s','FB_pct'});
    writetable(tabg, fullfile(pasta_out, '02_timing_gate.csv'));
end

%% 3) Monte Carlo delay (ungated + arm8), N=20
Nmc = 12;
rng(20260907, 'twister');
delays = round(max(-20, min(20, 6*randn(Nmc,1))));
linhas_mc = {};
for im = 1:Nmc
    for Narm = [inf, 8]
        if isinf(Narm), gname = 'ungated'; else, gname = 'arm8'; end
        tag = sprintf('mc_%02d_%s', im, gname);
        if any(strcmp(feitos, tag)), continue; end
        [out, m] = run_shift(param0, delays(im), Narm);
        linhas_mc(end+1,:) = {im, delays(im), gname, m.Pnao_atendida_max, ...
            double(m.Pnao_atendida_max > 593), out.percentual_fallback}; %#ok<SAGROW>
        feitos{end+1} = tag; %#ok<SAGROW>
        save(checkpoint, 'feitos');
        fprintf('%s delay=%d Pnao=%.2f\n', tag, delays(im), m.Pnao_atendida_max);
    end
end
if ~isempty(linhas_mc)
    tabmc = cell2table(linhas_mc, 'VariableNames', ...
        {'i','Delay_s','Gate','Pnao_max_kW','WorseThanReactive','FB_pct'});
    writetable(tabmc, fullfile(pasta_out, '02_timing_montecarlo.csv'));
end

%% 4) Traces NREL + Alibaba, 4 controladores
cen_tr = {'carga_nrel','carga_alibaba'};
ctrls = {'heuristico','heuristico_foresight','miope_qp','mpc_qp_v5'};
linhas_tr = {};
for ic = 1:numel(cen_tr)
    for it = 1:numel(ctrls)
        tag = sprintf('%s__%s', cen_tr{ic}, ctrls{it});
        if any(strcmp(feitos, tag)), continue; end
        param = param0;
        param.event_arm_horizon = inf;
        t1 = tic;
        out = simular_ems(ctrls{it}, cen_tr{ic}, param);
        m = out.metricas;
        linhas_tr(end+1,:) = {cen_tr{ic}, out.nome_controle, m.Pnao_atendida_max, ...
            m.Energia_nao_atendida_kWh, m.T_pnao_gt_50_s, m.T_pnao_gt_100_s, ...
            m.SOC_final, out.percentual_fallback, out.tempo_qp_medio_s, ...
            out.tempo_qp_p50_s, out.tempo_qp_p95_s, out.tempo_qp_max_s, toc(t1)}; %#ok<SAGROW>
        feitos{end+1} = tag; %#ok<SAGROW>
        save(checkpoint, 'feitos');
        fprintf('%s Pnao=%.2f wall=%.1f\n', tag, m.Pnao_atendida_max, toc(t1));
    end
end
if ~isempty(linhas_tr)
    tabtr = cell2table(linhas_tr, 'VariableNames', ...
        {'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_gt50_s','T_gt100_s', ...
        'SOC_final','FB_pct','tqp_med','tqp_p50','tqp_p95','tqp_max','wall_s'});
    writetable(tabtr, fullfile(pasta_out, '01_traces_controladores.csv'));
end

%% 5) Fairness miópe (limite_fonte): dUmax e w_du
linhas_f = {};
dUs = [80, 120, 200, 400];
wdus = [10, 50, 200];
for dU = dUs
    tag = sprintf('miope_dU_%d', dU);
    if any(strcmp(feitos, tag)), continue; end
    param = param0;
    param.dPBESS_ref_max = dU;
    param.dPBESS_ref_max_evento = max(dU, 400);
    out = simular_ems('miope_qp', 'limite_fonte', param);
    linhas_f(end+1,:) = {'dUmax', dU, NaN, out.metricas.Pnao_atendida_max}; %#ok<SAGROW>
    feitos{end+1} = tag; %#ok<SAGROW>
    save(checkpoint, 'feitos');
end
for wdu = wdus
    tag = sprintf('miope_wdu_%g', wdu);
    if any(strcmp(feitos, tag)), continue; end
    param = param0;
    param.w_mpc_delta_u = wdu;
    out = simular_ems('miope_qp', 'limite_fonte', param);
    linhas_f(end+1,:) = {'w_du', NaN, wdu, out.metricas.Pnao_atendida_max}; %#ok<SAGROW>
    feitos{end+1} = tag; %#ok<SAGROW>
    save(checkpoint, 'feitos');
end
% heuristic reference
if ~any(strcmp(feitos, 'heur_limite_ref'))
    outh = simular_ems('heuristico', 'limite_fonte', param0);
    linhas_f(end+1,:) = {'heuristic', NaN, NaN, outh.metricas.Pnao_atendida_max}; %#ok<SAGROW>
    feitos{end+1} = 'heur_limite_ref'; %#ok<SAGROW>
    save(checkpoint, 'feitos');
end
if ~isempty(linhas_f)
    tabf = cell2table(linhas_f, 'VariableNames', {'Knob','dUmax','w_du','Pnao_max_kW'});
    writetable(tabf, fullfile(pasta_out, '04_fairness_miope.csv'));
end

%% 6) Weight / cond(H) sweep (perda_fonte + carga_faixas, MPC)
pesos = {
    'nominal', 1e9, 1e9, 1e8, 50
    'wL_1e8',  1e8, 1e9, 1e8, 50
    'wL_1e10', 1e10,1e9, 1e8, 50
    'wE_1e8',  1e9, 1e8, 1e8, 50
    'wdu_5',   1e9, 1e9, 1e8, 5
    'wdu_500', 1e9, 1e9, 1e8, 500
    };
linhas_w = {};
for ip = 1:size(pesos,1)
    for cen = {'perda_fonte','carga_faixas'}
        tag = sprintf('w_%s__%s', pesos{ip,1}, cen{1});
        if any(strcmp(feitos, tag)), continue; end
        param = param0;
        param.w_mpc_slack_load = pesos{ip,2};
        param.w_mpc_slack_event = pesos{ip,3};
        param.w_mpc_slack_source = pesos{ip,4};
        param.w_mpc_delta_u = pesos{ip,5};
        param.report_hess_cond = true;
        out = simular_ems('mpc_qp_v5', cen{1}, param);
        linhas_w(end+1,:) = {pesos{ip,1}, cen{1}, pesos{ip,2}, pesos{ip,3}, pesos{ip,5}, ...
            out.metricas.Pnao_atendida_max, out.hess_cond, out.percentual_fallback, ...
            out.tempo_qp_p50_s, out.tempo_qp_p95_s, out.tempo_qp_max_s}; %#ok<SAGROW>
        feitos{end+1} = tag; %#ok<SAGROW>
        save(checkpoint, 'feitos');
        fprintf('%s Pnao=%.2f cond=%.3g\n', tag, out.metricas.Pnao_atendida_max, out.hess_cond);
    end
end
if ~isempty(linhas_w)
    tabw = cell2table(linhas_w, 'VariableNames', ...
        {'Config','Cenario','w_L','w_E','w_du','Pnao_max_kW','hess_cond','FB_pct', ...
        'tqp_p50','tqp_p95','tqp_max'});
    writetable(tabw, fullfile(pasta_out, '04_pesos_cond.csv'));
end

%% 7) Copiar tabela SIL (nao re-roda HIL)
sil_src = fullfile(pasta_projeto, '05_resultados', 'hil_de2115', '01_matlab_v5_vs_fpga.csv');
sil_dst = fullfile(pasta_out, '05_sil_fpga_ready.csv');
if exist(sil_src, 'file')
    copyfile(sil_src, sil_dst);
end
hil_src = fullfile(pasta_projeto, '05_resultados', 'hil_de2115', '02_hil_resultados.csv');
if exist(hil_src, 'file')
    copyfile(hil_src, fullfile(pasta_out, '05_sil_protocolo.csv'));
end

%% 8) Computacional V5 (carga_faixas) — percentis
if ~any(strcmp(feitos, 'comp_faixas'))
    param = param0; param.report_hess_cond = true;
    out = simular_ems('mpc_qp_v5', 'carga_faixas', param);
    qp = out.tempos_qp(~isnan(out.tempos_qp));
    tabc = table(out.hess_cond, out.tempo_qp_medio_s, out.tempo_qp_p50_s, ...
        out.tempo_qp_p95_s, out.tempo_qp_max_s, numel(qp), ...
        'VariableNames', {'hess_cond','tqp_mean','tqp_p50','tqp_p95','tqp_max','n_qp'});
    writetable(tabc, fullfile(pasta_out, '05_computacional.csv'));
    feitos{end+1} = 'comp_faixas'; %#ok<SAGROW>
    save(checkpoint, 'feitos');
end

fid = fopen(fullfile(pasta_out, 'ESTUDO_CONCLUIDO.txt'), 'w');
fprintf(fid, 'Fase 1 concluida %s\njobs=%d\n', datestr(now), numel(feitos));
fclose(fid);
fprintf('FASE1 FIM %s | feitos=%d\n', datestr(now), numel(feitos));
diary off;

function [out, m] = run_shift(param0, sh, Narm)
param = param0;
param.event_arm_horizon = Narm;
param.mpc_foresight_grid = true;
param.mpc_foresight_load = true;
t = 0:param.Ts:param.Tf;
[Pload_true, Pmax_true, grid_true] = gera_cenario(t, 'perda_fonte', param);
grid_fcst = ones(size(grid_true));
grid_fcst(t >= (500+sh) & t < (650+sh)) = 0;
param.Pload_forecast = Pload_true;
param.grid_forecast = grid_fcst;
param.Psource_max_forecast = param.Psource_max_nominal * grid_fcst;
out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
m = out.metricas;
end
