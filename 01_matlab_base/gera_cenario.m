function [Pload, Psource_max, grid_status, nome_cenario] = gera_cenario(t, tipo, param)
% GERA_CENARIO
% Gera os perfis de carga, limite da fonte e status da rede/fonte
% para os cenários do artigo MPC/BESS para data center.
%
% Entradas:
% t     -> vetor de tempo [s]
% tipo  -> nome do cenário
% param -> estrutura de parâmetros
%
% Saídas:
% Pload        -> potência da carga crítica [kW]
% Psource_max  -> potência máxima disponível da fonte [kW]
% grid_status  -> 1 fonte disponível, 0 fonte indisponível
% nome_cenario -> nome descritivo do cenário

%% Inicialização

N = length(t);

% Valores padrão
Pload = param.Pload_base * ones(1,N);
Psource_max = param.Psource_max_nominal * ones(1,N);
grid_status = ones(1,N);

%% Escolha do cenário

switch tipo

    case 'carga_faixas'

        nome_cenario = 'Cenário 1 - Carga variável em faixas';

        % Perfil representando diferentes níveis de carga computacional
        Pload(t >= 0   & t < 200)  = param.Pload_base;   % 600 kW
        Pload(t >= 200 & t < 400)  = param.Pload_media;  % 750 kW
        Pload(t >= 400 & t < 650)  = param.Pload_alta;   % 950 kW
        Pload(t >= 650 & t < 850)  = 700;                % redução parcial
        Pload(t >= 850)            = param.Pload_base;   % retorno à base

        Psource_max(:) = param.Psource_max_nominal;
        grid_status(:) = 1;


    case 'limite_fonte'

        nome_cenario = 'Cenário 2 - Limite de potência da fonte';

        % Cenário pensado para representar uma condição em que a fonte
        % principal possui limite de fornecimento, enquanto a carga do
        % data center aumenta para um patamar superior.
        %
        % Objetivo:
        % - Testar se o BESS reduz o pico visto pela fonte;
        % - Evitar que Psource ultrapasse Psource_max;
        % - Avaliar a atuação do controle quando a carga cresce.

        % Fonte disponível durante todo o período
        grid_status(:) = 1;

        % Limite da fonte principal
        Psource_max(:) = param.Psource_max_nominal;  % 800 kW

        % Início em carga média, abaixo do limite da fonte
        Pload(:) = param.Pload_media;  % 750 kW

        % A partir de 200 s, carga alta de IA/HPC
        Pload(t >= 200) = param.Pload_alta;  % 950 kW


    case 'perda_fonte'

        nome_cenario = 'Cenário 3 - Perda da fonte principal';

        % Carga constante durante a falha
        Pload(:) = param.Pload_media;  % 750 kW

        % Fonte disponível inicialmente
        grid_status(:) = 1;

        % Perda da fonte entre 500 s e 650 s
        grid_status(t >= 500 & t < 650) = 0;

        % Quando a fonte cai, sua potência máxima disponível vira zero
        Psource_max = param.Psource_max_nominal * grid_status;


    case 'retorno_fonte'

        nome_cenario = 'Cenário 4 - Retorno da fonte principal';

        % Carga constante
        Pload(:) = param.Pload_media;  % 750 kW

        % Fonte disponível, depois cai, depois retorna
        grid_status(:) = 1;

        % Falha da fonte entre 400 s e 650 s
        grid_status(t >= 400 & t < 650) = 0;

        % Após retorno, fonte volta disponível
        grid_status(t >= 650) = 1;

        % Potência máxima da fonte acompanha o status da rede
        Psource_max = param.Psource_max_nominal * grid_status;
   
    case 'falha_critica'

        nome_cenario = 'Cenário crítico - Falha prolongada da fonte principal';

        % Carga crítica constante do data center
        Pload(:) = param.Pload_media;  % 750 kW

        % Fonte inicialmente disponível
        grid_status(:) = 1;

        % Falha prolongada da rede:
        % começa em 600 s e termina em 7800 s
        % duração da falha = 7200 s = 2 horas
        grid_status(t >= 600 & t < 7800) = 0;

        % Potência máxima da fonte acompanha o status da rede
        Psource_max = param.Psource_max_nominal * grid_status;

    case 'multi_burst'

        nome_cenario = 'Cenário 5 - Carga IA/HPC com múltiplos bursts';

        % Base + oscilações + degraus médios + picos próximos (perfil sintético
        % referenciado a padrões de workload de treinamento/inferência).
        Pload(:) = param.Pload_base;  % 600 kW
        Psource_max(:) = param.Psource_max_nominal;
        grid_status(:) = 1;

        % Burst 1: degrau médio
        Pload(t >= 120 & t < 180) = param.Pload_media;           % 750
        % Burst 2: pico alto curto
        Pload(t >= 220 & t < 260) = param.Pload_alta;            % 950
        % Recuperação parcial
        Pload(t >= 260 & t < 320) = 700;
        % Burst 3: pico novamente (eventos próximos)
        Pload(t >= 340 & t < 400) = param.Pload_alta;            % 950
        % Degrau médio sustentado
        Pload(t >= 450 & t < 600) = param.Pload_media;           % 750
        % Pico final
        Pload(t >= 700 & t < 780) = param.Pload_alta;            % 950
        % Oscilação leve em torno da base no restante pós-780
        idx_osc = (t >= 800 & t < 1000);
        Pload(idx_osc) = param.Pload_base + 40 * sin(2*pi*(t(idx_osc)-800)/60);

    case {'carga_nrel', 'carga_alibaba'}
        if strcmp(tipo, 'carga_nrel')
            nome_cenario = 'Carga NLR/DIPLOEE facility (1 min, afinizada, Ts=1 s)';
            default_csv = 'nrel_facility_1200s.csv';
        else
            nome_cenario = 'Carga NLR NVML treino Llama2-70B 16 nos (afinizada, Ts=1 s)';
            default_csv = 'alibaba_gpu_1200s.csv';
        end
        if isfield(param, 'trace_csv') && ~isempty(param.trace_csv)
            csv_path = param.trace_csv;
        else
            csv_path = localizar_trace_csv(default_csv);
        end
        Pload = carregar_trace_carga(csv_path, t, param);
        Psource_max(:) = param.Psource_max_nominal;
        grid_status(:) = 1;

    otherwise

        error(['Tipo de cenário não reconhecido. Use: carga_faixas, ' ...
            'limite_fonte, perda_fonte, retorno_fonte, falha_critica, multi_burst, ' ...
            'carga_nrel, carga_alibaba.']);

