clc;
clear;
close all;

%% MAIN_TODOS_CENARIOS
% Roda todos os cenários usando controle heurístico.
%
% Objetivo:
% - Validar a planta;
% - Validar o controle heurístico;
% - Comparar os cenários;
% - Gerar métricas para futura comparação com MPC.

%% 1. Carregar parâmetros-base

param_base = parametros();

%% 2. Lista de cenários

cenarios = { ...
    'carga_faixas', ...
    'limite_fonte', ...
    'perda_fonte', ...
    'retorno_fonte'};

% Escolha do controlador:
% 'heuristico'
% 'mpc_qp_v3'

tipo_controle = 'mpc_qp_v3';

switch tipo_controle

    case 'heuristico'
        nomes_controle = 'Heuristico';

    case 'mpc_qp_v3'
        nomes_controle = 'MPC-QP-V3';

    otherwise
        error('Tipo de controle não reconhecido.');

end

%% 3. Configurações

gerar_graficos = true;
salvar_resultados = true;

%% 4. Criar pasta de saída

pasta_atual = pwd;
[pasta_pai, nome_pasta] = fileparts(pasta_atual);

if strcmp(nome_pasta, '01_matlab_base')
    pasta_projeto = pasta_pai;
else
    pasta_projeto = pasta_atual;
end

pasta_saida = fullfile(pasta_projeto, '05_resultados');

if ~exist(pasta_saida, 'dir')
    mkdir(pasta_saida);
end

%% 5. Inicializar estrutura de resultados

resultados = struct();

%% 6. Loop principal dos cenários

for i = 1:length(cenarios)

    tipo_cenario = cenarios{i};

    fprintf('\n\n=====================================\n');
    fprintf('RODANDO CENARIO: %s\n', tipo_cenario);
    fprintf('CONTROLE: %s\n', nomes_controle);
    fprintf('=====================================\n');

    %% 6.1 Ajustar parâmetros por cenário

    param = param_base;

    % Para a falha crítica, usamos tempo maior.
    % 14400 s = 4 horas.
    if strcmp(tipo_cenario, 'falha_critica')
        param.Tf = 14400;
    else
        param.Tf = 1200;
    end

    %% 6.2 Criar vetor de tempo

    t = 0:param.Ts:param.Tf;
    N = length(t);

    %% 6.3 Gerar cenário

    [Pload, Psource_max, grid_status, nome_cenario] = ...
        gera_cenario(t, tipo_cenario, param);

    %% 6.4 Inicializar variáveis

    SOC = zeros(1,N);
    PBESS = zeros(1,N);
    PBESS_ref = zeros(1,N);
    Psource = zeros(1,N);
    Pnao_atendida = zeros(1,N);

    SOC(1) = param.SOC_ref;
    PBESS(1) = 0;

      %% 6.5 Loop de simulação
    %% 6.5 Loop de simulação

    contador_qp_ok = 0;
    contador_fallback = 0;
    exitflags_mpc = zeros(1,N);

    for k = 1:N-1

        %% 6.5.1 Escolha do controlador

        switch tipo_controle

            case 'heuristico'

                PBESS_ref(k) = controle_heuristico( ...
                    Pload(k), ...
                    Psource_max(k), ...
                    grid_status(k), ...
                    SOC(k), ...
                    param);

            case 'mpc_qp_v3'

                if k == 1
                    PBESS_ref_anterior = 0;
                    Psource_anterior = Pload(k);
                else
                    PBESS_ref_anterior = PBESS_ref(k-1);
                    Psource_anterior = Psource(k-1);
                end

                [PBESS_ref(k), info_mpc_k] = controle_mpc_qp_v3( ...
                    k, ...
                    SOC(k), ...
                    PBESS(k), ...
                    PBESS_ref_anterior, ...
                    Psource_anterior, ...
                    Pload, ...
                    Psource_max, ...
                    grid_status, ...
                    param);

                exitflags_mpc(k) = info_mpc_k.exitflag;

                if info_mpc_k.usou_fallback == true
                    contador_fallback = contador_fallback + 1;
                else
                    contador_qp_ok = contador_qp_ok + 1;
                end

            otherwise

                error('Tipo de controle não reconhecido.');

        end

        %% 6.5.2 Planta BESS

        [SOC(k+1), PBESS(k+1), Psource(k), Pnao_atendida(k)] = planta_bess( ...
            SOC(k), ...
            PBESS(k), ...
            PBESS_ref(k), ...
            Pload(k), ...
            Psource_max(k), ...
            grid_status(k), ...
            param);

    end

    end

    %% 6.6 Último ponto

    PBESS_ref(N) = PBESS_ref(N-1);

    if grid_status(N) == 1
        Psource(N) = min(Pload(N) - PBESS(N), Psource_max(N));
    else
        Psource(N) = 0;
    end

    Psource(N) = max(Psource(N), 0);
    Pnao_atendida(N) = max(0, Pload(N) - Psource(N) - PBESS(N));

    %% 6.7 Calcular métricas

    metricas = calcula_metricas( ...
        t, ...
        Pload, ...
        Psource, ...
        PBESS, ...
        SOC, ...
        Psource_max, ...
        Pnao_atendida, ...
        param);

        %% 6.8      Diagnóstico do MPC

    if strcmp(tipo_controle, 'mpc_qp_v3')

        fprintf('\n--- Diagnostico MPC-QP-V3 ---\n');
        fprintf('Passos com QP OK: %d\n', contador_qp_ok);
        fprintf('Passos com fallback heuristico: %d\n', contador_fallback);
        fprintf('Percentual de fallback: %.2f %%\n', ...
            100 * contador_fallback / max(1,(N-1)));

    end
    %% 6.9 Guardar resultados na estrutura

    resultados(i).tipo_cenario = tipo_cenario;
    resultados(i).nome_cenario = nome_cenario;
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

    %% 6.10 Gráficos

    if gerar_graficos == true

        if max(t) >= 7200
            tempo_plot = t/3600;
            label_tempo = 'Tempo [h]';
        else
            tempo_plot = t/60;
            label_tempo = 'Tempo [min]';
        end

        figure('Name', nome_cenario, 'NumberTitle', 'off');

        subplot(5,1,1)
        plot(tempo_plot, Pload, 'LineWidth', 1.8)
        grid on
        ylabel('Pload [kW]')
        title([nome_cenario ' - Controle heurístico'])

        subplot(5,1,2)
        plot(tempo_plot, Psource_max, '--', 'LineWidth', 1.5)
        hold on
        plot(tempo_plot, Psource, 'LineWidth', 1.8)
        grid on
        ylabel('Fonte [kW]')
        legend('Limite fonte', 'Psource', 'Location', 'best')

        subplot(5,1,3)
        plot(tempo_plot, PBESS_ref, '--', 'LineWidth', 1.5)
        hold on
        plot(tempo_plot, PBESS, 'LineWidth', 1.8)
        grid on
        ylabel('BESS [kW]')
        legend('PBESS ref', 'PBESS real', 'Location', 'best')

        subplot(5,1,4)
        plot(tempo_plot, SOC, 'LineWidth', 1.8)
        grid on
        ylabel('SOC [%]')

        subplot(5,1,5)
        plot(tempo_plot, Pnao_atendida, 'LineWidth', 1.8)
        grid on
        ylabel('P não atend. [kW]')
        xlabel(label_tempo)

        if salvar_resultados == true
            nome_figura = ['heuristico_' tipo_cenario '.png'];
            saveas(gcf, fullfile(pasta_saida, nome_figura));
        end

    end



