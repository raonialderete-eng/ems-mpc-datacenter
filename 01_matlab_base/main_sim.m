clc;
clear;
close all;

%% MAIN_SIM
% Simulação completa do sistema:
% Data center + fonte principal + BESS/UPS
% Controle heurístico inicial

%% 1. Carregar parâmetros

param = parametros();

%% 2. Criar vetor de tempo

t = 0:param.Ts:param.Tf;
N = length(t);

%% 3. Escolher cenário

% Opções:
% 'carga_faixas'
% 'limite_fonte'
% 'perda_fonte'
% 'retorno_fonte'

tipo_cenario = 'perda_fonte';

[Pload, Psource_max, grid_status, nome_cenario] = gera_cenario(t, tipo_cenario, param);

%% 4. Inicializar variáveis

SOC = zeros(1,N);
PBESS = zeros(1,N);
PBESS_ref = zeros(1,N);
Psource = zeros(1,N);
Pnao_atendida = zeros(1,N);

SOC(1) = param.SOC_ref;
PBESS(1) = 0;

%% 5. Loop de simulação

for k = 1:N-1

    % Controlador heurístico
    PBESS_ref(k) = controle_heuristico( ...
        Pload(k), ...
        Psource_max(k), ...
        grid_status(k), ...
        SOC(k), ...
        param);

    % Planta BESS
    [SOC(k+1), PBESS(k+1), Psource(k), Pnao_atendida(k)] = planta_bess( ...
        SOC(k), ...
        PBESS(k), ...
        PBESS_ref(k), ...
        Pload(k), ...
        Psource_max(k), ...
        grid_status(k), ...
        param);

end

%% 6. Último ponto

PBESS_ref(N) = PBESS_ref(N-1);

if grid_status(N) == 1
    Psource(N) = min(Pload(N) - PBESS(N), Psource_max(N));
else
    Psource(N) = 0;
end

Psource(N) = max(Psource(N), 0);
Pnao_atendida(N) = max(0, Pload(N) - Psource(N) - PBESS(N));

%% 7. Calcular métricas

metricas = calcula_metricas(t, Pload, Psource, PBESS, SOC, Psource_max, Pnao_atendida, param);

%% 8. Gráficos

figure

subplot(5,1,1)
plot(t, Pload, 'LineWidth', 1.8)
grid on
ylabel('Pload [kW]')
title(nome_cenario)

subplot(5,1,2)
plot(t, Psource_max, '--', 'LineWidth', 1.5)
hold on
plot(t, Psource, 'LineWidth', 1.8)
grid on
ylabel('Fonte [kW]')
legend('Limite fonte', 'Psource')

subplot(5,1,3)
plot(t, PBESS_ref, '--', 'LineWidth', 1.5)
hold on
plot(t, PBESS, 'LineWidth', 1.8)
grid on
ylabel('BESS [kW]')
legend('PBESS ref', 'PBESS real')

subplot(5,1,4)
plot(t, SOC, 'LineWidth', 1.8)
grid on
ylabel('SOC [%]')

subplot(5,1,5)
plot(t, Pnao_atendida, 'LineWidth', 1.8)
grid on
ylabel('P não atend. [kW]')
xlabel('Tempo [s]')

%% 9. Resultados básicos

fprintf('\n=====================================\n');
fprintf('RESULTADOS DA SIMULACAO\n');
fprintf('=====================================\n');
fprintf('Cenario: %s\n', nome_cenario);
fprintf('SOC inicial: %.2f %%\n', SOC(1));
fprintf('SOC final: %.2f %%\n', SOC(end));
fprintf('SOC minimo: %.2f %%\n', min(SOC));
fprintf('Psource max observada: %.2f kW\n', max(Psource));
fprintf('PBESS max observada: %.2f kW\n', max(PBESS));
fprintf('Potencia nao atendida maxima: %.2f kW\n', max(Pnao_atendida));
fprintf('=====================================\n');