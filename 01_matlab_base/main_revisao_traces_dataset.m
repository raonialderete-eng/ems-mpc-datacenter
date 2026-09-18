%% MAIN_REVISAO_TRACES_DATASET
% Regenera traces a partir de dataset/ (NLR/Vercellino) e roda so o bloco 4
% (4 controladores x 2 cenarios). Nao refaz timing/pesos.
% CSV: 05_resultados/revisao_fase1/01_traces_controladores_dataset.csv

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

csv_recon = fullfile(pasta_out, '01_traces_controladores_reconstrucao.csv');
csv_atual = fullfile(pasta_out, '01_traces_controladores.csv');
if exist(csv_atual, 'file') && ~exist(csv_recon, 'file')
    copyfile(csv_atual, csv_recon);
end

gerar_traces_revisao();

param0 = parametros();
param0.Tf = 1200;
param0.event_arm_horizon = inf;

cen_tr = {'carga_nrel','carga_alibaba'};
ctrls = {'heuristico','heuristico_foresight','miope_qp','mpc_qp_v5'};
linhas_tr = {};
diary(fullfile(pasta_out, 'traces_dataset_log.txt'));
fprintf('TRACES DATASET INICIO %s\n', datestr(now));

for ic = 1:numel(cen_tr)
    for it = 1:numel(ctrls)
        fprintf('\n=== %s | %s ===\n', cen_tr{ic}, ctrls{it});
        t1 = tic;
        out = simular_ems(ctrls{it}, cen_tr{ic}, param0);
        m = out.metricas;
        linhas_tr(end+1,:) = {cen_tr{ic}, out.nome_controle, m.Pnao_atendida_max, ...
            m.Energia_nao_atendida_kWh, m.T_pnao_gt_50_s, m.T_pnao_gt_100_s, ...
            m.SOC_final, out.percentual_fallback, out.tempo_qp_medio_s, ...
            out.tempo_qp_p50_s, out.tempo_qp_p95_s, out.tempo_qp_max_s, toc(t1)}; %#ok<SAGROW>
        fprintf('Pnao=%.2f wall=%.1fs\n', m.Pnao_atendida_max, toc(t1));
    end
end

tabtr = cell2table(linhas_tr, 'VariableNames', ...
    {'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_gt50_s','T_gt100_s', ...
    'SOC_final','FB_pct','tqp_med','tqp_p50','tqp_p95','tqp_max','wall_s'});
writetable(tabtr, fullfile(pasta_out, '01_traces_controladores_dataset.csv'));
% Substitui a tabela do bloco 4 da campanha anterior (era reconstrucao).
writetable(tabtr, fullfile(pasta_out, '01_traces_controladores.csv'));
fprintf('TRACES DATASET FIM %s\n', datestr(now));
diary off;
