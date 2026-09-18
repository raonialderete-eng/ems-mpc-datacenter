function [PBESS_ref, info_mpc] = controle_mpc_qp_v4( ...
    k, ...
    SOC_atual, ...
    PBESS_atual, ...
    PBESS_ref_anterior, ...
    Psource_anterior, ...
    Pload, ...
    Psource_max, ...
    grid_status, ...
    param)
% CONTROLE_MPC_QP_V4
% MPC-QP determinístico para gerenciamento energético de BESS/UPS
% em data center.
%
% Melhorias da V4 em relação à V3:
%
% 1. Mantém a variável de decisão em Δu.
% 2. Mantém slacks para carga não atendida e violação de fonte.
% 3. Mantém restrições de SOC, potência e taxa.
% 4. Mantém termo terminal de SOC.
% 5. Adiciona lógica explícita de recarga usando folga da fonte.
%
% A recarga NÃO é imposta como um target fixo de PBESS.
% Ela é formulada como uma restrição operacional suave:
%
%   Se há fonte disponível, folga na fonte e SOC abaixo da referência,
%   então o MPC deve tentar elevar Pgrid para Pload + P_recarga.
%
% Convenção:
%
%   PBESS_ref > 0  -> BESS descarrega
%   PBESS_ref < 0  -> BESS carrega
%   PBESS_ref = 0  -> BESS parado
%
% Variável de decisão:
%
%   z = [ΔU ; Pgrid ; Sload ; Ssource ; Srecharge]
%
% Onde:
%
%   ΔU        -> incrementos futuros da referência do BESS
%   Pgrid     -> potência prevista da fonte
%   Sload     -> slack de potência não atendida
%   Ssource   -> slack de violação do limite da fonte
%   Srecharge -> slack da restrição de recarga

%% ================================================================
%  0. Diagnóstico
% ================================================================

info_mpc = struct();

info_mpc.exitflag = NaN;
info_mpc.custo = NaN;
info_mpc.usou_fallback = false;
info_mpc.mensagem = '';

info_mpc.delta_u_seq = [];
info_mpc.Pgrid_pred = [];
info_mpc.PBESS_pred = [];
info_mpc.SOC_pred = [];
info_mpc.u_pred = [];
info_mpc.slack_load_seq = [];
info_mpc.slack_source_seq = [];
info_mpc.slack_recharge_seq = [];
info_mpc.Psource_ref = [];
info_mpc.Psource_min_recharge = [];

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
    dUmax = param.dPBESS_ref_max;
else
    dUmax = 80;
end

dUmin = -dUmax;

%% ================================================================
%  2. Pesos da função objetivo
% ================================================================

if isfield(param, 'w_mpc_source_tracking')
    w_source_tracking = param.w_mpc_source_tracking;
else
    w_source_tracking = 5000;
end

if isfield(param, 'w_mpc_slack_load')
    w_slack_load = param.w_mpc_slack_load;
else
    w_slack_load = 1e7;
end

if isfield(param, 'w_mpc_slack_source')
    w_slack_source = param.w_mpc_slack_source;
else
    w_slack_source = 1e8;
end

if isfield(param, 'w_mpc_slack_recharge')
    w_slack_recharge = param.w_mpc_slack_recharge;
else
    w_slack_recharge = 5e7;
end

if isfield(param, 'w_mpc_rampa')
    w_rampa = param.w_mpc_rampa;
else
    w_rampa = 1000;
end

if isfield(param, 'w_mpc_soc')
    w_soc = param.w_mpc_soc;
else
    w_soc = 1200;
end

if isfield(param, 'w_mpc_soc_terminal')
    w_soc_terminal = param.w_mpc_soc_terminal;
else
    w_soc_terminal = 10000;
end

if isfield(param, 'w_mpc_uso_bess')
    w_uso_bess = param.w_mpc_uso_bess;
else
    w_uso_bess = 30;
end

if isfield(param, 'w_mpc_delta_u')
    w_delta_u = param.w_mpc_delta_u;
else
    w_delta_u = 200;
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
%  4. Vetores futuros conhecidos
% ================================================================

idx_fim = k + Np - 1;

L = Pload(k:idx_fim)';
Pmax = Psource_max(k:idx_fim)';
grid = grid_status(k:idx_fim)';

%% ================================================================
%  5. Variável de decisão
% ================================================================
%
% z = [ΔU ; Pgrid ; Sload ; Ssource ; Srecharge]

