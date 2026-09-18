function PBESS_ref = controle_heuristico(Pload, Psource_max, grid_status, SOC, param)
% CONTROLE_HEURISTICO
% Controlador simples baseado em regras para gerenciamento do BESS.
%
% Objetivos:
% - Se a fonte cair, o BESS tenta alimentar a carga.
% - Se a fonte estiver disponível e a carga ultrapassar o limite da fonte,
%   o BESS cobre a diferença.
% - Se a fonte estiver disponível, a carga estiver abaixo do limite e o SOC
%   estiver abaixo da referência, o BESS recarrega usando a folga da fonte.
% - Respeita limites de potência e SOC.
%
% Convenção:
% PBESS_ref > 0  -> BESS descarrega, fornecendo potência à carga
% PBESS_ref < 0  -> BESS carrega, absorvendo potência da fonte
% PBESS_ref = 0  -> BESS em repouso

%% Parâmetros auxiliares

SOC_ref = param.SOC_ref;

% Margem para evitar chaveamento excessivo ao redor do SOC_ref
banda_SOC = 0.5;   % [%]

% Potência máxima desejada de recarga no heurístico
% Usa o limite físico do BESS, mas deixa a recarga mais suave.
P_carga_heuristica_max = min(abs(param.PBESS_min), 150);  % kW

%% Caso 1: fonte indisponível

if grid_status == 0

    % Durante a perda da fonte, o BESS tenta alimentar a carga.
    PBESS_ref = Pload;

else

    %% Caso 2: fonte disponível

    if Pload > Psource_max

        % Se a carga ultrapassa o limite da fonte, o BESS cobre a diferença.
        PBESS_ref = Pload - Psource_max;

    else

        % A fonte consegue alimentar a carga.
        % Agora verificamos se existe folga para recarregar o BESS.

        folga_fonte = Psource_max - Pload;

        if SOC < (SOC_ref - banda_SOC) && folga_fonte > 0

            % Recarrega respeitando:
            % - folga disponível da fonte;
            % - limite definido para recarga heurística;
            % - limite físico de carga do BESS.
            P_carga = min(folga_fonte, P_carga_heuristica_max);

            % Potência negativa significa carga do BESS.
            PBESS_ref = -P_carga;

        else

            % Se SOC está adequado ou não há folga, BESS fica parado.
            PBESS_ref = 0;

        end

    end

end

%% Proteção por SOC

% Se SOC está no mínimo, não deixa descarregar
if SOC <= param.SOC_min && PBESS_ref > 0
    PBESS_ref = 0;
end

% Se SOC está no máximo, não deixa carregar
if SOC >= param.SOC_max && PBESS_ref < 0
    PBESS_ref = 0;
end

%% Saturação da referência do BESS

PBESS_ref = min(PBESS_ref, param.PBESS_max);
PBESS_ref = max(PBESS_ref, param.PBESS_min);

end