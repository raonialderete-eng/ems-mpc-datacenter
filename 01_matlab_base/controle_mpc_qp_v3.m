function [PBESS_ref, info_mpc] = controle_mpc_qp_v3( ...
    k, ...
    SOC_atual, ...
    PBESS_atual, ...
    PBESS_ref_anterior, ...
    Psource_anterior, ...
    Pload, ...
    Psource_max, ...
    grid_status, ...
    param)
% CONTROLE_MPC_QP_V3
% MPC-QP determinístico para gerenciamento energético de BESS/UPS
% em data center.
%
% Esta versão usa formulação mais adequada para artigo:
%
%   Variável manipulada:
%       u(k) = PBESS_ref(k)
%
%   Variável otimizada:
%       Δu(k) = u(k) - u(k-1)
%
% Além de Δu, o QP também usa variáveis auxiliares:
%
%   Pgrid      -> potência prevista da fonte/rede
%   Sload      -> slack de potência não atendida
%   Ssource    -> slack de violação do limite da fonte
%
% Estrutura da variável de decisão:
%
%   z = [ΔU ; Pgrid ; Sload ; Ssource]
%
% Convenção de sinais:
%
%   PBESS_ref > 0  -> BESS descarrega
%   PBESS_ref < 0  -> BESS carrega
%   PBESS_ref = 0  -> BESS parado
%
% Objetivos principais:
%
%   1. atender a carga crítica sempre que fisicamente possível;
%   2. respeitar limite da fonte;
%   3. suavizar a potência da fonte;
%   4. evitar uso desnecessário do BESS;
%   5. recuperar SOC quando houver folga na fonte;
%   6. preservar factibilidade com slacks em cenários severos.
%
% Entradas:
%   k                   -> instante atual da simulação
%   SOC_atual           -> SOC atual [%]
%   PBESS_atual         -> potência real atual do BESS [kW]
%   PBESS_ref_anterior  -> referência anterior do BESS [kW]
%   Psource_anterior    -> potência anterior da fonte [kW]
%   Pload               -> vetor completo da carga [kW]
%   Psource_max         -> vetor completo do limite da fonte [kW]
%   grid_status         -> vetor completo do status da fonte
%   param               -> estrutura de parâmetros
%
% Saídas:
%   PBESS_ref           -> referência ótima para o BESS [kW]
%   info_mpc            -> estrutura de diagnóstico

%% ================================================================
%  0. Inicialização do diagnóstico
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
info_mpc.Psource_ref = [];

%% ================================================================
%  1. Configurações principais do MPC
% ================================================================

N_total = length(Pload);

% Horizonte de predição
if isfield(param, 'Np_mpc')
    Np = param.Np_mpc;
else
    Np = 60;     % 60 s, assumindo Ts = 1 s
end

% Horizonte de controle
if isfield(param, 'Nc_mpc')
    Nc = param.Nc_mpc;
else
    Nc = 15;     % otimiza 15 incrementos futuros
end

% Ajuste para o fim da simulação
Np = min(Np, N_total - k + 1);
Nc = min(Nc, Np);

if Np < 1 || Nc < 1
    PBESS_ref = 0;
    info_mpc.mensagem = 'Horizonte insuficiente.';
    return;
end

% Limite de variação de referência do BESS por passo
if isfield(param, 'dPBESS_ref_max')
    dUmax = param.dPBESS_ref_max;
else
    dUmax = 100;   % [kW/amostra]
end

dUmin = -dUmax;

%% ================================================================
%  2. Pesos da função objetivo
% ================================================================
% Os pesos estão normalizados por Pbase, Rbase e 100% SOC.
%
% Ajustaremos depois com base nos resultados.

if isfield(param, 'w_mpc_source_tracking')
    w_source_tracking = param.w_mpc_source_tracking;
else
    w_source_tracking = 3000;
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

if isfield(param, 'w_mpc_rampa')
    w_rampa = param.w_mpc_rampa;
else
    w_rampa = 500;
end

if isfield(param, 'w_mpc_soc')
    w_soc = param.w_mpc_soc;
else
    w_soc = 800;
end

if isfield(param, 'w_mpc_soc_terminal')
    w_soc_terminal = param.w_mpc_soc_terminal;
