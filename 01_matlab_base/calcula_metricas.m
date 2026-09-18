function metricas = calcula_metricas(t, Pload, Psource, PBESS, SOC, Psource_max, Pnao_atendida, param, varargin)
% CALCULA_METRICAS
% Indicadores técnicos da simulação EMS + BESS/UPS.
%
% Opcional (Name-Value):
%   'grid_status' -> vetor 0/1 para localizar início de evento
%   'PBESS_ref'   -> referência de comando (rampas de u)

grid_status = [];
PBESS_ref = [];
if ~isempty(varargin)
    for ii = 1:2:numel(varargin)
        switch lower(varargin{ii})
            case 'grid_status'
                grid_status = varargin{ii+1};
            case 'pbess_ref'
                PBESS_ref = varargin{ii+1};
        end
    end
end

Ts = param.Ts;

%% Carga / fonte

metricas.Pload_media = mean(Pload);
metricas.Pload_max = max(Pload);
metricas.Pload_min = min(Pload);

metricas.Psource_max_observada = max(Psource);
metricas.Psource_media = mean(Psource);

violacao_fonte = Psource > Psource_max + 1e-6;
metricas.tempo_violacao_fonte_s = sum(violacao_fonte) * Ts;
metricas.percentual_violacao_fonte = 100 * sum(violacao_fonte) / length(Psource);
metricas.Energia_violacao_fonte_kWh = sum(max(Psource - Psource_max, 0)) * Ts / 3600;

dPsource = diff(Psource) / Ts;
metricas.rampa_fonte_max = max(abs(dPsource));
metricas.rampa_fonte_media_abs = mean(abs(dPsource));
metricas.rampa_fonte_rms = sqrt(mean(dPsource.^2));
metricas.rampa_fonte_p95 = prctile(abs(dPsource), 95);

%% BESS

metricas.PBESS_max_descarga = max(PBESS);
metricas.PBESS_max_carga = min(PBESS);

PBESS_descarga = PBESS;
PBESS_descarga(PBESS_descarga < 0) = 0;
metricas.Energia_BESS_descarga_kWh = sum(PBESS_descarga) * Ts / 3600;

PBESS_carga = PBESS;
PBESS_carga(PBESS_carga > 0) = 0;
metricas.Energia_BESS_carga_kWh = abs(sum(PBESS_carga) * Ts / 3600);

metricas.Energia_throughput_kWh = sum(abs(PBESS)) * Ts / 3600;
metricas.N_EFC = metricas.Energia_throughput_kWh / max(2 * param.Ebat, eps);

dPBESS = diff(PBESS) / Ts;
metricas.rampa_BESS_max = max(abs(dPBESS));

if ~isempty(PBESS_ref)
    du = diff(PBESS_ref);
    metricas.TV_u = sum(abs(du));
    metricas.rampa_u_max = max(abs(du)) / Ts;
else
    metricas.TV_u = NaN;
    metricas.rampa_u_max = NaN;
end

%% SOC

metricas.SOC_inicial = SOC(1);
metricas.SOC_final = SOC(end);
metricas.SOC_minimo = min(SOC);
metricas.SOC_maximo = max(SOC);

% Reserva energética no início (janela útil até SOC_min)
eta_d = param.eta_descarga;
metricas.E_reserva_inicial_kWh = (SOC(1) - param.SOC_min) / 100 * param.Ebat * eta_d;

%% Evento (SOC no início da falha / alta demanda)

metricas.SOC_no_evento = NaN;
metricas.t_evento_s = NaN;
if ~isempty(grid_status)
    idx_falha = find(grid_status == 0, 1, 'first');
    if ~isempty(idx_falha)
        metricas.t_evento_s = t(idx_falha);
        metricas.SOC_no_evento = SOC(idx_falha);
    end
end
if isnan(metricas.SOC_no_evento)
    idx_alta = find(Pload > Psource_max + 1e-6, 1, 'first');
    if ~isempty(idx_alta)
        metricas.t_evento_s = t(idx_alta);
        metricas.SOC_no_evento = SOC(idx_alta);
    end
end

if ~isnan(metricas.SOC_no_evento)
    metricas.E_reserva_no_evento_kWh = ...
        (metricas.SOC_no_evento - param.SOC_min) / 100 * param.Ebat * eta_d;
else
    metricas.E_reserva_no_evento_kWh = NaN;
end

%% Potência / energia não atendida

limiar_pnao = max(1, 0.001 * max(Pload));
Pnao_filtrada = Pnao_atendida;
Pnao_filtrada(Pnao_filtrada < limiar_pnao) = 0;

metricas.Pnao_atendida_max = max(Pnao_filtrada);
metricas.Pnao_p95 = prctile(Pnao_filtrada, 95);
metricas.Pnao_p99 = prctile(Pnao_filtrada, 99);
metricas.Energia_nao_atendida_kWh = sum(Pnao_filtrada) * Ts / 3600;
metricas.tempo_com_carga_nao_atendida_s = sum(Pnao_filtrada > 0) * Ts;
metricas.percentual_tempo_carga_nao_atendida = ...
    100 * sum(Pnao_filtrada > 0) / length(Pnao_filtrada);
metricas.n_violacoes_pnao = sum(Pnao_filtrada > 0);
metricas.T_pnao_gt_50_s = sum(Pnao_filtrada > 50) * Ts;
metricas.T_pnao_gt_100_s = sum(Pnao_filtrada > 100) * Ts;
metricas.T_pnao_gt_350_s = sum(Pnao_filtrada > 350) * Ts;
[~, imax_pnao] = max(Pnao_filtrada);
idx_rec = find(Pnao_filtrada(imax_pnao:end) < limiar_pnao, 1, 'first');
if isempty(idx_rec)
    metricas.t_recovery_s = NaN;
else
    metricas.t_recovery_s = (idx_rec - 1) * Ts;
end

%% Impressão

fprintf('\n=====================================\n');
fprintf('METRICAS DA SIMULACAO\n');
fprintf('=====================================\n');
fprintf('Carga media: %.2f kW | max: %.2f kW\n', metricas.Pload_media, metricas.Pload_max);
fprintf('Pnao max: %.2f kW | Energia nao: %.3f kWh | T_nao: %.1f s\n', ...
    metricas.Pnao_atendida_max, metricas.Energia_nao_atendida_kWh, ...
    metricas.tempo_com_carga_nao_atendida_s);
fprintf('Throughput: %.3f kWh | EFC: %.4f | SOC final: %.2f %%\n', ...
    metricas.Energia_throughput_kWh, metricas.N_EFC, metricas.SOC_final);
if ~isnan(metricas.SOC_no_evento)
    fprintf('SOC no evento (t=%.0fs): %.2f %%\n', metricas.t_evento_s, metricas.SOC_no_evento);
end
fprintf('Rampa fonte max: %.2f kW/s | p95: %.2f kW/s\n', ...
    metricas.rampa_fonte_max, metricas.rampa_fonte_p95);
fprintf('=====================================\n');

end
