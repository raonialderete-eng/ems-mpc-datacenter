function metricas = calcula_metricas(t, Pload, Psource, PBESS, SOC, Psource_max, Pnao_atendida, param)
% CALCULA_METRICAS
% Calcula indicadores técnicos da simulação do sistema:
% data center + fonte principal + BESS/UPS.
%
% Entradas:
% t               -> vetor de tempo [s]
% Pload           -> potência da carga [kW]
% Psource         -> potência fornecida pela fonte [kW]
% PBESS           -> potência real do BESS [kW]
% SOC             -> estado de carga da bateria [%]
% Psource_max     -> limite disponível da fonte [kW]
% Pnao_atendida   -> potência não atendida [kW]
% param           -> estrutura de parâmetros
%
% Saída:
% metricas        -> estrutura com indicadores da simulação

%% Passo de tempo

Ts = param.Ts;   % [s]

%% Métricas da carga

metricas.Pload_media = mean(Pload);
metricas.Pload_max = max(Pload);
metricas.Pload_min = min(Pload);

%% Métricas da fonte principal

metricas.Psource_max_observada = max(Psource);
metricas.Psource_media = mean(Psource);

% Violação do limite da fonte
violacao_fonte = Psource > Psource_max + 1e-6;

metricas.tempo_violacao_fonte_s = sum(violacao_fonte) * Ts;
metricas.percentual_violacao_fonte = 100 * sum(violacao_fonte) / length(Psource);

% Rampa da fonte
dPsource = diff(Psource) / Ts;

metricas.rampa_fonte_max = max(abs(dPsource));

%% Métricas do BESS

metricas.PBESS_max_descarga = max(PBESS);
metricas.PBESS_max_carga = min(PBESS);

% Energia descarregada pelo BESS
PBESS_descarga = PBESS;
PBESS_descarga(PBESS_descarga < 0) = 0;

metricas.Energia_BESS_descarga_kWh = sum(PBESS_descarga) * Ts / 3600;

% Energia de carga do BESS
PBESS_carga = PBESS;
PBESS_carga(PBESS_carga > 0) = 0;

metricas.Energia_BESS_carga_kWh = abs(sum(PBESS_carga) * Ts / 3600);

%% Métricas de SOC

metricas.SOC_inicial = SOC(1);
metricas.SOC_final = SOC(end);
metricas.SOC_minimo = min(SOC);
metricas.SOC_maximo = max(SOC);

%% Métricas de potência não atendida

metricas.Pnao_atendida_max = max(Pnao_atendida);

metricas.Energia_nao_atendida_kWh = sum(Pnao_atendida) * Ts / 3600;

metricas.tempo_com_carga_nao_atendida_s = sum(Pnao_atendida > 1e-6) * Ts;

metricas.percentual_tempo_carga_nao_atendida = ...
    100 * sum(Pnao_atendida > 1e-6) / length(Pnao_atendida);

%% Impressão dos resultados

fprintf('\n=====================================\n');
fprintf('METRICAS DA SIMULACAO\n');
fprintf('=====================================\n');

fprintf('Carga media: %.2f kW\n', metricas.Pload_media);
fprintf('Carga maxima: %.2f kW\n', metricas.Pload_max);

fprintf('\n--- Fonte principal ---\n');
fprintf('Potencia maxima da fonte: %.2f kW\n', metricas.Psource_max_observada);
fprintf('Potencia media da fonte: %.2f kW\n', metricas.Psource_media);
fprintf('Tempo de violacao do limite da fonte: %.2f s\n', metricas.tempo_violacao_fonte_s);
fprintf('Percentual de violacao da fonte: %.2f %%\n', metricas.percentual_violacao_fonte);
fprintf('Rampa maxima da fonte: %.2f kW/s\n', metricas.rampa_fonte_max);

fprintf('\n--- BESS ---\n');
fprintf('Potencia maxima de descarga do BESS: %.2f kW\n', metricas.PBESS_max_descarga);
fprintf('Potencia maxima de carga do BESS: %.2f kW\n', metricas.PBESS_max_carga);
fprintf('Energia fornecida pelo BESS: %.2f kWh\n', metricas.Energia_BESS_descarga_kWh);
fprintf('Energia absorvida pelo BESS: %.2f kWh\n', metricas.Energia_BESS_carga_kWh);

fprintf('\n--- SOC ---\n');
fprintf('SOC inicial: %.2f %%\n', metricas.SOC_inicial);
fprintf('SOC final: %.2f %%\n', metricas.SOC_final);
fprintf('SOC minimo: %.2f %%\n', metricas.SOC_minimo);
fprintf('SOC maximo: %.2f %%\n', metricas.SOC_maximo);

fprintf('\n--- Carga nao atendida ---\n');
fprintf('Potencia nao atendida maxima: %.2f kW\n', metricas.Pnao_atendida_max);
fprintf('Energia nao atendida: %.2f kWh\n', metricas.Energia_nao_atendida_kWh);
fprintf('Tempo com carga nao atendida: %.2f s\n', metricas.tempo_com_carga_nao_atendida_s);
fprintf('Percentual do tempo com carga nao atendida: %.2f %%\n', metricas.percentual_tempo_carga_nao_atendida);

fprintf('=====================================\n');

end