end

end

function csv_path = localizar_trace_csv(nome)
aqui = fileparts(mfilename('fullpath'));
cands = {
    fullfile(aqui, '..', '05_resultados', 'revisao_fase1', 'traces', nome)
    fullfile(pwd, '..', '05_resultados', 'revisao_fase1', 'traces', nome)
    fullfile(pwd, '05_resultados', 'revisao_fase1', 'traces', nome)
    };
csv_path = '';
for i = 1:numel(cands)
    if exist(cands{i}, 'file')
        csv_path = cands{i};
        return;
    end
end
error('Trace CSV nao encontrado: %s. Rode gerar_traces_revisao.m', nome);
end

function Pload = carregar_trace_carga(csv_path, t, param)
T = readtable(csv_path);
if any(strcmpi(T.Properties.VariableNames, 't_s'))
    tt = T.t_s;
elseif any(strcmpi(T.Properties.VariableNames, 't'))
    tt = T.t;
else
    tt = T{:,1};
end
if any(strcmpi(T.Properties.VariableNames, 'P_kW'))
    pp = T.P_kW;
elseif any(strcmpi(T.Properties.VariableNames, 'Pload_kW'))
    pp = T.Pload_kW;
else
    pp = T{:,2};
end
tt = double(tt(:));
pp = double(pp(:));
Pload = interp1(tt, pp, t, 'linear', 'extrap');
Pload = min(max(Pload, param.Pload_base * 0.85), param.Pload_alta * 1.05);
end