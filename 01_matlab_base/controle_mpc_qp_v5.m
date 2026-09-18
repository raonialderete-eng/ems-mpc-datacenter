function [PBESS_ref, info_mpc] = controle_mpc_qp_v5( ...
    k, ...
    SOC_atual, ...
    PBESS_atual, ...
    PBESS_ref_anterior, ...
    Psource_anterior, ...
    Pload, ...
    Psource_max, ...
    grid_status, ...
    param)
% CONTROLE_MPC_QP_V5
% MPC-QP determinístico para gerenciamento energético de BESS/UPS
% em data center, com antecipação de eventos.
%
% Evolução em relação à V4:
%
% 1. Mantém Δu, Pgrid, slacks de carga/fonte/recarga.
% 2. Adiciona slack Sevent e restrição suave de suporte mínimo:
%       PBESS_pred + Sevent >= PBESS_min_event
% 3. Detecta no horizonte:
%       - perda da fonte (grid = 0)
%       - alta demanda (Pload > Psource_max)
% 4. Prepara o BESS antes do evento (janela Nprep).
% 5. Alinha Psource_ref com a preparação (evita conflito com tracking).
% 6. Relaxa dUmax em modo evento.
% 7. Aceleração numérica:
%    - restrições de desigualdade pré-alocadas (sem concatenação);
%    - options do quadprog em persistent;
%    - warm-start com solução do passo anterior.
%
% Convenção:
%   PBESS_ref > 0  -> BESS descarrega
%   PBESS_ref < 0  -> BESS carrega
%   PBESS_ref = 0  -> BESS parado
%
% Variável de decisão:
%   z = [ΔU ; Pgrid ; Sload ; Ssource ; Srecharge ; Sevent]
%
% Preditor de SOC (alinhado à planta, sem variáveis extras):
%   ganhos Kd (descarga) e Kc (carga) aplicados por linearização
%   sucessiva em torno da resposta livre PBESS_livre (sinal por passo).
%   Isso evita o mismatch 1/eta^2 da carga do preditor de ganho único.

%% ================================================================
%  0. Diagnóstico
% ================================================================

info_mpc = struct();

info_mpc.exitflag = NaN;
info_mpc.custo = NaN;
info_mpc.usou_fallback = false;
info_mpc.mensagem = '';
info_mpc.modo_evento = false;
info_mpc.evento_visto = false;
info_mpc.evento_confirmado = false;
info_mpc.i_evento = NaN;
info_mpc.hess_cond = NaN;

info_mpc.delta_u_seq = [];
info_mpc.Pgrid_pred = [];
info_mpc.PBESS_pred = [];
info_mpc.SOC_pred = [];
info_mpc.u_pred = [];
info_mpc.slack_load_seq = [];
info_mpc.slack_source_seq = [];
info_mpc.slack_recharge_seq = [];
info_mpc.slack_event_seq = [];
info_mpc.Psource_ref = [];
info_mpc.Psource_min_recharge = [];
info_mpc.PBESS_min_event = [];
info_mpc.tempo_qp_s = NaN;
info_mpc.foresight_grid = true;
info_mpc.foresight_load = true;
info_mpc.fallback_causa = '';

%% ================================================================
%  1. Configurações do MPC
% ================================================================

N_total = length(Pload);

if isfield(param, 'Np_mpc')
    Np = param.Np_mpc;
else
    Np = 60;
end

if isfield(param, 'Nc_mpc')
    Nc = param.Nc_mpc;
else
    Nc = 15;
end

Np = min(Np, N_total - k + 1);
Nc = min(Nc, Np);

if Np < 1 || Nc < 1
    PBESS_ref = 0;
    info_mpc.mensagem = 'Horizonte insuficiente.';
    return;
end

if isfield(param, 'dPBESS_ref_max')
    dUmax_normal = param.dPBESS_ref_max;
else
    dUmax_normal = 120;
end

if isfield(param, 'dPBESS_ref_max_evento')
    dUmax_evento = param.dPBESS_ref_max_evento;
else
    dUmax_evento = 400;
end

if isfield(param, 'Nprep_evento_mpc')
    Nprep = param.Nprep_evento_mpc;
else
    Nprep = 30;
end

%% ================================================================
%  2. Pesos da função objetivo
% ================================================================

if isfield(param, 'w_mpc_source_tracking')
    w_source_tracking = param.w_mpc_source_tracking;
