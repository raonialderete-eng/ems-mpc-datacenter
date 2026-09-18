function [PBESS_ref, info_mpc] = controle_mpc_qp_v2( ...
    k, ...
    SOC_atual, ...
    PBESS_atual, ...
    PBESS_ref_anterior, ...
    Psource_anterior, ...
    Pload, ...
    Psource_max, ...
    grid_status, ...
    param)
% CONTROLE_MPC_QP_V2
% Controlador MPC determinístico via programação quadrática para EMS de
% data center com BESS/UPS.
%
% Esta versão usa uma formulação mais clássica de MPC:
%
%   Variável manipulada:
%       u(k) = PBESS_ref(k)
%
%   Variável otimizada:
%       Δu(k) = u(k) - u(k-1)
%
% O controlador otimiza a sequência futura:
%
%   ΔU = [Δu(k), Δu(k+1), ..., Δu(k+Nc-1)]'
%
% e aplica apenas o primeiro comando:
%
%   PBESS_ref(k) = PBESS_ref_anterior + Δu(k)
%
% Além disso, inclui:
%   - restrições de amplitude de u;
%   - restrições de taxa Δu;
%   - restrições de SOC;
%   - restrições de potência do BESS;
%   - slack de potência não atendida;
%   - slack de violação da fonte;
%   - termo terminal de SOC;
%   - fallback heurístico se quadprog falhar.
%
% Convenção de sinais:
%   PBESS_ref > 0  -> BESS descarrega, fornecendo potência à carga
%   PBESS_ref < 0  -> BESS carrega, absorvendo potência da fonte
%   PBESS_ref = 0  -> BESS parado
%
% Entradas:
%   k                   -> instante atual da simulação
%   SOC_atual           -> SOC atual [%]
%   PBESS_atual         -> potência real atual do BESS [kW]
%   PBESS_ref_anterior  -> referência aplicada no passo anterior [kW]
%   Psource_anterior    -> potência anterior da fonte [kW]
%   Pload               -> vetor completo da carga [kW]
%   Psource_max         -> vetor completo do limite da fonte [kW]
%   grid_status         -> vetor completo do status da rede/fonte
%   param               -> estrutura de parâmetros
%
% Saídas:
%   PBESS_ref           -> referência calculada para o BESS [kW]
%   info_mpc            -> estrutura auxiliar para diagnóstico

%% ================================================================
%  0. Inicialização da estrutura de diagnóstico
% ================================================================

info_mpc = struct();
info_mpc.exitflag = NaN;
info_mpc.custo = NaN;
info_mpc.usou_fallback = false;
info_mpc.mensagem = '';

%% ================================================================
%  1. Configurações principais do MPC
% ================================================================

N_total = length(Pload);

% Horizonte de predição
if isfield(param, 'Np_mpc')
    Np = param.Np_mpc;
else
    Np = 60;     % 60 passos. Com Ts = 1 s, olha 60 s à frente.
end

% Horizonte de controle
if isfield(param, 'Nc_mpc')
    Nc = param.Nc_mpc;
else
    Nc = 15;     % otimiza 15 movimentos futuros de Δu
end

% Ajuste caso esteja próximo do fim da simulação
Np = min(Np, N_total - k + 1);
Nc = min(Nc, Np);

if Np < 1 || Nc < 1
    PBESS_ref = 0;
    info_mpc.mensagem = 'Horizonte insuficiente.';
    return;
end

% Limite de variação da referência do BESS por passo
% Unidade: kW por amostra
if isfield(param, 'dPBESS_ref_max')
    dUmax = param.dPBESS_ref_max;
else
    dUmax = 100;   % kW/amostra
end

dUmin = -dUmax;

%% ================================================================
%  2. Pesos da função objetivo
% ================================================================
% Estes pesos serão ajustados depois pelos resultados.
% A escala foi escolhida para trabalhar com variáveis normalizadas.

if isfield(param, 'w_mpc_slack_load')
    w_slack_load = param.w_mpc_slack_load;
else
    w_slack_load = 1e6;    % potência não atendida deve ser muito penalizada
end

if isfield(param, 'w_mpc_slack_source')
    w_slack_source = param.w_mpc_slack_source;
else
    w_slack_source = 1e7;  % violar a fonte deve ser ainda mais penalizado