n_du = Nc;
n_pgrid = Np;
n_slack_load = Np;
n_slack_source = Np;
n_slack_recharge = Np;

idx_du = 1:n_du;
idx_pgrid = n_du + (1:n_pgrid);
idx_slack_load = n_du + n_pgrid + (1:n_slack_load);
idx_slack_source = n_du + n_pgrid + n_slack_load + (1:n_slack_source);
idx_slack_recharge = n_du + n_pgrid + n_slack_load + n_slack_source + (1:n_slack_recharge);

nvar = n_du + n_pgrid + n_slack_load + n_slack_source + n_slack_recharge;

%% ================================================================
%  6. Reconstrução de u = PBESS_ref a partir de Δu
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

% u_pred = u_livre + u_mat*z

%% ================================================================
%  7. Modelo preditivo da potência real do BESS
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

% PBESS_pred = PBESS_livre + PBESS_mat*z

%% ================================================================
%  8. Modelo preditivo do SOC
% ================================================================

if isfield(param, 'eta_mpc')
    eta_mpc = param.eta_mpc;
else
    eta_mpc = 0.95;
end

Ksoc = (param.Ts / 3600) / (param.Ebat * eta_mpc) * 100;

Acum = tril(ones(Np));

SOC_livre = SOC_atual - Ksoc * Acum * PBESS_livre;
SOC_mat = -Ksoc * Acum * PBESS_mat;

% SOC_pred = SOC_livre + SOC_mat*z

%% ================================================================
%  9. Matrizes das variáveis auxiliares
% ================================================================

Pgrid_mat = zeros(Np, nvar);
Sload_mat = zeros(Np, nvar);
Ssource_mat = zeros(Np, nvar);
Srecharge_mat = zeros(Np, nvar);

for i = 1:Np
    Pgrid_mat(i, idx_pgrid(i)) = 1;
    Sload_mat(i, idx_slack_load(i)) = 1;
    Ssource_mat(i, idx_slack_source(i)) = 1;
    Srecharge_mat(i, idx_slack_recharge(i)) = 1;
end

%% ================================================================
%  10. Lógica supervisória de recarga com folga da fonte
% ================================================================
%
% P_recarga_req(i) é a potência que gostaríamos de usar para carregar
% o BESS quando houver folga.
%
% Essa potência só existe quando:
%
%   grid = 1
%   Pload < Psource_max
%   SOC_atual < SOC_ref - banda
%
% Caso contrário, P_recarga_req = 0.

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

% Se existe perda de fonte dentro do horizonte de predição,
% o controlador não deve priorizar recarga.
% Isso evita que o BESS esteja carregando próximo de uma contingência.
existe_falha_no_horizonte = any(grid == 0);


for i = 1:Np

    if grid(i) == 0

        Psource_ref(i) = 0;
        P_recarga_req(i) = 0;
        Psource_min_recharge(i) = 0;

    else

        folga_fonte = Pmax(i) - L(i);

        if L(i) > Pmax(i)

            % Carga acima do limite: fonte no limite e BESS cobre diferença.
            Psource_ref(i) = Pmax(i);
            P_recarga_req(i) = 0;
            Psource_min_recharge(i) = 0;

        else

            % Operação normal: fonte atende a carga.
            Psource_ref(i) = L(i);

            % Recarga somente se SOC estiver abaixo da referência.
            if SOC_atual < (SOC_ref - banda_SOC_mpc) && folga_fonte > 0 && ~existe_falha_no_horizonte

                P_recarga_req(i) = min([ ...
                    folga_fonte, ...
                    P_recarga_mpc_max, ...
                    abs(param.PBESS_min)]);

                % Referência desejada da fonte passa a incluir recarga.
                Psource_ref(i) = L(i) + P_recarga_req(i);

                % Restrição suave: fonte deve tentar fornecer pelo menos
                % carga + recarga.
                Psource_min_recharge(i) = L(i) + P_recarga_req(i);

            else

                P_recarga_req(i) = 0;
                Psource_min_recharge(i) = 0;

            end

        end

    end

end

%% ================================================================
%  11. Função objetivo
% ================================================================

H = zeros(nvar,nvar);
f = zeros(nvar,1);

% Forma geral:
% Para w*||A*z + b||²:
% H = H + 2*w*A'*A
% f = f + 2*w*A'*b

%% 11.1 Rastreamento da potência da fonte

A = Pgrid_mat / Pbase;
b0 = -Psource_ref / Pbase;