else
    w_source_tracking = 3000;
end

if isfield(param, 'w_mpc_slack_load')
    w_slack_load = param.w_mpc_slack_load;
else
    w_slack_load = 1e9;
end

if isfield(param, 'w_mpc_slack_source')
    w_slack_source = param.w_mpc_slack_source;
else
    w_slack_source = 1e8;
end

if isfield(param, 'w_mpc_slack_recharge')
    w_slack_recharge = param.w_mpc_slack_recharge;
else
    w_slack_recharge = 1e6;
end

if isfield(param, 'w_mpc_slack_event')
    w_slack_event = param.w_mpc_slack_event;
else
    w_slack_event = 1e9;
end

if isfield(param, 'w_mpc_rampa')
    w_rampa = param.w_mpc_rampa;
else
    w_rampa = 300;
end

if isfield(param, 'w_mpc_soc')
    w_soc = param.w_mpc_soc;
else
    w_soc = 1200;
end

if isfield(param, 'w_mpc_soc_terminal')
    w_soc_terminal = param.w_mpc_soc_terminal;
else
    w_soc_terminal = 12000;
end

if isfield(param, 'w_mpc_uso_bess')
    w_uso_bess = param.w_mpc_uso_bess;
else
    w_uso_bess = 20;
end

if isfield(param, 'w_mpc_delta_u')
    w_delta_u = param.w_mpc_delta_u;
else
    w_delta_u = 50;
end

%% ================================================================
%  3. Normalização
% ================================================================

Pbase = max([ ...
    max(abs(Pload)), ...
    max(abs(Psource_max)), ...
    abs(param.PBESS_max), ...
    abs(param.PBESS_min), ...
    1]);

if isfield(param, 'Rsource_max')
    Rbase = max(param.Rsource_max, 1);
else
    Rbase = 100;
end

SOC_ref = param.SOC_ref;

%% ================================================================
%  4. Vetores futuros conhecidos (com/sem foresight)
% ================================================================

idx_fim = k + Np - 1;

L = Pload(k:idx_fim)';
Pmax = Psource_max(k:idx_fim)';
grid = grid_status(k:idx_fim)';

% Foresight: se false, o MPC NÃO vê contingências futuras no horizonte.
% Mantém apenas o instante atual (i=1) como medido; o futuro assume
% operação "normal" (rede disponível / carga congelada no valor atual).
if isfield(param, 'mpc_foresight_grid')
    foresight_grid = logical(param.mpc_foresight_grid);
else
    foresight_grid = true;
end

if isfield(param, 'mpc_foresight_load')
    foresight_load = logical(param.mpc_foresight_load);
else
    foresight_load = true;
end

info_mpc.foresight_grid = foresight_grid;
info_mpc.foresight_load = foresight_load;

if ~foresight_grid && Np >= 2
    grid(2:end) = 1;
    if isfield(param, 'Psource_max_nominal')
        Pmax(2:end) = param.Psource_max_nominal;
    else
        Pmax(2:end) = Pmax(1);
    end
    % Se a rede já caiu no instante atual, isso permanece visível em grid(1).
end

if ~foresight_load && Np >= 2
    L(2:end) = L(1);
end

%% ================================================================
%  5. Detecção de eventos e suporte mínimo do BESS
% ================================================================

PBESS_min_event = zeros(Np,1);
target_evento = zeros(Np,1);

for i = 1:Np
    if grid(i) == 0
        target_evento(i) = min(L(i), param.PBESS_max);
    elseif L(i) > Pmax(i)
        target_evento(i) = min(max(L(i) - Pmax(i), 0), param.PBESS_max);
    else
        target_evento(i) = 0;
    end
end

i_evento = find(target_evento > 0, 1, 'first');
modo_evento_visto = ~isempty(i_evento);

N_arm = inf;
if isfield(param, 'event_arm_horizon') && ~isempty(param.event_arm_horizon)
    N_arm = param.event_arm_horizon;
end
N_hold = 1;
if isfield(param, 'event_min_duration') && ~isempty(param.event_min_duration)
    N_hold = param.event_min_duration;
end

dur_evento = 0;
if modo_evento_visto
    for ii = i_evento:Np
        if target_evento(ii) > 0
            dur_evento = dur_evento + 1;
        else
            break;
        end
    end