end

if isfield(param, 'w_mpc_rampa')
    w_rampa = param.w_mpc_rampa;
else
    w_rampa = 300;
end

if isfield(param, 'w_mpc_soc')
    w_soc = param.w_mpc_soc;
else
    w_soc = 300;
end

if isfield(param, 'w_mpc_soc_terminal')
    w_soc_terminal = param.w_mpc_soc_terminal;
else
    w_soc_terminal = 2000;
end

if isfield(param, 'w_mpc_uso_bess')
    w_uso_bess = param.w_mpc_uso_bess;
else
    w_uso_bess = 5;
end

if isfield(param, 'w_mpc_delta_u')
    w_delta_u = param.w_mpc_delta_u;
else
    w_delta_u = 50;
end

%% ================================================================
%  3. Bases de normalização
% ================================================================
% A normalização evita que termos em kW dominem numericamente os termos
% em porcentagem de SOC.

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

L = Pload(k:idx_fim)';          % carga prevista [kW]
Pmax = Psource_max(k:idx_fim)'; % limite previsto da fonte [kW]
grid = grid_status(k:idx_fim)'; % status previsto da fonte

%% ================================================================
%  5. Variável de decisão do QP
% ================================================================
%
% z = [ ΔU ; Sload ; Ssource ]
%
% ΔU     -> Nc x 1
% Sload  -> Np x 1  slack de potência não atendida
% Ssource-> Np x 1  slack de violação da fonte
%
% Dimensão total:
% nvar = Nc + Np + Np

n_du = Nc;
n_slack_load = Np;
n_slack_source = Np;

idx_du = 1:n_du;
idx_slack_load = n_du + (1:n_slack_load);
idx_slack_source = n_du + n_slack_load + (1:n_slack_source);

nvar = n_du + n_slack_load + n_slack_source;

%% ================================================================
%  6. Reconstrução de u a partir de Δu
% ================================================================
%
% u(i) = PBESS_ref_anterior + soma dos Δu até o instante i.
%
% Para i > Nc, assume-se Δu = 0.
% Então u fica constante após o horizonte de controle.

Tdu = zeros(Np, Nc);

for i = 1:Np
    for j = 1:Nc
        if j <= i
            Tdu(i,j) = 1;
        end
    end
end

u_livre = PBESS_ref_anterior * ones(Np,1);
u_mat_du = Tdu;

% Matriz completa de u em relação a z
u_mat = zeros(Np, nvar);
u_mat(:, idx_du) = u_mat_du;

% u_pred = u_livre + u_mat*z

%% ================================================================
%  7. Modelo preditivo da potência real do BESS
% ================================================================
%
% Modelo da planta:
%
% PBESS(k+1) = a*PBESS(k) + b*PBESS_ref(k)
%
% Para o horizonte:
%
% PBESS_pred = PBESS_livre + PBESS_mat*z

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
PBESS_mat_du = Su * u_mat_du;

PBESS_mat = zeros(Np, nvar);
PBESS_mat(:, idx_du) = PBESS_mat_du;

% PBESS_pred = PBESS_livre + PBESS_mat*z

%% ================================================================
%  8. Modelo preditivo do SOC
% ================================================================
%
% Modelo aproximado linear para manter o problema como QP.
%
% PBESS > 0 descarrega e reduz SOC.
% PBESS < 0 carrega e aumenta SOC.
%
% A planta real continua usando a eficiência de carga/descarga no arquivo
% planta_bess.m. Aqui usamos uma eficiência média para a predição.

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
%  9. Modelo preditivo da potência da fonte
% ================================================================
%
% Quando a fonte está disponível:
%
%   Psource = Pload - PBESS
%
% Quando a fonte está indisponível:
%
%   Psource = 0
%
% No QP, a indisponibilidade da fonte é conhecida pelo vetor grid.

Psource_livre = L - PBESS_livre;
Psource_mat = -PBESS_mat;

for i = 1:Np
    if grid(i) == 0
        Psource_livre(i) = 0;
        Psource_mat(i,:) = 0;
    end
end

% Psource_pred = Psource_livre + Psource_mat*z

%% ================================================================
%  10. Matrizes auxiliares para slacks
% ================================================================

Sload_mat = zeros(Np, nvar);
Ssource_mat = zeros(Np, nvar);

