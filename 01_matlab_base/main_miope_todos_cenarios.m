%% MAIN_MIOPE_TODOS_CENARIOS
% Simula o controlador míope-QP nos 4 cenários curtos e salva resultados.

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

pasta_saida = fullfile(pasta_projeto, '05_resultados');
if ~exist(pasta_saida, 'dir'); mkdir(pasta_saida); end

cenarios = {'carga_faixas','limite_fonte','perda_fonte','retorno_fonte'};
param_base = parametros();

n = numel(cenarios);
resultados = repmat(struct( ...
    'tipo_cenario',[], 'nome_cenario',[], 'controle',[], ...
    't',[], 'Pload',[], 'Psource_max',[], 'grid_status',[], ...
    'PBESS_ref',[], 'PBESS',[], 'Psource',[], 'SOC',[], ...
    'Pnao_atendida',[], 'metricas',[], ...
    'contador_qp_ok',[], 'contador_fallback',[], ...
    'percentual_fallback',[], 'exitflags_mpc',[]), n, 1);

for i = 1:n
    param = param_base;
    param.Tf = 1200;
    fprintf('\n=== MIOPE | %s ===\n', cenarios{i});
    out = simular_ems('miope_qp', cenarios{i}, param);

    resultados(i).tipo_cenario = out.tipo_cenario;
    resultados(i).nome_cenario = out.nome_cenario;
    resultados(i).controle = 'Miope-QP';
    resultados(i).t = out.t;
    resultados(i).Pload = out.Pload;
    resultados(i).Psource_max = out.Psource_max;
    resultados(i).grid_status = out.grid_status;
    resultados(i).PBESS_ref = out.PBESS_ref;
    resultados(i).PBESS = out.PBESS;
    resultados(i).Psource = out.Psource;
    resultados(i).SOC = out.SOC;
    resultados(i).Pnao_atendida = out.Pnao_atendida;
    resultados(i).metricas = out.metricas;
    resultados(i).contador_qp_ok = out.contador_qp_ok;
    resultados(i).contador_fallback = out.contador_fallback;
    resultados(i).percentual_fallback = out.percentual_fallback;
    resultados(i).exitflags_mpc = out.exitflags;

    fprintf('Pnao_max=%.2f | FB=%.2f%% | t_wall=%.1fs\n', ...
        out.metricas.Pnao_atendida_max, out.percentual_fallback, out.tempo_wall_s);
end

% Tabela
Cenario = strings(n,1); Controle = strings(n,1);
Pnao_atendida_max_kW = zeros(n,1); Energia_nao_atendida_kWh = zeros(n,1);
SOC_final_percent = zeros(n,1); SOC_minimo_percent = zeros(n,1);
PBESS_max_descarga_kW = zeros(n,1); PBESS_max_carga_kW = zeros(n,1);
Energia_BESS_descarga_kWh = zeros(n,1); Energia_BESS_carga_kWh = zeros(n,1);
Percentual_fallback = zeros(n,1);

for i = 1:n
    m = resultados(i).metricas;
    Cenario(i) = string(resultados(i).nome_cenario);
    Controle(i) = "Miope-QP";
    Pnao_atendida_max_kW(i) = m.Pnao_atendida_max;
    Energia_nao_atendida_kWh(i) = m.Energia_nao_atendida_kWh;
    SOC_final_percent(i) = m.SOC_final;
    SOC_minimo_percent(i) = m.SOC_minimo;
    PBESS_max_descarga_kW(i) = m.PBESS_max_descarga;
    PBESS_max_carga_kW(i) = m.PBESS_max_carga;
    Energia_BESS_descarga_kWh(i) = m.Energia_BESS_descarga_kWh;
    Energia_BESS_carga_kWh(i) = m.Energia_BESS_carga_kWh;
    Percentual_fallback(i) = resultados(i).percentual_fallback;
end

tabela_metricas = table(Cenario, Controle, Pnao_atendida_max_kW, ...
    Energia_nao_atendida_kWh, SOC_final_percent, SOC_minimo_percent, ...
    PBESS_max_descarga_kW, PBESS_max_carga_kW, ...
    Energia_BESS_descarga_kWh, Energia_BESS_carga_kWh, Percentual_fallback);

disp(tabela_metricas);

writetable(tabela_metricas, fullfile(pasta_saida, 'metricas_miope_qp_todos_cenarios.csv'));
save(fullfile(pasta_saida, 'resultados_miope_qp_todos_cenarios.mat'), ...
    'resultados', 'tabela_metricas');

fprintf('\nMIOPE CONCLUIDO\n');