end

evento_ja_ocorreu = (target_evento(1) > 0);
arm_ok = modo_evento_visto;
if modo_evento_visto && ~evento_ja_ocorreu
    if isfinite(N_arm) && i_evento > N_arm
        arm_ok = false;
    end
    if dur_evento < N_hold
        arm_ok = false;
    end
end

modo_evento = arm_ok;
info_mpc.modo_evento = modo_evento;
info_mpc.evento_visto = modo_evento_visto;
info_mpc.evento_confirmado = modo_evento;
if modo_evento_visto
    info_mpc.i_evento = i_evento;
else
    info_mpc.i_evento = NaN;
end

if modo_evento

    target_prep = target_evento(i_evento);

    for i = 1:Np

        if i >= i_evento
            % Durante/após o início do evento: suporte exigido no instante
            PBESS_min_event(i) = target_evento(i);
        else
            dist = i_evento - i;   % passos até o evento

            if dist <= Nprep
                % Rampa de preparação: quanto mais perto, maior o suporte
                alpha = (Nprep - dist + 1) / Nprep;
                PBESS_min_event(i) = alpha * target_prep;
            else
                PBESS_min_event(i) = 0;
            end
        end

    end

end

% Limite de variação do comando
if modo_evento
    dUmax = dUmax_evento;
else
    dUmax = dUmax_normal;
end
dUmin = -dUmax;

% Em modo evento, reduz penalidades que competem com a preparação
if modo_evento
    w_uso_bess = 0.1 * w_uso_bess;
    w_delta_u  = 0.1 * w_delta_u;
    w_rampa    = 0.25 * w_rampa;
end

%% ================================================================
%  6. Variável de decisão
% ================================================================
%
% z = [ΔU ; Pgrid ; Sload ; Ssource ; Srecharge ; Sevent]

n_du = Nc;
n_pgrid = Np;
n_slack_load = Np;
n_slack_source = Np;
n_slack_recharge = Np;
n_slack_event = Np;

idx_du = 1:n_du;
idx_pgrid = n_du + (1:n_pgrid);
idx_slack_load = n_du + n_pgrid + (1:n_slack_load);
idx_slack_source = n_du + n_pgrid + n_slack_load + (1:n_slack_source);
idx_slack_recharge = n_du + n_pgrid + n_slack_load + n_slack_source + (1:n_slack_recharge);
idx_slack_event = n_du + n_pgrid + n_slack_load + n_slack_source + n_slack_recharge + (1:n_slack_event);

nvar = n_du + n_pgrid + n_slack_load + n_slack_source + n_slack_recharge + n_slack_event;

%% ================================================================
%  7. Reconstrução de u = PBESS_ref a partir de Δu
% ================================================================

Tdu = zeros(Np, Nc);

for i = 1:Np
    for j = 1:Nc
        if j <= i
            Tdu(i,j) = 1;
        end
    end
end

u_livre = PBESS_ref_anterior * ones(Np,1);

u_mat = zeros(Np, nvar);
u_mat(:, idx_du) = Tdu;

%% ================================================================
%  8. Modelo preditivo da potência real do BESS
% ================================================================

a = param.ab;
b = param.bb;

Su = zeros(Np, Np);

for i = 1:Np
    for j = 1:i
        Su(i,j) = b * a^(i-j);
    end
end

Sx = zeros(Np,1);

for i = 1:Np
    Sx(i) = a^i;
end

PBESS_livre = Sx * PBESS_atual + Su * u_livre;

PBESS_mat = zeros(Np, nvar);
PBESS_mat(:, idx_du) = Su * Tdu;

%% ================================================================
%  9. Modelo preditivo do SOC (Kd/Kc por linearização na resposta livre)
% ================================================================

if isfield(param, 'eta_descarga')
    eta_d = param.eta_descarga;
elseif isfield(param, 'eta_mpc')
    eta_d = param.eta_mpc;
else
    eta_d = 0.95;
end

if isfield(param, 'eta_carga')
    eta_c = param.eta_carga;
elseif isfield(param, 'eta_mpc')
    eta_c = param.eta_mpc;
else
    eta_c = 0.95;
end

K0 = (param.Ts / 3600) / param.Ebat * 100;
Kd = K0 / eta_d;
Kc = K0 * eta_c;