%% 7. Montar tabela comparativa

n = length(resultados);

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

end

tabela_metricas = table( ...
    Cenario, ...
    Controle, ...
    Pload_media_kW, ...
    Pload_max_kW, ...
    Psource_max_observada_kW, ...
    Psource_media_kW, ...
    Rampa_fonte_max_kW_s, ...
    Tempo_violacao_fonte_s, ...
    PBESS_max_descarga_kW, ...
    PBESS_max_carga_kW, ...
    Energia_BESS_descarga_kWh, ...
    Energia_BESS_carga_kWh, ...
    SOC_inicial_percent, ...
    SOC_final_percent, ...
    SOC_minimo_percent, ...
    SOC_maximo_percent, ...
    Pnao_atendida_max_kW, ...
    Energia_nao_atendida_kWh, ...
    Tempo_carga_nao_atendida_s, ...
    Percentual_tempo_carga_nao_atendida);

%% 8. Mostrar tabela no Command Window

fprintf('\n\n=====================================\n');
fprintf('TABELA COMPARATIVA - CONTROLE %s\n', nomes_controle);
fprintf('=====================================\n');

disp(tabela_metricas)

%% 9. Salvar tabela e resultados

if salvar_resultados == true

  arquivo_csv = fullfile(pasta_saida, ['metricas_' tipo_controle '_todos_cenarios.csv']);
writetable(tabela_metricas, arquivo_csv);

arquivo_mat = fullfile(pasta_saida, ['resultados_' tipo_controle '_todos_cenarios.mat']);
save(arquivo_mat, 'resultados', 'tabela_metricas');

    
    fprintf('\nArquivos salvos em:\n');
    fprintf('%s\n', pasta_saida);
    fprintf('\nCSV salvo como:\n');
    fprintf('%s\n', arquivo_csv);
    fprintf('\nMAT salvo como:\n');
    fprintf('%s\n', arquivo_mat);

end

fprintf('\n=====================================\n');
fprintf('SIMULACAO DE TODOS OS CENARIOS CONCLUIDA\n');
fprintf('=====================================\n');