function PBESS_ref = controle_heuristico_foresight( ...
    k, ...
    SOC, ...
    PBESS_ref_anterior, ...
    Pload, ...
    Psource_max, ...
    grid_status, ...
    param)
% CONTROLE_HEURISTICO_FORESIGHT
% Mesmas regras do heurístico reativo, porém com antecipação de eventos
% usando a mesma informação futura disponível ao MPC (carga, limite, rede).
%
% Isola o ganho da previsão versus o ganho da otimização multietapa.

if isfield(param, 'Nprep_evento_mpc')
    Nprep = param.Nprep_evento_mpc;
else
    Nprep = 30;
end

if isfield(param, 'dPBESS_ref_max')
    dUmax = param.dPBESS_ref_max;
else
    dUmax = 120;
end
if isfield(param, 'dPBESS_ref_max_evento')
    dUmax_evento = param.dPBESS_ref_max_evento;
else
    dUmax_evento = 400;
end

N = length(Pload);
idx_fim = min(k + max(Nprep, 1) - 1, N);

% Detecta primeiro evento no horizonte de preparação
target = 0;
i_rel = [];
for i = k:idx_fim
    if grid_status(i) == 0
        target = min(Pload(i), param.PBESS_max);
        i_rel = i;
        break;
    elseif Pload(i) > Psource_max(i)
        target = min(max(Pload(i) - Psource_max(i), 0), param.PBESS_max);
        i_rel = i;
        break;
    end
end

modo_evento = ~isempty(i_rel) && target > 0;

if modo_evento
    dist = i_rel - k;  % 0 = evento agora
    if dist <= Nprep
        alpha = (Nprep - dist + 1) / Nprep;
        u_prep = alpha * target;
    else
        u_prep = 0;
    end

    % Durante o evento: regras reativas de emergência/suporte
    if grid_status(k) == 0 || Pload(k) > Psource_max(k)
        PBESS_ref = controle_heuristico( ...
            Pload(k), Psource_max(k), grid_status(k), SOC, param);
    else
        PBESS_ref = max(u_prep, 0);
    end

    dU = dUmax_evento;
else
    PBESS_ref = controle_heuristico( ...
        Pload(k), Psource_max(k), grid_status(k), SOC, param);
    dU = dUmax;
end

% Limite de rampa do comando (comparável ao MPC)
if nargin >= 3 && ~isempty(PBESS_ref_anterior)
    PBESS_ref = min(PBESS_ref, PBESS_ref_anterior + dU);
    PBESS_ref = max(PBESS_ref, PBESS_ref_anterior - dU);
end

if SOC <= param.SOC_min && PBESS_ref > 0
    PBESS_ref = 0;
end
if SOC >= param.SOC_max && PBESS_ref < 0
    PBESS_ref = 0;
end
if grid_status(k) == 0 && PBESS_ref < 0
    PBESS_ref = 0;
end

PBESS_ref = min(max(PBESS_ref, param.PBESS_min), param.PBESS_max);

end
