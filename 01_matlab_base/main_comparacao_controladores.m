%% MAIN_COMPARACAO_CONTROLADORES
% Etapa 2: compara Heuristico x MPC-QP-V4 x MPC-QP-V5 nos 4 cenários curtos.
%
% Estratégia:
% - Heuristico: simula agora (CSV antigo estava inconsistente).
% - V4: usa resultados já salvos (pesos originais da V4).
% - V5: usa resultados aprovados já salvos.
%
% Gera:
%   metricas_heuristico_todos_cenarios.csv/.mat  (atualizado)
%   comparacao_heuristico_v4_v5.csv
%   comparacao_resumo_chave.csv

clc;
clear;
close all;

%% 0. Paths

pasta_atual = pwd;
[pasta_pai, nome_pasta] = fileparts(pasta_atual);

if strcmp(nome_pasta, '01_matlab_base')
    pasta_projeto = pasta_pai;
else
    pasta_projeto = pasta_atual;
    addpath(fullfile(pasta_projeto, '01_matlab_base'));
end

pasta_saida = fullfile(pasta_projeto, '05_resultados');
if ~exist(pasta_saida, 'dir')
    mkdir(pasta_saida);
end

%% 1. Cenários

cenarios = { ...
    'carga_faixas', ...
    'limite_fonte', ...
    'perda_fonte', ...
    'retorno_fonte'};

n_cenarios = length(cenarios);
param_base = parametros();

%% 2. Simular Heuristico

fprintf('\n=====================================\n');
fprintf('ETAPA 2A - SIMULANDO HEURISTICO\n');
fprintf('=====================================\n');

tipo_controle = 'heuristico';
nomes_controle = 'Heuristico';

resultados = struct( ...
    'tipo_cenario', [], 'nome_cenario', [], 'controle', [], ...
    't', [], 'Pload', [], 'Psource_max', [], 'grid_status', [], ...
    'PBESS_ref', [], 'PBESS', [], 'Psource', [], 'SOC', [], ...
    'Pnao_atendida', [], 'metricas', [], ...
    'contador_qp_ok', [], 'contador_fallback', [], ...
    'percentual_fallback', [], 'exitflags_mpc', []);
resultados = repmat(resultados, n_cenarios, 1);

for i = 1:n_cenarios

    tipo_cenario = cenarios{i};
    param = param_base;
    param.Tf = 1200;

    fprintf('\n--- %s | %s ---\n', tipo_cenario, nomes_controle);

    t = 0:param.Ts:param.Tf;
    N = length(t);

    [Pload, Psource_max, grid_status, nome_cenario] = ...
        gera_cenario(t, tipo_cenario, param);
    nome_cenario_char = char(nome_cenario);

    SOC = zeros(1,N);
    PBESS = zeros(1,N);
    PBESS_ref = zeros(1,N);
    Psource = zeros(1,N);
    Pnao_atendida = zeros(1,N);

    SOC(1) = param.SOC_ref;
    PBESS(1) = 0;
    PBESS_ref(1) = 0;

    for k = 1:N-1
        PBESS_ref(k) = controle_heuristico( ...
            Pload(k), Psource_max(k), grid_status(k), SOC(k), param);

        [SOC(k+1), PBESS(k+1), Psource(k), Pnao_atendida(k)] = planta_bess( ...
            SOC(k), PBESS(k), PBESS_ref(k), ...
            Pload(k), Psource_max(k), grid_status(k), param);
    end

    PBESS_ref(N) = PBESS_ref(N-1);
    if grid_status(N) == 1
        Psource(N) = min(Pload(N) - PBESS(N), Psource_max(N));
    else
        Psource(N) = 0;
    end
    Psource(N) = max(Psource(N), 0);
    Pnao_atendida(N) = max(0, Pload(N) - Psource(N) - PBESS(N));

    metricas = calcula_metricas( ...
        t, Pload, Psource, PBESS, SOC, Psource_max, Pnao_atendida, param);

    resultados(i).tipo_cenario = tipo_cenario;
    resultados(i).nome_cenario = nome_cenario_char;
    resultados(i).controle = nomes_controle;
    resultados(i).t = t;
    resultados(i).Pload = Pload;
    resultados(i).Psource_max = Psource_max;
    resultados(i).grid_status = grid_status;
    resultados(i).PBESS_ref = PBESS_ref;
    resultados(i).PBESS = PBESS;
    resultados(i).Psource = Psource;
    resultados(i).SOC = SOC;
    resultados(i).Pnao_atendida = Pnao_atendida;
    resultados(i).metricas = metricas;
    resultados(i).contador_qp_ok = 0;
    resultados(i).contador_fallback = 0;
    resultados(i).percentual_fallback = 0;
    resultados(i).exitflags_mpc = zeros(1,N);

