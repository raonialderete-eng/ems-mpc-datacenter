function out = simular_ems(tipo_controle, tipo_cenario, param)
% SIMULAR_EMS
% Simula um cenário com um controlador e devolve métricas + séries + tempos.
%
% Controles: heuristico | heuristico_foresight | miope_qp | mpc_qp_v4 | mpc_qp_v5 | mpc_qp_fpga
%
% Previsão imperfeita (opcional em param):
%   param.Pload_forecast, param.grid_forecast, param.Psource_max_forecast
%   Se presentes, o controlador enxerga esses vetores; a planta usa o cenário real.

if nargin < 3 || isempty(param)
    param = parametros();
end

switch tipo_controle
    case 'heuristico'
        nome_controle = 'Heuristico';
    case 'heuristico_foresight'
        nome_controle = 'Heuristico-FS';
    case 'miope_qp'
        nome_controle = 'Miope-QP';
    case 'mpc_qp_v4'
        nome_controle = 'MPC-QP-V4';
    case 'mpc_qp_v5'
        nome_controle = 'MPC-QP-V5';
    case 'mpc_qp_fpga'
        nome_controle = 'MPC-QP-FPGA';
    otherwise
        error('Controle nao suportado: %s', tipo_controle);
end

t = 0:param.Ts:param.Tf;
N = length(t);

[Pload, Psource_max, grid_status, nome_cenario] = ...
    gera_cenario(t, tipo_cenario, param);

% Vetores vistos pelo controlador (previsão); default = verdade
if isfield(param, 'Pload_forecast') && ~isempty(param.Pload_forecast)
    Pload_ctrl = param.Pload_forecast;
else
    Pload_ctrl = Pload;
end
if isfield(param, 'Psource_max_forecast') && ~isempty(param.Psource_max_forecast)
    Psource_max_ctrl = param.Psource_max_forecast;
else
    Psource_max_ctrl = Psource_max;
end
if isfield(param, 'grid_forecast') && ~isempty(param.grid_forecast)
    grid_ctrl = param.grid_forecast;
else
    grid_ctrl = grid_status;
end

% Garante comprimento
Pload_ctrl = alinhamento_vetor(Pload_ctrl, N);
Psource_max_ctrl = alinhamento_vetor(Psource_max_ctrl, N);
grid_ctrl = alinhamento_vetor(grid_ctrl, N);

SOC = zeros(1,N);
PBESS = zeros(1,N);
PBESS_ref = zeros(1,N);
Psource = zeros(1,N);
Pnao_atendida = zeros(1,N);
tempos_qp = nan(1,N);
exitflags = nan(1,N);
modos_evento = false(1,N);
fallback_causa = strings(1, N);

SOC(1) = param.SOC_ref;
PBESS(1) = 0;
PBESS_ref(1) = 0;

contador_qp_ok = 0;
contador_fallback = 0;
fallback_por_causa = containers.Map('KeyType', 'char', 'ValueType', 'double');
hess_cond = NaN;

t_wall = tic;

% Evita herdar warm-start / options de cenário anterior (persistents).
if strcmp(tipo_controle, 'mpc_qp_v5')
    clear_mpc_qp_v5_cache();
elseif strcmp(tipo_controle, 'mpc_qp_fpga')
    clear_mpc_qp_fpga_cache();
end

