function param = parametros()
% PARAMETROS
% Parâmetros iniciais do projeto MPC para gerenciamento energético
% de data center de IA/HPC com BESS/UPS.
%
% Este arquivo centraliza os dados do sistema para evitar variáveis soltas.
% Observação:
% Os valores adotados neste arquivo são premissas iniciais de simulação.
% Eles representam um estudo de caso agregado e deverão ser refinados
% posteriormente com dados de literatura, datasheets ou ensaios de bancada.

%% Tempo de simulação

param.Ts = 1;              % Tempo de amostragem [s]
param.Tf = 1200;           % Tempo total de simulação [s]

%% Fonte principal / rede

param.Psource_max_nominal = 800;   % Limite nominal da fonte/rede [kW]
param.Rsource_max = 100;           % Rampa máxima desejada da fonte [kW/s]

%% Carga crítica do data center

param.Pload_base = 600;    % Carga base [kW]
param.Pload_media = 750;   % Carga média [kW]
param.Pload_alta = 950;    % Carga alta IA/HPC [kW]

%% BESS / UPS

param.Ebat = 500;          % Energia nominal da bateria [kWh]

param.SOC_min = 20;        % SOC mínimo permitido [%]
param.SOC_max = 90;        % SOC máximo permitido [%]
param.SOC_ref = 60;        % SOC inicial/referência [%]

param.PBESS_max = 400;     % Potência máxima de descarga do BESS [kW]
param.PBESS_min = -250;    % Potência máxima de carga do BESS [kW]

%% Dinâmica agregada do BESS/conversor

param.tau_b = 2;           % Constante de tempo do BESS/conversor [s] - velocidade de resposta agregada
                            % PBESS​(k+1)=ab​PBESS​(k)+bb​PBESSref​(k)
                            %


param.ab = exp(-param.Ts/param.tau_b);
param.bb = 1 - param.ab;

%% Eficiência simplificada

param.eta_descarga = 0.95; % Eficiência na descarga
param.eta_carga = 0.95;    % Eficiência na carga




%% Parâmetros do MPC-QP (V4/V5)

param.Np_mpc = 60;              % horizonte de predição [passos]
param.Nc_mpc = 15;              % horizonte de controle [passos]

% Limite de variação da referência do BESS
param.dPBESS_ref_max = 120;           % operação normal [kW/amostra]
param.dPBESS_ref_max_evento = 400;    % modo evento / preparação [kW/amostra]

% Janela de preparação antes de falha ou alta demanda [passos]
param.Nprep_evento_mpc = 30;

% Prioridades do MPC
param.w_mpc_source_tracking = 3000;

% Carga crítica deve ser prioridade máxima
param.w_mpc_slack_load = 1e9;

% Não violar fonte continua muito importante
param.w_mpc_slack_source = 1e8;

% Preparação/suporte de evento (antecipação)
param.w_mpc_slack_event = 1e9;

% Recarga deve existir, mas não pode competir com atendimento da carga
param.w_mpc_slack_recharge = 1e6;

% Reduzir rampa, mas sem sacrificar carga crítica
param.w_mpc_rampa = 300;

% Preservar SOC
param.w_mpc_soc = 1200;
param.w_mpc_soc_terminal = 12000;

% Evitar uso excessivo do BESS
param.w_mpc_uso_bess = 20;

% Suavizar comando do BESS
param.w_mpc_delta_u = 50;

% Recarga limitada pela folga típica dos cenários
param.P_recarga_mpc_max = 50;
param.banda_SOC_mpc = 0.3;

param.SOC_margem_mpc = 0;
% eta_mpc: legado; preditor atual usa eta_descarga/eta_carga via ganhos Kd/Kc
% (linearização sucessiva na resposta livre de P_BESS).
param.eta_mpc = 0.95;

% w_mpc_throughput: legado (não usado no QP atual; o custo de uso do BESS
% é w_mpc_uso_bess sobre ||P_BESS||^2). Mantido só por compatibilidade.
% param.w_mpc_throughput = 20;

% Foresight no horizonte (true = vê eventos futuros; false = só instante atual)
param.mpc_foresight_grid = true;
param.mpc_foresight_load = true;

% Confirmação conservadora (revisão IEEE): inf = comportamento do artigo submetido.
% event_arm_horizon: só arma preparação se o evento previsto está a <= N passos
%   (ou se o evento já ocorreu no instante atual). 8 passos @ Ts=1s cobre ~4*tau_b.
% event_min_duration: ignora picos previstos mais curtos que este número de passos.
param.event_arm_horizon = inf;
param.event_min_duration = 1;

% condest(H) no primeiro QP (campanha de pesos / apêndice)
param.report_hess_cond = false;
end