end

tabela_heuristico = montar_tabela_metricas(resultados);
writetable(tabela_heuristico, fullfile(pasta_saida, 'metricas_heuristico_todos_cenarios.csv'));
save(fullfile(pasta_saida, 'resultados_heuristico_todos_cenarios.mat'), ...
    'resultados', 'tabela_heuristico');

fprintf('\nHeuristico salvo.\n');

%% 3. Carregar V4 e V5 salvos

arquivo_v4 = fullfile(pasta_saida, 'metricas_mpc_qp_v4_todos_cenarios.csv');
arquivo_v5 = fullfile(pasta_saida, 'metricas_mpc_qp_v5_todos_cenarios.csv');

if ~exist(arquivo_v4, 'file')
    error('Arquivo V4 nao encontrado: %s', arquivo_v4);
end
if ~exist(arquivo_v5, 'file')
    error('Arquivo V5 nao encontrado: %s', arquivo_v5);
end

tabela_v4 = readtable(arquivo_v4);
tabela_v5 = readtable(arquivo_v5);
tabela_h  = tabela_heuristico;

% Padronizar nomes de controle
tabela_h.Controle  = repmat("Heuristico", height(tabela_h), 1);
tabela_v4.Controle = repmat("MPC-QP-V4", height(tabela_v4), 1);
tabela_v5.Controle = repmat("MPC-QP-V5", height(tabela_v5), 1);

%% 4. Unificar colunas e concatenar

cols_comuns = intersect(intersect(tabela_h.Properties.VariableNames, ...
    tabela_v4.Properties.VariableNames), tabela_v5.Properties.VariableNames);

tabela_comparacao = [ ...
    tabela_h(:, cols_comuns); ...
    tabela_v4(:, cols_comuns); ...
    tabela_v5(:, cols_comuns)];

% Ordenar por cenário e controle
if ismember('Cenario', tabela_comparacao.Properties.VariableNames)
    tabela_comparacao = sortrows(tabela_comparacao, {'Cenario', 'Controle'});
end

arquivo_comp = fullfile(pasta_saida, 'comparacao_heuristico_v4_v5.csv');
writetable(tabela_comparacao, arquivo_comp);

%% 5. Tabela-resumo com métricas-chave

cols_chave = {'Cenario','Controle'};
candidatos = { ...
    'Pnao_atendida_max_kW', ...
    'Energia_nao_atendida_kWh', ...
    'SOC_final_percent', ...
    'SOC_minimo_percent', ...
    'PBESS_max_descarga_kW', ...
    'PBESS_max_carga_kW', ...
    'Energia_BESS_descarga_kWh', ...
    'Energia_BESS_carga_kWh', ...
    'Rampa_fonte_max_kW_s', ...
    'Percentual_fallback'};

for c = 1:numel(candidatos)
    if ismember(candidatos{c}, tabela_comparacao.Properties.VariableNames)
        cols_chave{end+1} = candidatos{c}; %#ok<AGROW>
    end
end

tabela_resumo = tabela_comparacao(:, cols_chave);
arquivo_resumo = fullfile(pasta_saida, 'comparacao_resumo_chave.csv');
writetable(tabela_resumo, arquivo_resumo);

%% 6. Impressão focada

fprintf('\n\n=====================================\n');
fprintf('COMPARACAO HEURISTICO x V4 x V5\n');
fprintf('=====================================\n\n');
disp(tabela_resumo);

fprintf('\n--- Destaques por cenario (Pnao max) ---\n');
cenarios_unicos = unique(tabela_resumo.Cenario, 'stable');
for i = 1:numel(cenarios_unicos)
    sub = tabela_resumo(tabela_resumo.Cenario == cenarios_unicos(i), :);
    fprintf('\n%s\n', cenarios_unicos(i));
    for r = 1:height(sub)
        fprintf('  %-12s  Pnao_max=%8.2f kW | E_nao=%7.3f kWh | SOC_f=%6.2f %%', ...
            string(sub.Controle(r)), ...
            sub.Pnao_atendida_max_kW(r), ...
            sub.Energia_nao_atendida_kWh(r), ...
            sub.SOC_final_percent(r));
        if ismember('Percentual_fallback', sub.Properties.VariableNames)
            fprintf(' | FB=%5.2f %%', sub.Percentual_fallback(r));
        end
        fprintf('\n');
    end
