%% COMPARA_HEURISTICO_MIOPE_MPC
% Monta tabela-resumo Heuristico x Miope x MPC (V5) a partir dos CSVs/MATs.

clc;
clear;

pasta = fullfile('c:/Users/Rauni/Documents/MPC_DATACENTER', '05_resultados');

H = readtable(fullfile(pasta, 'metricas_heuristico_todos_cenarios.csv'));
M = readtable(fullfile(pasta, 'metricas_miope_qp_todos_cenarios.csv'));
P = readtable(fullfile(pasta, 'metricas_mpc_qp_v5_todos_cenarios.csv'));

H.Controle = repmat("Heuristico", height(H), 1);
M.Controle = repmat("Miope", height(M), 1);
P.Controle = repmat("MPC", height(P), 1);

cols = intersect(intersect(H.Properties.VariableNames, M.Properties.VariableNames), ...
    P.Properties.VariableNames);
T = [H(:,cols); M(:,cols); P(:,cols)];

% Resumo chave
keep = {'Cenario','Controle'};
for c = {'Pnao_atendida_max_kW','Energia_nao_atendida_kWh','SOC_final_percent', ...
         'PBESS_max_descarga_kW','PBESS_max_carga_kW','Percentual_fallback'}
    if ismember(c{1}, T.Properties.VariableNames)
        keep{end+1} = c{1}; %#ok<AGROW>
    end
end
resumo = T(:, keep);
resumo = sortrows(resumo, {'Cenario','Controle'});

writetable(T, fullfile(pasta, 'comparacao_heuristico_miope_mpc.csv'));
writetable(resumo, fullfile(pasta, 'comparacao_resumo_heuristico_miope_mpc.csv'));
disp(resumo);
fprintf('\nTabelas salvas em %s\n', pasta);