H = H + 2*w_source_tracking*(A'*A);
f = f + 2*w_source_tracking*(A'*b0);

%% 11.2 Slack de carga não atendida

A = Sload_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_load*(A'*A);
f = f + 2*w_slack_load*(A'*b0);

%% 11.3 Slack de violação da fonte

A = Ssource_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_source*(A'*A);
f = f + 2*w_slack_source*(A'*b0);

%% 11.4 Slack da recarga

% Penaliza não cumprir a recarga quando há folga e SOC baixo.

A = Srecharge_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_recharge*(A'*A);
f = f + 2*w_slack_recharge*(A'*b0);

%% 11.5 Rampa da fonte

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

%% 11.6 Desvio de SOC ao longo do horizonte

A = SOC_mat / 100;
b0 = (SOC_livre - SOC_ref) / 100;

H = H + 2*w_soc*(A'*A);
f = f + 2*w_soc*(A'*b0);

%% 11.7 Termo terminal de SOC

A = SOC_mat(end,:) / 100;
b0 = (SOC_livre(end) - SOC_ref) / 100;

H = H + 2*w_soc_terminal*(A'*A);
f = f + 2*w_soc_terminal*(A'*b0);

%% 11.8 Uso do BESS

A = PBESS_mat / Pbase;
b0 = PBESS_livre / Pbase;

H = H + 2*w_uso_bess*(A'*A);
f = f + 2*w_uso_bess*(A'*b0);

%% 11.9 Variação do comando Δu

A = zeros(Nc,nvar);
A(:, idx_du) = eye(Nc);

b0 = zeros(Nc,1);

H = H + 2*w_delta_u*(A'*A);
f = f + 2*w_delta_u*(A'*b0);

%% 11.10 Regularização numérica

H = (H + H')/2;
H = H + 1e-8*eye(nvar);

%% ================================================================
%  12. Restrições de igualdade
% ================================================================
%
% Balanço de potência:
%
%   Pgrid + PBESS + Sload = Pload
%
% Se PBESS for negativo, ele está carregando.
% Então Pgrid precisa aumentar para suprir carga + recarga.

Aeq = zeros(Np,nvar);
beq = zeros(Np,1);

for i = 1:Np
    Aeq(i,:) = Pgrid_mat(i,:) + PBESS_mat(i,:) + Sload_mat(i,:);
    beq(i) = L(i) - PBESS_livre(i);
end

%% ================================================================
%  13. Restrições de desigualdade
% ================================================================

Aineq = [];
bineq = [];

%% 13.1 Limites da referência do BESS

for i = 1:Np

    % u_pred <= PBESS_max
    Aineq = [Aineq; u_mat(i,:)];
    bineq = [bineq; param.PBESS_max - u_livre(i)];

    if grid(i) == 0

        % Durante falta de rede, não carregar:
        % u_pred >= 0
        Aineq = [Aineq; -u_mat(i,:)];
        bineq = [bineq; u_livre(i)];

    else

        % Com rede disponível:
        % u_pred >= PBESS_min
        Aineq = [Aineq; -u_mat(i,:)];
        bineq = [bineq; u_livre(i) - param.PBESS_min];

    end

end

%% 13.2 Limites da potência real do BESS

for i = 1:Np

    % PBESS_pred <= PBESS_max
    Aineq = [Aineq; PBESS_mat(i,:)];
    bineq = [bineq; param.PBESS_max - PBESS_livre(i)];

    % PBESS_pred >= PBESS_min
    Aineq = [Aineq; -PBESS_mat(i,:)];
    bineq = [bineq; PBESS_livre(i) - param.PBESS_min];

end

%% 13.3 Restrições de SOC

if isfield(param, 'SOC_margem_mpc')
    margem_soc = param.SOC_margem_mpc;
else
    margem_soc = 0;
end

SOC_min_mpc = param.SOC_min + margem_soc;
SOC_max_mpc = param.SOC_max - margem_soc;

for i = 1:Np

    % SOC_pred <= SOC_max_mpc
    Aineq = [Aineq; SOC_mat(i,:)];
    bineq = [bineq; SOC_max_mpc - SOC_livre(i)];

    % SOC_pred >= SOC_min_mpc
    Aineq = [Aineq; -SOC_mat(i,:)];
    bineq = [bineq; SOC_livre(i) - SOC_min_mpc];

end

%% 13.4 Limite da fonte com slack

for i = 1:Np

    % Pgrid <= Psource_max + Ssource
    %
    % Pgrid - Ssource <= Psource_max

    Aineq = [Aineq; Pgrid_mat(i,:) - Ssource_mat(i,:)];
    bineq = [bineq; Pmax(i)];

end

%% 13.5 Restrição suave de recarga com folga da fonte
%
% Quando Psource_min_recharge > 0:
%
%   Pgrid + Srecharge >= Psource_min_recharge
%
% Rearranjo:
%
%   -Pgrid - Srecharge <= -Psource_min_recharge
%
% Se não for fisicamente possível atender imediatamente, Srecharge absorve
% a diferença, mas é fortemente penalizado.

for i = 1:Np

    if Psource_min_recharge(i) > 0

        Aineq = [Aineq; -Pgrid_mat(i,:) - Srecharge_mat(i,:)];
        bineq = [bineq; -Psource_min_recharge(i)];

    end

end

%% ================================================================
%  14. Limites inferiores e superiores das variáveis
% ================================================================

lb = -inf(nvar,1);
ub = inf(nvar,1);

%% 14.1 Limites de Δu

lb(idx_du) = dUmin;
ub(idx_du) = dUmax;

%% 14.2 Limites de Pgrid

for i = 1:Np

    if grid(i) == 0

        % Rede indisponível: Pgrid = 0.
        lb(idx_pgrid(i)) = 0;
        ub(idx_pgrid(i)) = 0;

    else

        % Rede disponível: Pgrid >= 0.
        lb(idx_pgrid(i)) = 0;
        ub(idx_pgrid(i)) = inf;

    end

end

%% 14.3 Limites dos slacks

lb(idx_slack_load) = 0;
lb(idx_slack_source) = 0;
lb(idx_slack_recharge) = 0;

for i = 1:Np

    if grid(i) == 0
        % Sem rede, não existe violação de fonte nem recarga.
        ub(idx_slack_source(i)) = 0;
        ub(idx_slack_recharge(i)) = 0;
    end

    if Psource_min_recharge(i) == 0
        % Quando não há solicitação de recarga, fixa o slack de recarga em zero.
        ub(idx_slack_recharge(i)) = 0;
    end

end

%% ================================================================
%  15. Resolver QP
% ================================================================

options = optimoptions('quadprog', ...
    'Display', 'off', ...
    'Algorithm', 'interior-point-convex', ...
    'MaxIterations', 1000, ...
    'ConstraintTolerance', 1e-7, ...
    'OptimalityTolerance', 1e-7, ...
    'StepTolerance', 1e-10);

[z_otimo, custo, exitflag] = quadprog( ...
    H, ...
    f, ...
    Aineq, ...
    bineq, ...
    Aeq, ...
    beq, ...
    lb, ...
    ub, ...
    [], ...
    options);

info_mpc.exitflag = exitflag;
info_mpc.custo = custo;


%% ================================================================
%  16. Aplicar primeira ação ou fallback
% ================================================================

emergencia_rede = (grid_status(k) == 0);

if exitflag <= 0 || isempty(z_otimo)

    info_mpc.usou_fallback = true;
    info_mpc.mensagem = 'quadprog falhou; controle de fallback usado.';

    if emergencia_rede == true

        % Modo emergencial:
        % Se a fonte caiu, a prioridade absoluta é atender a carga crítica.
        % Portanto, comanda-se imediatamente a maior potência possível do BESS.
        PBESS_ref = min(Pload(k), param.PBESS_max);

        % Durante emergência não faz sentido carregar.
        PBESS_ref = max(PBESS_ref, 0);

    else

        % Modo normal:
        % Usa o heurístico, mantendo suavização do comando.
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
    info_mpc.mensagem = 'quadprog OK.';

    delta_u_otimo = z_otimo(idx_du(1));

    PBESS_ref = PBESS_ref_anterior + delta_u_otimo;

end

%% ================================================================
%  17. Proteções finais
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

% Em operação normal, mantém limite de variação.
% Em emergência com fallback, permite comando imediato do BESS.
if ~(grid_status(k) == 0 && info_mpc.usou_fallback == true)

    PBESS_ref = min(PBESS_ref, PBESS_ref_anterior + dUmax);
    PBESS_ref = max(PBESS_ref, PBESS_ref_anterior + dUmin);

end

%% ================================================================
%  18. Diagnóstico adicional
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
    info_mpc.Psource_ref = Psource_ref;
    info_mpc.Psource_min_recharge = Psource_min_recharge;

end

end