end

fprintf('\nArquivos gerados:\n');
fprintf('  %s\n', arquivo_comp);
fprintf('  %s\n', arquivo_resumo);
fprintf('  %s\n', fullfile(pasta_saida, 'metricas_heuristico_todos_cenarios.csv'));

fprintf('\n=====================================\n');
fprintf('COMPARACAO CONCLUIDA\n');
fprintf('=====================================\n');

%% -------- função local --------
function tabela = montar_tabela_metricas(resultados)

n = numel(resultados);

Cenario = strings(n,1);
Controle = strings(n,1);
Pload_media_kW = zeros(n,1);
Pload_max_kW = zeros(n,1);
Psource_max_observada_kW = zeros(n,1);
Psource_media_kW = zeros(n,1);
Rampa_fonte_max_kW_s = zeros(n,1);
Tempo_violacao_fonte_s = zeros(n,1);
PBESS_max_descarga_kW = zeros(n,1);
PBESS_max_carga_kW = zeros(n,1);
Energia_BESS_descarga_kWh = zeros(n,1);
Energia_BESS_carga_kWh = zeros(n,1);
SOC_inicial_percent = zeros(n,1);
SOC_final_percent = zeros(n,1);
SOC_minimo_percent = zeros(n,1);
SOC_maximo_percent = zeros(n,1);
Pnao_atendida_max_kW = zeros(n,1);
Energia_nao_atendida_kWh = zeros(n,1);
Tempo_carga_nao_atendida_s = zeros(n,1);
Percentual_tempo_carga_nao_atendida = zeros(n,1);
QP_OK = zeros(n,1);
Fallback_heuristico = zeros(n,1);
Percentual_fallback = zeros(n,1);

for i = 1:n
    m = resultados(i).metricas;
    Cenario(i) = string(resultados(i).nome_cenario);
    Controle(i) = string(resultados(i).controle);
    Pload_media_kW(i) = m.Pload_media;
    Pload_max_kW(i) = m.Pload_max;
    Psource_max_observada_kW(i) = m.Psource_max_observada;
    Psource_media_kW(i) = m.Psource_media;
    Rampa_fonte_max_kW_s(i) = m.rampa_fonte_max;
    Tempo_violacao_fonte_s(i) = m.tempo_violacao_fonte_s;
    PBESS_max_descarga_kW(i) = m.PBESS_max_descarga;
    PBESS_max_carga_kW(i) = m.PBESS_max_carga;
    Energia_BESS_descarga_kWh(i) = m.Energia_BESS_descarga_kWh;
    Energia_BESS_carga_kWh(i) = m.Energia_BESS_carga_kWh;
    SOC_inicial_percent(i) = m.SOC_inicial;
    SOC_final_percent(i) = m.SOC_final;
    SOC_minimo_percent(i) = m.SOC_minimo;
    SOC_maximo_percent(i) = m.SOC_maximo;
    Pnao_atendida_max_kW(i) = m.Pnao_atendida_max;
    Energia_nao_atendida_kWh(i) = m.Energia_nao_atendida_kWh;
    Tempo_carga_nao_atendida_s(i) = m.tempo_com_carga_nao_atendida_s;
    Percentual_tempo_carga_nao_atendida(i) = m.percentual_tempo_carga_nao_atendida;
    QP_OK(i) = resultados(i).contador_qp_ok;
    Fallback_heuristico(i) = resultados(i).contador_fallback;
    Percentual_fallback(i) = resultados(i).percentual_fallback;
end

tabela = table( ...
    Cenario, Controle, ...
    Pload_media_kW, Pload_max_kW, ...
    Psource_max_observada_kW, Psource_media_kW, ...
    Rampa_fonte_max_kW_s, Tempo_violacao_fonte_s, ...
    PBESS_max_descarga_kW, PBESS_max_carga_kW, ...
    Energia_BESS_descarga_kWh, Energia_BESS_carga_kWh, ...
    SOC_inicial_percent, SOC_final_percent, ...
    SOC_minimo_percent, SOC_maximo_percent, ...
    Pnao_atendida_max_kW, Energia_nao_atendida_kWh, ...
    Tempo_carga_nao_atendida_s, Percentual_tempo_carga_nao_atendida, ...
    QP_OK, Fallback_heuristico, Percentual_fallback);

end