else
    w_soc_terminal = 5000;
end

if isfield(param, 'w_mpc_uso_bess')
    w_uso_bess = param.w_mpc_uso_bess;
else
    w_uso_bess = 20;
end

if isfield(param, 'w_mpc_delta_u')
    w_delta_u = param.w_mpc_delta_u;
else
    w_delta_u = 100;
end

%% ================================================================
%  3. Bases de normalização
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

L = Pload(k:idx_fim)';             % carga prevista [kW]
Pmax = Psource_max(k:idx_fim)';    % limite previsto da fonte [kW]
grid = grid_status(k:idx_fim)';    % status previsto da fonte

%% ================================================================
%  5. Definição da variável de decisão
% ================================================================
%
% z = [ ΔU ; Pgrid ; Sload ; Ssource ]
%
% ΔU      -> Nc x 1
% Pgrid   -> Np x 1
% Sload   -> Np x 1
% Ssource -> Np x 1

n_du = Nc;
n_pgrid = Np;
n_slack_load = Np;
n_slack_source = Np;

idx_du = 1:n_du;
idx_pgrid = n_du + (1:n_pgrid);
idx_slack_load = n_du + n_pgrid + (1:n_slack_load);
idx_slack_source = n_du + n_pgrid + n_slack_load + (1:n_slack_source);

nvar = n_du + n_pgrid + n_slack_load + n_slack_source;

%% ================================================================
%  6. Reconstrução de u = PBESS_ref a partir de Δu
% ================================================================
%
% u(i) = PBESS_ref_anterior + soma dos Δu até o instante i.
%
% Para i > Nc, assume-se Δu = 0.
% Então u permanece constante após o horizonte de controle.

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
%
% Planta:
%
%   PBESS(k+1) = a*PBESS(k) + b*PBESS_ref(k)
%
% Predição:
%
%   PBESS_pred = PBESS_livre + PBESS_mat*z

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
%
% Modelo linear aproximado para manter o QP.
%
% PBESS > 0  -> descarga -> SOC diminui
% PBESS < 0  -> carga    -> SOC aumenta

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
%  9. Matrizes das variáveis Pgrid, Sload e Ssource
% ================================================================

Pgrid_mat = zeros(Np, nvar);
Sload_mat = zeros(Np, nvar);
Ssource_mat = zeros(Np, nvar);

for i = 1:Np
    Pgrid_mat(i, idx_pgrid(i)) = 1;
    Sload_mat(i, idx_slack_load(i)) = 1;
    Ssource_mat(i, idx_slack_source(i)) = 1;
end

%% ================================================================
%  10. Referência desejada para a fonte
% ================================================================
%
% Esta é a principal melhoria em relação à V2.
%
% Regras:
%
% 1. Se a fonte caiu:
%       Psource_ref = 0
%
% 2. Se a fonte está disponível e a carga cabe na fonte:
%       Psource_ref = Pload
%
% 3. Se a fonte está disponível e a carga passa do limite:
%       Psource_ref = Psource_max
%
% 4. Se o SOC está abaixo da referência e existe folga:
%       Psource_ref = Pload + potência de recarga
%       limitado a Psource_max
%
% Com isso, o MPC entende que:
% - não deve usar BESS sem necessidade;
% - deve usar BESS quando a carga ultrapassa a fonte;
% - deve recarregar quando há folga;
% - deve zerar fonte quando grid_status = 0.

if isfield(param, 'P_recarga_mpc_max')
    P_recarga_mpc_max = param.P_recarga_mpc_max;
else
    P_recarga_mpc_max = 150;   % [kW]
end

if isfield(param, 'banda_SOC_mpc')
    banda_SOC_mpc = param.banda_SOC_mpc;
else
    banda_SOC_mpc = 0.5;       % [%]
end

Psource_ref = zeros(Np,1);

