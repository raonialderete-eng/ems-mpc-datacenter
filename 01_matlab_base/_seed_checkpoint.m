%% SEED CHECKPOINT - casos rapidos ja concluidos antes do crash do monitor
pasta_out = fullfile('c:\Users\Rauni\Documents\MPC_DATACENTER', '05_resultados', 'revisao_ieee_applied');
if ~exist(pasta_out, 'dir'), mkdir(pasta_out); end

param0 = parametros();
linhas = {};
resultados = struct();
feitos = containers.Map('KeyType', 'char', 'ValueType', 'logical');

pares = {
    'carga_faixas', 'heuristico'
    'carga_faixas', 'heuristico_foresight'
    'carga_faixas', 'miope_qp'
    };

for i = 1:size(pares, 1)
    tipo_c = pares{i, 1};
    tipo_t = pares{i, 2};
    param = param0;
    param.Tf = 1200;
    param.mpc_foresight_grid = true;
    param.mpc_foresight_load = true;
    fprintf('SEED %s | %s\n', tipo_c, tipo_t);
    out = simular_ems(tipo_t, tipo_c, param);
    keyv = matlab.lang.makeValidName(sprintf('%s__%s', tipo_c, tipo_t));
    resultados.(keyv) = out;
    m = out.metricas;
    linhas(end+1, :) = {tipo_c, out.nome_controle, ...
        m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
        m.tempo_com_carga_nao_atendida_s, m.SOC_final, m.SOC_minimo, ...
        m.SOC_no_evento, m.Energia_throughput_kWh, m.N_EFC, ...
        m.rampa_fonte_max, out.percentual_fallback, ...
        out.tempo_qp_medio_s, out.tempo_qp_max_s, out.tempo_wall_s}; %#ok<SAGROW>
    feitos(keyv) = true;
end

feitos_keys = feitos.keys;
save(fullfile(pasta_out, '01_checkpoint.mat'), 'linhas', 'resultados', 'feitos_keys', '-v7.3');
tab_tmp = cell2table(linhas, 'VariableNames', { ...
    'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_nao_s', ...
    'SOC_final','SOC_min','SOC_evento','Throughput_kWh','EFC', ...
    'Rampa_fonte_max','Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});
writetable(tab_tmp, fullfile(pasta_out, '01_comparacao_controladores.csv'));
fprintf('SEED OK n=%d\n', feitos.Count);