% Ganho por passo conforme sinal da trajetória livre (descarga/carga)
Kstep = Kd * ones(Np, 1);
Kstep(PBESS_livre < 0) = Kc;

Acum = tril(ones(Np));
SOC_livre = SOC_atual - Acum * (Kstep .* PBESS_livre);
SOC_mat = -Acum * diag(Kstep) * PBESS_mat;

%% ================================================================
%  10. Matrizes das variáveis auxiliares
% ================================================================

Pgrid_mat = zeros(Np, nvar);
Sload_mat = zeros(Np, nvar);
Ssource_mat = zeros(Np, nvar);
Srecharge_mat = zeros(Np, nvar);
Sevent_mat = zeros(Np, nvar);

for i = 1:Np
    Pgrid_mat(i, idx_pgrid(i)) = 1;
    Sload_mat(i, idx_slack_load(i)) = 1;
    Ssource_mat(i, idx_slack_source(i)) = 1;
    Srecharge_mat(i, idx_slack_recharge(i)) = 1;
    Sevent_mat(i, idx_slack_event(i)) = 1;
end

%% ================================================================
%  11. Lógica supervisória de recarga e referência da fonte
% ================================================================

if isfield(param, 'P_recarga_mpc_max')
    P_recarga_mpc_max = param.P_recarga_mpc_max;
else
    P_recarga_mpc_max = 50;
end

if isfield(param, 'banda_SOC_mpc')
    banda_SOC_mpc = param.banda_SOC_mpc;
else
    banda_SOC_mpc = 0.3;
end

P_recarga_req = zeros(Np,1);
Psource_ref = zeros(Np,1);
Psource_min_recharge = zeros(Np,1);

% Em modo evento: sem recarga; tracking alinhado à preparação do BESS
existe_evento_no_horizonte = modo_evento;

for i = 1:Np

    if grid(i) == 0

        Psource_ref(i) = 0;
        P_recarga_req(i) = 0;
        Psource_min_recharge(i) = 0;

    elseif PBESS_min_event(i) > 0

        % Preparação / suporte: fonte cobre o residual
        Psource_ref(i) = max(0, L(i) - PBESS_min_event(i));
        P_recarga_req(i) = 0;
        Psource_min_recharge(i) = 0;

    elseif L(i) > Pmax(i)

        Psource_ref(i) = Pmax(i);
        P_recarga_req(i) = 0;
        Psource_min_recharge(i) = 0;

    else

        Psource_ref(i) = L(i);

        folga_fonte = Pmax(i) - L(i);

        if SOC_atual < (SOC_ref - banda_SOC_mpc) && folga_fonte > 0 && ~existe_evento_no_horizonte

            P_recarga_req(i) = min([ ...
                folga_fonte, ...
                P_recarga_mpc_max, ...
                abs(param.PBESS_min)]);

            Psource_ref(i) = L(i) + P_recarga_req(i);
            Psource_min_recharge(i) = L(i) + P_recarga_req(i);

        else

            P_recarga_req(i) = 0;
            Psource_min_recharge(i) = 0;

        end

    end

end

%% ================================================================
%  12. Função objetivo
% ================================================================

H = zeros(nvar,nvar);
f = zeros(nvar,1);

%% 12.1 Rastreamento da potência da fonte

A = Pgrid_mat / Pbase;
b0 = -Psource_ref / Pbase;