for i = 1:Np

    if grid(i) == 0

        % Rede indisponível
        Psource_ref(i) = 0;

    else

        % Fonte disponível
        if L(i) <= Pmax(i)

            % Em condição normal, a fonte deve atender a carga.
            Psource_ref(i) = L(i);

            % Se SOC está abaixo da referência e existe folga, usar parte
            % da folga da fonte para recarregar o BESS.
            folga_fonte = Pmax(i) - L(i);

            if SOC_atual < (SOC_ref - banda_SOC_mpc) && folga_fonte > 0

                P_carga_desejada = min([ ...
                    folga_fonte, ...
                    P_recarga_mpc_max, ...
                    abs(param.PBESS_min)]);

                Psource_ref(i) = min(Pmax(i), L(i) + P_carga_desejada);

            end

        else

            % Carga acima do limite da fonte.
            % A fonte deve operar no limite e o BESS cobre a diferença.
            Psource_ref(i) = Pmax(i);

        end

    end

end

%% ================================================================
%  11. Montagem da função objetivo
% ================================================================
%
% quadprog resolve:
%
%   min 0.5*z'*H*z + f'*z
%
% Para cada termo:
%
%   w * ||A*z + b||²
%
% adicionamos:
%
%   H = H + 2*w*A'*A
%   f = f + 2*w*A'*b

H = zeros(nvar,nvar);
f = zeros(nvar,1);

%% 11.1 Rastreamento da potência da fonte

% Termo:
%   ||Pgrid - Psource_ref||²

A = Pgrid_mat / Pbase;
b0 = -Psource_ref / Pbase;