for k = 1:N-1

    switch tipo_controle

        case 'heuristico'
            PBESS_ref(k) = controle_heuristico( ...
                Pload(k), Psource_max(k), grid_status(k), SOC(k), param);

        case 'heuristico_foresight'
            if k == 1
                PBESS_ref_anterior = 0;
            else
                PBESS_ref_anterior = PBESS_ref(k-1);
            end
            PBESS_ref(k) = controle_heuristico_foresight( ...
                k, SOC(k), PBESS_ref_anterior, ...
                Pload_ctrl, Psource_max_ctrl, grid_ctrl, param);

        case 'miope_qp'
            if k == 1
                PBESS_ref_anterior = 0;
                Psource_anterior = Pload(k);
            else
                PBESS_ref_anterior = PBESS_ref(k-1);
                Psource_anterior = Psource(k-1);
            end
            [PBESS_ref(k), info] = controle_miope_qp( ...
                SOC(k), PBESS(k), PBESS_ref_anterior, Psource_anterior, ...
                Pload_ctrl(k), Psource_max_ctrl(k), grid_ctrl(k), param);
            exitflags(k) = info.exitflag;
            if isfield(info, 'tempo_qp_s')
                tempos_qp(k) = info.tempo_qp_s;
            end
            if info.usou_fallback
                contador_fallback = contador_fallback + 1;
                causa = 'desconhecida';
                if isfield(info, 'fallback_causa') && ~isempty(info.fallback_causa)
                    causa = char(info.fallback_causa);
                end
                fallback_causa(k) = string(causa);
                fallback_por_causa = incrementar_mapa(fallback_por_causa, causa);
            else
                contador_qp_ok = contador_qp_ok + 1;
            end

        case 'mpc_qp_v4'
            if k == 1
                PBESS_ref_anterior = 0;
                Psource_anterior = Pload(k);
            else
                PBESS_ref_anterior = PBESS_ref(k-1);
                Psource_anterior = Psource(k-1);
            end
            [PBESS_ref(k), info] = controle_mpc_qp_v4( ...
                k, SOC(k), PBESS(k), PBESS_ref_anterior, Psource_anterior, ...
                Pload_ctrl, Psource_max_ctrl, grid_ctrl, param);
            exitflags(k) = info.exitflag;
            if info.usou_fallback
                contador_fallback = contador_fallback + 1;
            else
                contador_qp_ok = contador_qp_ok + 1;
            end

        case {'mpc_qp_v5', 'mpc_qp_fpga'}
            if k == 1
                PBESS_ref_anterior = 0;
                Psource_anterior = Pload(k);
            else
                PBESS_ref_anterior = PBESS_ref(k-1);
                Psource_anterior = Psource(k-1);
            end
            if strcmp(tipo_controle, 'mpc_qp_fpga')
                [PBESS_ref(k), info] = controle_mpc_qp_fpga( ...
                    k, SOC(k), PBESS(k), PBESS_ref_anterior, Psource_anterior, ...
                    Pload_ctrl, Psource_max_ctrl, grid_ctrl, param);
            else
                [PBESS_ref(k), info] = controle_mpc_qp_v5( ...
                    k, SOC(k), PBESS(k), PBESS_ref_anterior, Psource_anterior, ...
                    Pload_ctrl, Psource_max_ctrl, grid_ctrl, param);
            end
            exitflags(k) = info.exitflag;
            if isfield(info, 'tempo_qp_s')
                tempos_qp(k) = info.tempo_qp_s;
            end
            if isfield(info, 'modo_evento')
                modos_evento(k) = info.modo_evento;
            end
            if k == 1 && isfield(info, 'hess_cond')
                hess_cond = info.hess_cond;
            end
            if info.usou_fallback
                contador_fallback = contador_fallback + 1;
                causa = 'desconhecida';
                if isfield(info, 'fallback_causa') && ~isempty(info.fallback_causa)
                    causa = char(info.fallback_causa);
                end
                fallback_causa(k) = string(causa);
                fallback_por_causa = incrementar_mapa(fallback_por_causa, causa);
            else
                contador_qp_ok = contador_qp_ok + 1;
            end
    end

    [SOC(k+1), PBESS(k+1), Psource(k), Pnao_atendida(k)] = planta_bess( ...
        SOC(k), PBESS(k), PBESS_ref(k), ...
        Pload(k), Psource_max(k), grid_status(k), param);

    % Progresso MPC: localiza se crash nativo ocorre no 1º QP ou mid-loop.
    if (strcmp(tipo_controle, 'mpc_qp_v5') || strcmp(tipo_controle, 'mpc_qp_fpga')) && (k == 1 || mod(k, 100) == 0)
        tqp_k = NaN;
        if ~isnan(tempos_qp(k)), tqp_k = tempos_qp(k); end
        fprintf('  [mpc] k=%d/%d exit=%g tqp=%.3fs FB=%d SOC=%.2f wall=%.1fs\n', ...
            k, N-1, exitflags(k), tqp_k, contador_fallback, SOC(k+1), toc(t_wall));
        drawnow;
    end

end

PBESS_ref(N) = PBESS_ref(N-1);
if grid_status(N) == 1
    Psource(N) = min(Pload(N) - PBESS(N), Psource_max(N));
else
    Psource(N) = 0;
end
Psource(N) = max(Psource(N), 0);
Pnao_atendida(N) = max(0, Pload(N) - Psource(N) - PBESS(N));

tempo_wall_s = toc(t_wall);

metricas = calcula_metricas( ...
    t, Pload, Psource, PBESS, SOC, Psource_max, Pnao_atendida, param, ...
    'grid_status', grid_status, 'PBESS_ref', PBESS_ref);

out = struct();
out.tipo_controle = tipo_controle;
out.nome_controle = nome_controle;
out.tipo_cenario = tipo_cenario;
out.nome_cenario = char(nome_cenario);
out.param = param;
out.t = t;
out.Pload = Pload;
out.Psource_max = Psource_max;
out.grid_status = grid_status;
out.Pload_ctrl = Pload_ctrl;
out.Psource_max_ctrl = Psource_max_ctrl;
out.grid_ctrl = grid_ctrl;
out.PBESS_ref = PBESS_ref;
out.PBESS = PBESS;
out.Psource = Psource;
out.SOC = SOC;
out.Pnao_atendida = Pnao_atendida;
out.metricas = metricas;
out.contador_qp_ok = contador_qp_ok;
out.contador_fallback = contador_fallback;
out.percentual_fallback = 100 * contador_fallback / max(1, N-1);
out.fallback_causa = fallback_causa;
out.fallback_por_causa = fallback_por_causa;
out.tempos_qp = tempos_qp;
out.exitflags = exitflags;
out.modos_evento = modos_evento;
out.hess_cond = hess_cond;
out.tempo_wall_s = tempo_wall_s;

qp_valid = tempos_qp(~isnan(tempos_qp));
if isempty(qp_valid)
    out.tempo_qp_medio_s = NaN;
    out.tempo_qp_max_s = NaN;
    out.tempo_qp_p50_s = NaN;
    out.tempo_qp_p95_s = NaN;
else
    out.tempo_qp_medio_s = mean(qp_valid);
    out.tempo_qp_max_s = max(qp_valid);
    out.tempo_qp_p50_s = median(qp_valid);
    out.tempo_qp_p95_s = prctile(qp_valid, 95);
end

end

function v = alinhamento_vetor(v, N)
v = v(:)';
if numel(v) < N
    v = [v; v(end) * ones(N - numel(v), 1)];
elseif numel(v) > N
    v = v(1:N);
end
v = v';
end

function m = incrementar_mapa(m, chave)
if m.isKey(chave)
    m(chave) = m(chave) + 1;
else
    m(chave) = 1;
end
end
