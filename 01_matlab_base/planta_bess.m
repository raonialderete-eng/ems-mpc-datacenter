function [SOC_next, PBESS_next, Psource, Pnao_atendida] = planta_bess(SOC, PBESS, PBESS_ref, Pload, Psource_max, grid_status, param)
% PLANTA_BESS
% Modelo simplificado da planta elétrica:
% data center + fonte principal + BESS/UPS.
%
% Convenção:
% PBESS > 0  -> bateria descarregando, fornecendo potência à carga
% PBESS < 0  -> bateria carregando, consumindo potência da fonte
%
% Entradas:
% SOC          -> estado de carga atual da bateria [%]
% PBESS        -> potência atual do BESS [kW]
% PBESS_ref    -> referência de potência do BESS [kW]
% Pload        -> potência da carga crítica [kW]
% Psource_max  -> limite disponível da fonte [kW]
% grid_status  -> 1 fonte disponível, 0 fonte indisponível
% param        -> estrutura de parâmetros
%
% Saídas:
% SOC_next       -> próximo SOC [%]
% PBESS_next     -> próxima potência real do BESS [kW]
% Psource        -> potência fornecida pela fonte [kW]
% Pnao_atendida  -> potência da carga não atendida [kW]

%% 1. Aplicar saturação na referência do BESS

PBESS_ref = min(PBESS_ref, param.PBESS_max);
PBESS_ref = max(PBESS_ref, param.PBESS_min);

%% 2. Dinâmica de primeira ordem do BESS/conversor

PBESS_next = param.ab * PBESS + param.bb * PBESS_ref;

%% 3. Aplicar saturação na potência real do BESS

PBESS_next = min(PBESS_next, param.PBESS_max);
PBESS_next = max(PBESS_next, param.PBESS_min);

%% 4. Proteção de SOC

% Se SOC está no mínimo, não deixa descarregar
if SOC <= param.SOC_min && PBESS_next > 0
    PBESS_next = 0;
end

% Se SOC está no máximo, não deixa carregar
if SOC >= param.SOC_max && PBESS_next < 0
    PBESS_next = 0;
end

%% 5. Calcular potência da fonte

% Balanço:
% Psource + PBESS = Pload
% Portanto:
% Psource = Pload - PBESS

if grid_status == 1
    Psource = Pload - PBESS_next;
else
    Psource = 0;
end

%% 6. Limitar potência da fonte

if Psource > Psource_max
    Psource = Psource_max;
end

if Psource < 0
    Psource = 0;
end

%% 7. Calcular potência não atendida

Pnao_atendida = Pload - Psource - PBESS_next;

if Pnao_atendida < 0
    Pnao_atendida = 0;
end

%% 8. Atualizar SOC

% Energia em kWh:
% P [kW] * Ts [s] / 3600 = kWh

if PBESS_next >= 0
    % Descarga
    delta_SOC = (PBESS_next * param.Ts / 3600) / (param.Ebat * param.eta_descarga) * 100;
else
    % Carga
    delta_SOC = (PBESS_next * param.Ts / 3600) * param.eta_carga / param.Ebat * 100;
end

% Como PBESS > 0 descarrega, SOC diminui
SOC_next = SOC - delta_SOC;

%% 9. Saturar SOC

SOC_next = min(SOC_next, param.SOC_max);
SOC_next = max(SOC_next, param.SOC_min);

end