H = H + 2*w_source_tracking*(A'*A);
f = f + 2*w_source_tracking*(A'*b0);

%% 11.2 Slack de carga não atendida

% Termo:
%   ||Sload||²

A = Sload_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_load*(A'*A);
f = f + 2*w_slack_load*(A'*b0);

%% 11.3 Slack de violação da fonte

% Termo:
%   ||Ssource||²

A = Ssource_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_source*(A'*A);
f = f + 2*w_slack_source*(A'*b0);

%% 11.4 Rampa da fonte

% Termo:
%   ||Pgrid(i) - Pgrid(i-1)||²

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

%% 11.5 Desvio de SOC ao longo do horizonte

A = SOC_mat / 100;
b0 = (SOC_livre - SOC_ref) / 100;

H = H + 2*w_soc*(A'*A);
f = f + 2*w_soc*(A'*b0);

%% 11.6 Termo terminal de SOC

% Penaliza especialmente o SOC no fim do horizonte.
% Isso força o MPC a pensar em reserva de energia, não só no instante atual.

A = SOC_mat(end,:) / 100;
b0 = (SOC_livre(end) - SOC_ref) / 100;

H = H + 2*w_soc_terminal*(A'*A);
f = f + 2*w_soc_terminal*(A'*b0);

%% 11.7 Uso do BESS

% Termo:
%   ||PBESS_pred||²
%
% Evita usar o BESS sem necessidade.

A = PBESS_mat / Pbase;
b0 = PBESS_livre / Pbase;

H = H + 2*w_uso_bess*(A'*A);
f = f + 2*w_uso_bess*(A'*b0);

%% 11.8 Variação do comando Δu

% Termo:
%   ||ΔU||²
%
% Suaviza a referência enviada ao BESS/conversor.

A = zeros(Nc,nvar);
A(:, idx_du) = eye(Nc);

b0 = zeros(Nc,1);

H = H + 2*w_delta_u*(A'*A);
f = f + 2*w_delta_u*(A'*b0);

%% 11.9 Regularização numérica

H = (H + H')/2;
H = H + 1e-8*eye(nvar);

%% ================================================================
%  12. Restrições de igualdade
% ================================================================
%
% Balanço de potência com slack de carga:
%
%   Pgrid + PBESS + Sload = Pload
%
% Se a rede caiu, Pgrid será forçado a zero pelos limites da variável,
% então:
%
%   PBESS + Sload = Pload
%
% Isso torna Sload a potência não atendida prevista.

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

%% 13.1 Limite de amplitude da referência do BESS
%
% PBESS_min <= u_pred <= PBESS_max
%
% Se grid = 0, não permitimos carga:
%
% u_pred >= 0

for i = 1:Np

    % u_pred <= PBESS_max
    Aineq = [Aineq; u_mat(i,:)];
    bineq = [bineq; param.PBESS_max - u_livre(i)];

    if grid(i) == 0

        % u_pred >= 0
        % -u_pred <= 0

        Aineq = [Aineq; -u_mat(i,:)];
        bineq = [bineq; u_livre(i)];

    else

        % u_pred >= PBESS_min
        % -u_pred <= -PBESS_min

        Aineq = [Aineq; -u_mat(i,:)];
        bineq = [bineq; u_livre(i) - param.PBESS_min];

    end

end

%% 13.2 Limite físico da potência real do BESS
%
% PBESS_min <= PBESS_pred <= PBESS_max

for i = 1:Np

    % PBESS_pred <= PBESS_max
    Aineq = [Aineq; PBESS_mat(i,:)];
    bineq = [bineq; param.PBESS_max - PBESS_livre(i)];

    % PBESS_pred >= PBESS_min
    Aineq = [Aineq; -PBESS_mat(i,:)];
    bineq = [bineq; PBESS_livre(i) - param.PBESS_min];

end

%% 13.3 Restrições de SOC
%
% SOC_min_mpc <= SOC_pred <= SOC_max_mpc

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
%
% Pgrid <= Psource_max + Ssource
%
% Rearranjo:
%
% Pgrid - Ssource <= Psource_max

for i = 1:Np

    Aineq = [Aineq; Pgrid_mat(i,:) - Ssource_mat(i,:)];
    bineq = [bineq; Pmax(i)];

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

        % Quando a fonte está indisponível, Pgrid = 0.
        lb(idx_pgrid(i)) = 0;
        ub(idx_pgrid(i)) = 0;

    else

        % Quando a fonte está disponível, Pgrid >= 0.
        lb(idx_pgrid(i)) = 0;
        ub(idx_pgrid(i)) = inf;

    end

end

%% 14.3 Limites dos slacks

lb(idx_slack_load) = 0;
lb(idx_slack_source) = 0;

% Se a fonte caiu, não há "violação de fonte" a contabilizar.
% Nesse caso, Ssource é fixado em zero.
for i = 1:Np
    if grid(i) == 0
        ub(idx_slack_source(i)) = 0;
    end
end

%% ================================================================
%  15. Resolver o QP
% ================================================================

options = optimoptions('quadprog', ...
    'Display', 'off', ...
    'Algorithm', 'interior-point-convex', ...
    'MaxIterations', 200);

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

if exitflag <= 0 || isempty(z_otimo)

    info_mpc.usou_fallback = true;
    info_mpc.mensagem = 'quadprog falhou; controle heuristico usado como fallback.';

    PBESS_ref_fb = controle_heuristico( ...
        Pload(k), ...
        Psource_max(k), ...
        grid_status(k), ...
        SOC_atual, ...
        param);

    % Mesmo no fallback, respeitamos taxa máxima de variação.
    PBESS_ref = min(PBESS_ref_fb, PBESS_ref_anterior + dUmax);
    PBESS_ref = max(PBESS_ref,    PBESS_ref_anterior + dUmin);

else

    info_mpc.usou_fallback = false;
    info_mpc.mensagem = 'quadprog OK.';

    delta_u_otimo = z_otimo(idx_du(1));

    PBESS_ref = PBESS_ref_anterior + delta_u_otimo;

end

%% ================================================================
%  17. Proteções finais
% ================================================================

% Se SOC está no mínimo, não deixa descarregar.
if SOC_atual <= param.SOC_min && PBESS_ref > 0
    PBESS_ref = 0;
end

% Se SOC está no máximo, não deixa carregar.
if SOC_atual >= param.SOC_max && PBESS_ref < 0
    PBESS_ref = 0;
end

% Se a fonte caiu, não deixa carregar.
if grid_status(k) == 0 && PBESS_ref < 0
    PBESS_ref = 0;
end

% Saturação física.
PBESS_ref = min(PBESS_ref, param.PBESS_max);
PBESS_ref = max(PBESS_ref, param.PBESS_min);

% Saturação de taxa.
PBESS_ref = min(PBESS_ref, PBESS_ref_anterior + dUmax);
PBESS_ref = max(PBESS_ref, PBESS_ref_anterior + dUmin);

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
    info_mpc.Psource_ref = Psource_ref;

end

end