H = H + 2*w_source_tracking*(A'*A);
f = f + 2*w_source_tracking*(A'*b0);

%% 12.2 Slack de carga não atendida

A = Sload_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_load*(A'*A);
f = f + 2*w_slack_load*(A'*b0);

%% 12.3 Slack de violação da fonte

A = Ssource_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_source*(A'*A);
f = f + 2*w_slack_source*(A'*b0);

%% 12.4 Slack da recarga

A = Srecharge_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_recharge*(A'*A);
f = f + 2*w_slack_recharge*(A'*b0);

%% 12.5 Slack de evento / preparação

A = Sevent_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_event*(A'*A);
f = f + 2*w_slack_event*(A'*b0);

%% 12.6 Rampa da fonte

Dramp = zeros(Np,nvar);
bramp = zeros(Np,1);

for i = 1:Np

    if i == 1
        Dramp(i,:) = Pgrid_mat(i,:);
        bramp(i) = -Psource_anterior;
    else
        Dramp(i,:) = Pgrid_mat(i,:) - Pgrid_mat(i-1,:);
        bramp(i) = 0;
    end

end

A = Dramp / Rbase;
b0 = bramp / Rbase;

H = H + 2*w_rampa*(A'*A);
f = f + 2*w_rampa*(A'*b0);

%% 12.7 Desvio de SOC ao longo do horizonte

A = SOC_mat / 100;
b0 = (SOC_livre - SOC_ref) / 100;

H = H + 2*w_soc*(A'*A);
f = f + 2*w_soc*(A'*b0);

%% 12.8 Termo terminal de SOC

A = SOC_mat(end,:) / 100;
b0 = (SOC_livre(end) - SOC_ref) / 100;

H = H + 2*w_soc_terminal*(A'*A);
f = f + 2*w_soc_terminal*(A'*b0);

%% 12.9 Uso do BESS

A = PBESS_mat / Pbase;
b0 = PBESS_livre / Pbase;

H = H + 2*w_uso_bess*(A'*A);
f = f + 2*w_uso_bess*(A'*b0);

%% 12.10 Variação do comando Δu

A = zeros(Nc,nvar);
A(:, idx_du) = eye(Nc);

b0 = zeros(Nc,1);

H = H + 2*w_delta_u*(A'*A);
f = f + 2*w_delta_u*(A'*b0);

%% 12.11 Regularização numérica (reforçada em sparse antes do quadprog)

H = (H + H')/2;

%% ================================================================
%  13. Restrições de igualdade
% ================================================================
%
%   Pgrid + PBESS + Sload = Pload

Aeq = zeros(Np,nvar);
beq = zeros(Np,1);

for i = 1:Np
    Aeq(i,:) = Pgrid_mat(i,:) + PBESS_mat(i,:) + Sload_mat(i,:);
    beq(i) = L(i) - PBESS_livre(i);
end

%% ================================================================
%  14. Restrições de desigualdade (pré-alocadas)
% ================================================================
%
% Evita Aineq = [Aineq; linha], que realoca a matriz a cada inserção.

if isfield(param, 'SOC_margem_mpc')
    margem_soc = param.SOC_margem_mpc;
else
    margem_soc = 0;
end

SOC_min_mpc = param.SOC_min + margem_soc;
SOC_max_mpc = param.SOC_max - margem_soc;

idx_recarga = find(Psource_min_recharge > 0);
idx_event   = find(PBESS_min_event > 0);

n_recarga = numel(idx_recarga);
n_event   = numel(idx_event);
n_ineq    = 7*Np + n_recarga + n_event;

Aineq = zeros(n_ineq, nvar);
bineq = zeros(n_ineq, 1);
row = 0;

%% 14.1 Limites da referência do BESS (2*Np)

% u_pred <= PBESS_max
Aineq(row+(1:Np), :) = u_mat;
bineq(row+(1:Np))    = param.PBESS_max - u_livre;
row = row + Np;

% u_pred >= 0 (sem rede) ou >= PBESS_min (com rede)
u_min_local = param.PBESS_min * ones(Np,1);
u_min_local(grid == 0) = 0;

Aineq(row+(1:Np), :) = -u_mat;
bineq(row+(1:Np))    = u_livre - u_min_local;
row = row + Np;

%% 14.2 Limites da potência real do BESS (2*Np)

Aineq(row+(1:Np), :) = PBESS_mat;
bineq(row+(1:Np))    = param.PBESS_max - PBESS_livre;
row = row + Np;

Aineq(row+(1:Np), :) = -PBESS_mat;
bineq(row+(1:Np))    = PBESS_livre - param.PBESS_min;
row = row + Np;

%% 14.3 Restrições de SOC (2*Np)

Aineq(row+(1:Np), :) = SOC_mat;
bineq(row+(1:Np))    = SOC_max_mpc - SOC_livre;
row = row + Np;

Aineq(row+(1:Np), :) = -SOC_mat;
bineq(row+(1:Np))    = SOC_livre - SOC_min_mpc;
row = row + Np;

%% 14.4 Limite da fonte com slack (Np)
% Pgrid - Ssource <= Psource_max

Aineq(row+(1:Np), :) = Pgrid_mat - Ssource_mat;
bineq(row+(1:Np))    = Pmax;
row = row + Np;

%% 14.5 Restrição suave de recarga
% Pgrid + Srecharge >= Psource_min_recharge

for ii = 1:n_recarga
    i = idx_recarga(ii);
    row = row + 1;
    Aineq(row, :) = -Pgrid_mat(i,:) - Srecharge_mat(i,:);
    bineq(row)    = -Psource_min_recharge(i);
end

%% 14.6 Restrição suave de suporte mínimo para eventos
% PBESS_pred + Sevent >= PBESS_min_event

for ii = 1:n_event
    i = idx_event(ii);
    row = row + 1;
    Aineq(row, :) = -PBESS_mat(i,:) - Sevent_mat(i,:);
    bineq(row)    = PBESS_livre(i) - PBESS_min_event(i);
end

% Segurança: número de linhas preenchidas deve bater com n_ineq
if row ~= n_ineq
    error('controle_mpc_qp_v5: contagem de restrições inconsistente (%d vs %d).', row, n_ineq);
end

%% ================================================================
%  15. Limites inferiores e superiores das variáveis
% ================================================================

lb = -inf(nvar,1);
ub = inf(nvar,1);

%% 15.1 Limites de Δu

lb(idx_du) = dUmin;
ub(idx_du) = dUmax;

%% 15.2 Limites de Pgrid

for i = 1:Np

    if grid(i) == 0
        lb(idx_pgrid(i)) = 0;
        ub(idx_pgrid(i)) = 0;
    else
        lb(idx_pgrid(i)) = 0;
        ub(idx_pgrid(i)) = inf;
    end

end

%% 15.3 Limites dos slacks

lb(idx_slack_load) = 0;
lb(idx_slack_source) = 0;
lb(idx_slack_recharge) = 0;
lb(idx_slack_event) = 0;

for i = 1:Np

    if grid(i) == 0
        ub(idx_slack_source(i)) = 0;
        ub(idx_slack_recharge(i)) = 0;
    end

    if Psource_min_recharge(i) == 0
        ub(idx_slack_recharge(i)) = 0;
    end

    if PBESS_min_event(i) == 0
        ub(idx_slack_event(i)) = 0;
    end

end

%% ================================================================
%  16. Resolver QP (opções cacheadas + warm-start)
% ================================================================

persistent qp_options z_warm

if isempty(qp_options)
    % Tolerâncias práticas para EMS supervisório (Applied): prioriza
    % throughput de solução sem alterar a política do controlador.
    % MaxIterations 150: falha→fallback mais cedo evita loops longos no IPM.
    qp_options = optimoptions('quadprog', ...
        'Display', 'off', ...
        'Algorithm', 'interior-point-convex', ...
        'MaxIterations', 150, ...
        'ConstraintTolerance', 1e-5, ...
        'OptimalityTolerance', 1e-5, ...
        'StepTolerance', 1e-8);
end

% Warm-start: reutiliza a solução do passo anterior (mesma dimensão).
% Para ΔU, aplica deslocamento temporal [du2; ...; duNc; duNc].
% Em k==1 reinicia, para não herdar solução de outro cenário.
if k == 1
    z_warm = [];
end

x0 = [];
if ~isempty(z_warm) && isequal(size(z_warm), [nvar, 1])
    x0 = z_warm;
    if Nc >= 2
        du = x0(idx_du);
        x0(idx_du) = [du(2:end); du(end)];
    end
    % Garante chute dentro dos bounds atuais
    x0 = min(max(x0, lb), ub);
end

% Sparse + regularização: reduz pico de memória nativa do IPM e melhora
% condicionamento com pesos grandes (slacks 1e8–1e9).
H = sparse((H + H')/2);
H = H + speye(nvar) * 1e-6;
Aineq = sparse(Aineq);
Aeq = sparse(Aeq);
f = full(f(:));
bineq = full(bineq(:));
beq = full(beq(:));
lb = full(lb(:));
ub = full(ub(:));
if ~isempty(x0)
    x0 = full(x0(:));
end

t_qp = tic;
[z_otimo, custo, exitflag] = quadprog( ...
    H, ...
    f, ...
    Aineq, ...
    bineq, ...
    Aeq, ...
    beq, ...
    lb, ...
    ub, ...
    x0, ...
    qp_options);
info_mpc.tempo_qp_s = toc(t_qp);

info_mpc.exitflag = exitflag;
info_mpc.custo = custo;

if k == 1 || (isfield(param, 'report_hess_cond') && param.report_hess_cond)
    try
        info_mpc.hess_cond = condest(H);
    catch
        info_mpc.hess_cond = NaN;
    end
end

if exitflag > 0 && ~isempty(z_otimo)
    z_warm = z_otimo;
elseif isempty(z_warm) || ~isequal(size(z_warm), [nvar, 1])
    z_warm = [];
end

%% ================================================================
%  17. Aplicar primeira ação ou fallback
% ================================================================

emergencia_rede = (grid_status(k) == 0);
preparando_evento = (PBESS_min_event(1) > 0);

if exitflag <= 0 || isempty(z_otimo)

    info_mpc.usou_fallback = true;
    info_mpc.fallback_causa = classificar_exitflag_qp(exitflag);
    info_mpc.mensagem = sprintf('quadprog falhou (%s); controle de fallback usado.', ...
        info_mpc.fallback_causa);

    if emergencia_rede == true

        PBESS_ref = min(Pload(k), param.PBESS_max);
        PBESS_ref = max(PBESS_ref, 0);

    elseif preparando_evento == true

        % Fallback de preparação: sobe o BESS em direção ao suporte mínimo
        PBESS_ref = min(PBESS_min_event(1), param.PBESS_max);
        PBESS_ref = max(PBESS_ref, 0);
        PBESS_ref = min(PBESS_ref, PBESS_ref_anterior + dUmax);
        PBESS_ref = max(PBESS_ref, PBESS_ref_anterior + dUmin);

    else

        PBESS_ref_fb = controle_heuristico( ...
            Pload(k), ...
            Psource_max(k), ...
            grid_status(k), ...
            SOC_atual, ...
            param);

        PBESS_ref = min(PBESS_ref_fb, PBESS_ref_anterior + dUmax);
        PBESS_ref = max(PBESS_ref,    PBESS_ref_anterior + dUmin);

    end

else

    info_mpc.usou_fallback = false;
    info_mpc.fallback_causa = '';
    info_mpc.mensagem = 'quadprog OK.';

    delta_u_otimo = z_otimo(idx_du(1));
    PBESS_ref = PBESS_ref_anterior + delta_u_otimo;

end

%% ================================================================
%  18. Proteções finais
% ================================================================

if SOC_atual <= param.SOC_min && PBESS_ref > 0
    PBESS_ref = 0;
end

if SOC_atual >= param.SOC_max && PBESS_ref < 0
    PBESS_ref = 0;
end

if grid_status(k) == 0 && PBESS_ref < 0
    PBESS_ref = 0;
end

PBESS_ref = min(PBESS_ref, param.PBESS_max);
PBESS_ref = max(PBESS_ref, param.PBESS_min);

% Em emergência / preparação, permite dUmax do modo atual (já relaxado).
% Só aplica o clip se ainda não foi aplicado no fallback de emergência "hard".
if ~(grid_status(k) == 0 && info_mpc.usou_fallback == true)

    PBESS_ref = min(PBESS_ref, PBESS_ref_anterior + dUmax);
    PBESS_ref = max(PBESS_ref, PBESS_ref_anterior + dUmin);

end

%% ================================================================
%  19. Diagnóstico adicional
% ================================================================

if exist('z_otimo', 'var') && ~isempty(z_otimo)

    u_pred = u_livre + u_mat*z_otimo;
    PBESS_pred = PBESS_livre + PBESS_mat*z_otimo;
    SOC_pred = SOC_livre + SOC_mat*z_otimo;
    Pgrid_pred = Pgrid_mat*z_otimo;

    info_mpc.delta_u_seq = z_otimo(idx_du);
    info_mpc.Pgrid_pred = Pgrid_pred;
    info_mpc.PBESS_pred = PBESS_pred;
    info_mpc.SOC_pred = SOC_pred;
    info_mpc.u_pred = u_pred;
    info_mpc.slack_load_seq = z_otimo(idx_slack_load);
    info_mpc.slack_source_seq = z_otimo(idx_slack_source);
    info_mpc.slack_recharge_seq = z_otimo(idx_slack_recharge);
    info_mpc.slack_event_seq = z_otimo(idx_slack_event);
    info_mpc.Psource_ref = Psource_ref;
    info_mpc.Psource_min_recharge = Psource_min_recharge;
    info_mpc.PBESS_min_event = PBESS_min_event;

end

end