for i = 1:Np
    Sload_mat(i, idx_slack_load(i)) = 1;
    Ssource_mat(i, idx_slack_source(i)) = 1;
end

%% ================================================================
%  11. Função objetivo quadrática
% ================================================================
%
% quadprog resolve:
%
%   min 0.5*z'*H*z + f'*z
%
% Para um termo:
%
%   w * ||A*z + b||²
%
% adicionamos:
%
%   H = H + 2*w*A'*A
%   f = f + 2*w*A'*b

H = zeros(nvar, nvar);
f = zeros(nvar, 1);

%% 11.1 Penalização de potência não atendida

A = Sload_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_load*(A'*A);
f = f + 2*w_slack_load*(A'*b0);

%% 11.2 Penalização de violação da fonte

A = Ssource_mat / Pbase;
b0 = zeros(Np,1);

H = H + 2*w_slack_source*(A'*A);
f = f + 2*w_slack_source*(A'*b0);

%% 11.3 Penalização da rampa da fonte

Dramp = zeros(Np, nvar);
bramp = zeros(Np,1);

for i = 1:Np

    if i == 1
        Dramp(i,:) = Psource_mat(i,:);
        bramp(i) = Psource_livre(i) - Psource_anterior;
    else
        Dramp(i,:) = Psource_mat(i,:) - Psource_mat(i-1,:);
        bramp(i) = Psource_livre(i) - Psource_livre(i-1);
    end

end

A = Dramp / Rbase;
b0 = bramp / Rbase;

H = H + 2*w_rampa*(A'*A);
f = f + 2*w_rampa*(A'*b0);

%% 11.4 Penalização do desvio de SOC ao longo do horizonte

A = SOC_mat / 100;
b0 = (SOC_livre - SOC_ref) / 100;

H = H + 2*w_soc*(A'*A);
f = f + 2*w_soc*(A'*b0);

%% 11.5 Penalização terminal de SOC

A = SOC_mat(end,:) / 100;
b0 = (SOC_livre(end) - SOC_ref) / 100;

H = H + 2*w_soc_terminal*(A'*A);
f = f + 2*w_soc_terminal*(A'*b0);

%% 11.6 Penalização do uso do BESS

A = PBESS_mat / Pbase;
b0 = PBESS_livre / Pbase;

H = H + 2*w_uso_bess*(A'*A);
f = f + 2*w_uso_bess*(A'*b0);

%% 11.7 Penalização da variação de comando Δu

A = zeros(Nc, nvar);
A(:, idx_du) = eye(Nc);

b0 = zeros(Nc,1);

H = H + 2*w_delta_u*(A'*A);
f = f + 2*w_delta_u*(A'*b0);

%% 11.8 Regularização numérica

H = (H + H')/2;
H = H + 1e-8*eye(nvar);

%% ================================================================
%  12. Restrições de desigualdade
% ================================================================
%
% Forma:
%
%   Aineq*z <= bineq

Aineq = [];
bineq = [];

%% 12.1 Limite de amplitude da referência do BESS
%
% PBESS_min <= u_pred <= PBESS_max
%
% Além disso:
% se grid = 0, não permitimos carga do BESS:
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

%% 12.2 Limite físico da potência real do BESS
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

%% 12.3 Restrições de SOC
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

%% 12.4 Restrição de limite da fonte com slack
%
% Psource_pred <= Psource_max + Ssource
%
% Rearranjo:
% Psource_mat*z - Ssource <= Psource_max - Psource_livre

for i = 1:Np

    if grid(i) == 1

        Aineq = [Aineq; Psource_mat(i,:) - Ssource_mat(i,:)];
        bineq = [bineq; Pmax(i) - Psource_livre(i)];

    end

end

%% 12.5 Restrição para evitar potência negativa da fonte
%
% Psource_pred >= 0
%
% -Psource_pred <= 0

for i = 1:Np

    if grid(i) == 1

        Aineq = [Aineq; -Psource_mat(i,:)];
        bineq = [bineq; Psource_livre(i)];

    end

end

%% 12.6 Restrição de atendimento de carga com slack
%
% Interpretação:
% Se fonte disponível:
%
%   PBESS_pred + Psource_max + Ssource + Sload >= Pload
%
% Se fonte indisponível:
%
%   PBESS_pred + Sload >= Pload
%
% Assim:
%   Sload representa potência não atendida.
%   Ssource representa violação teórica do limite da fonte.
%
% Como w_slack_source é maior que w_slack_load, o MPC tende a preferir
% registrar déficit de carga em cenário fisicamente impossível, em vez de
% "violar" artificialmente a fonte.

for i = 1:Np

    if grid(i) == 1

        % PBESS + Pmax + Ssource + Sload >= L
        %
        % -PBESS - Ssource - Sload <= Pmax - L

        Aineq = [Aineq; ...
            -PBESS_mat(i,:) - Ssource_mat(i,:) - Sload_mat(i,:)];

        bineq = [bineq; ...
            Pmax(i) - L(i) + PBESS_livre(i)];

    else

        % PBESS + Sload >= L
        %
        % -PBESS - Sload <= -L

        Aineq = [Aineq; ...
            -PBESS_mat(i,:) - Sload_mat(i,:)];

        bineq = [bineq; ...
            -L(i) + PBESS_livre(i)];

    end

end

%% ================================================================
%  13. Limites inferiores e superiores das variáveis
% ================================================================

lb = -inf(nvar,1);
ub = inf(nvar,1);

% Limites de Δu
lb(idx_du) = dUmin;
ub(idx_du) = dUmax;

% Slacks sempre não negativos
lb(idx_slack_load) = 0;
lb(idx_slack_source) = 0;

% Durante falha da fonte, não faz sentido permitir slack de violação da fonte,
% pois não existe fonte a ser violada. Fixamos Ssource = 0.
for i = 1:Np
    if grid(i) == 0
        ub(idx_slack_source(i)) = 0;
    end
end

%% ================================================================
%  14. Resolver QP
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
    [], ...
    [], ...
    lb, ...
    ub, ...
    [], ...
    options);

info_mpc.exitflag = exitflag;
info_mpc.custo = custo;

%% ================================================================
%  15. Fallback se o QP falhar
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

    % Mesmo no fallback, respeitamos limite de variação do comando.
    PBESS_ref = min(PBESS_ref_fb, PBESS_ref_anterior + dUmax);
    PBESS_ref = max(PBESS_ref,    PBESS_ref_anterior + dUmin);

else

    info_mpc.mensagem = 'quadprog OK.';

    delta_u_otimo = z_otimo(idx_du(1));

    PBESS_ref = PBESS_ref_anterior + delta_u_otimo;

end

%% ================================================================
%  16. Proteções finais
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

% Saturação física final.
PBESS_ref = min(PBESS_ref, param.PBESS_max);
PBESS_ref = max(PBESS_ref, param.PBESS_min);

% Respeitar taxa de variação final por segurança.
PBESS_ref = min(PBESS_ref, PBESS_ref_anterior + dUmax);
PBESS_ref = max(PBESS_ref, PBESS_ref_anterior + dUmin);

%% ================================================================
%  17. Informações adicionais para diagnóstico
% ================================================================

if exist('z_otimo', 'var') && ~isempty(z_otimo)

    delta_u_seq = z_otimo(idx_du);
    slack_load_seq = z_otimo(idx_slack_load);
    slack_source_seq = z_otimo(idx_slack_source);

    u_pred = u_livre + u_mat*z_otimo;
    PBESS_pred = PBESS_livre + PBESS_mat*z_otimo;
    SOC_pred = SOC_livre + SOC_mat*z_otimo;
    Psource_pred = Psource_livre + Psource_mat*z_otimo;

    info_mpc.delta_u_seq = delta_u_seq;
    info_mpc.slack_load_seq = slack_load_seq;
    info_mpc.slack_source_seq = slack_source_seq;
    info_mpc.u_pred = u_pred;
    info_mpc.PBESS_pred = PBESS_pred;
    info_mpc.SOC_pred = SOC_pred;
    info_mpc.Psource_pred = Psource_pred;

else

    info_mpc.delta_u_seq = [];
    info_mpc.slack_load_seq = [];
    info_mpc.slack_source_seq = [];
    info_mpc.u_pred = [];
    info_mpc.PBESS_pred = [];
    info_mpc.SOC_pred = [];
    info_mpc.Psource_pred = [];

end

end