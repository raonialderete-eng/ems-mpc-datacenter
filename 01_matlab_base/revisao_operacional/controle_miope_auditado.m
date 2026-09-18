function [PBESS_ref, info] = controle_miope_auditado( ...
    SOC_atual, ...
    PBESS_atual, ...
    PBESS_ref_anterior, ...
    Psource_anterior, ...
    Pload_k, ...
    Psource_max_k, ...
    grid_status_k, ...
    param)
% CONTROLE_MIOPE_QP
% QP de um passo. Preditor SOC com Kd/Kc conforme sinal da resposta livre.

info = struct();
info.exitflag = NaN;
info.custo = NaN;
info.usou_fallback = false;
info.mensagem = '';
info.tempo_qp_s = NaN;
info.fallback_causa = '';

if isfield(param, 'w_mpc_source_tracking'), w_source = param.w_mpc_source_tracking; else, w_source = 3000; end
if isfield(param, 'w_mpc_slack_load'), w_slack_load = param.w_mpc_slack_load; else, w_slack_load = 1e9; end
if isfield(param, 'w_mpc_slack_source'), w_slack_source = param.w_mpc_slack_source; else, w_slack_source = 1e8; end
if isfield(param, 'w_mpc_slack_recharge'), w_slack_recharge = param.w_mpc_slack_recharge; else, w_slack_recharge = 1e6; end
if isfield(param, 'w_mpc_rampa'), w_rampa = param.w_mpc_rampa; else, w_rampa = 300; end
if isfield(param, 'w_mpc_soc'), w_soc = param.w_mpc_soc; else, w_soc = 1200; end
if isfield(param, 'w_mpc_uso_bess'), w_uso = param.w_mpc_uso_bess; else, w_uso = 20; end
if isfield(param, 'w_mpc_delta_u'), w_du = param.w_mpc_delta_u; else, w_du = 50; end
if isfield(param, 'dPBESS_ref_max'), dUmax = param.dPBESS_ref_max; else, dUmax = 120; end
if grid_status_k == 0
    if isfield(param, 'dPBESS_ref_max_evento'), dUmax = param.dPBESS_ref_max_evento; else, dUmax = param.PBESS_max; end
end
dUmin = -dUmax;
if isfield(param, 'P_recarga_mpc_max'), P_recarga_max = param.P_recarga_mpc_max; else, P_recarga_max = 50; end
if isfield(param, 'banda_SOC_mpc'), banda = param.banda_SOC_mpc; else, banda = 0.3; end
if isfield(param, 'eta_descarga'), eta_d = param.eta_descarga; else, eta_d = 0.95; end
if isfield(param, 'eta_carga'), eta_c = param.eta_carga; else, eta_c = 0.95; end

Pbase = max([abs(Pload_k), abs(Psource_max_k), abs(param.PBESS_max), abs(param.PBESS_min), 1]);
if isfield(param, 'Rsource_max'), Rbase = max(param.Rsource_max, 1); else, Rbase = 100; end

if isfield(param, 'Pbase_audit'), Pbase=param.Pbase_audit; end
a = param.ab; b = param.bb;
K0 = (param.Ts / 3600) / param.Ebat * 100;
Kd = K0 / eta_d; Kc = K0 * eta_c;

% Resposta livre com u=0 para escolher ganho; refina com u_ant
PBESS_livre_u0 = a * PBESS_atual;
Ksoc = Kd; if PBESS_livre_u0 < 0, Ksoc = Kc; end
% Com u: PBESS_next = a*PBESS + b*u; usa Ksoc da livre (linearização)
% Se u_ant tipicamente define o regime, ajusta:
PBESS_guess = a * PBESS_atual + b * PBESS_ref_anterior;
if PBESS_guess < 0, Ksoc = Kc; else, Ksoc = Kd; end

idx_u = 1; idx_pg = 2; idx_sl = 3; idx_ss = 4; idx_sr = 5; nvar = 5;

Psource_ref = Pload_k; Psource_min_recharge = 0;
if grid_status_k == 0
    Psource_ref = 0;
elseif Pload_k > Psource_max_k
    Psource_ref = Psource_max_k;
else
    folga = Psource_max_k - Pload_k;
    if SOC_atual < (param.SOC_ref - banda) && folga > 0
        P_recarga_req = min([folga, P_recarga_max, abs(param.PBESS_min)]);
        Psource_ref = Pload_k + P_recarga_req;
        Psource_min_recharge = Psource_ref;
    end
end

H = zeros(nvar); f = zeros(nvar,1);
H(idx_pg, idx_pg) = H(idx_pg, idx_pg) + 2*w_source/(Pbase^2);
f(idx_pg) = f(idx_pg) - 2*w_source*Psource_ref/(Pbase^2);
H(idx_sl, idx_sl) = H(idx_sl, idx_sl) + 2*w_slack_load/(Pbase^2);
H(idx_ss, idx_ss) = H(idx_ss, idx_ss) + 2*w_slack_source/(Pbase^2);
H(idx_sr, idx_sr) = H(idx_sr, idx_sr) + 2*w_slack_recharge/(Pbase^2);
H(idx_pg, idx_pg) = H(idx_pg, idx_pg) + 2*w_rampa/(Rbase^2);
f(idx_pg) = f(idx_pg) - 2*w_rampa*Psource_anterior/(Rbase^2);

c1 = Ksoc * b;
c0 = SOC_atual - Ksoc * a * PBESS_atual;
H(idx_u, idx_u) = H(idx_u, idx_u) + 2*w_soc*(c1^2)/(100^2);
f(idx_u) = f(idx_u) - 2*w_soc*c1*(c0 - param.SOC_ref)/(100^2);
H(idx_u, idx_u) = H(idx_u, idx_u) + 2*w_uso*(b^2)/(Pbase^2);
f(idx_u) = f(idx_u) + 2*w_uso*b*(a*PBESS_atual)/(Pbase^2);
H(idx_u, idx_u) = H(idx_u, idx_u) + 2*w_du/(Pbase^2);
f(idx_u) = f(idx_u) - 2*w_du*PBESS_ref_anterior/(Pbase^2);
H = (H + H')/2 + 1e-8*eye(nvar);

Aeq = zeros(1,nvar); Aeq(idx_u)=b; Aeq(idx_pg)=1; Aeq(idx_sl)=1;
beq = Pload_k - a*PBESS_atual;

Aineq = []; bineq = [];
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_u)=1; bineq=[bineq; param.PBESS_max]; %#ok<*AGROW>
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_u)=-1;
if grid_status_k==0, bineq=[bineq; 0]; else, bineq=[bineq; -param.PBESS_min]; end
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_u)=b; bineq=[bineq; param.PBESS_max - a*PBESS_atual];
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_u)=-b; bineq=[bineq; -param.PBESS_min + a*PBESS_atual];
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_u)=-c1; bineq=[bineq; param.SOC_max - c0];
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_u)=c1; bineq=[bineq; c0 - param.SOC_min];
Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_pg)=1; Aineq(end,idx_ss)=-1; bineq=[bineq; Psource_max_k];
if Psource_min_recharge > 0
    Aineq = [Aineq; zeros(1,nvar)]; Aineq(end,idx_pg)=-1; Aineq(end,idx_sr)=-1; bineq=[bineq; -Psource_min_recharge];
end

lb=-inf(nvar,1); ub=inf(nvar,1);
lb(idx_u)=max(PBESS_ref_anterior+dUmin, param.PBESS_min);
ub(idx_u)=min(PBESS_ref_anterior+dUmax, param.PBESS_max);
if grid_status_k==0
    lb(idx_pg)=0; ub(idx_pg)=0; ub(idx_ss)=0; ub(idx_sr)=0; lb(idx_u)=max(lb(idx_u),0);
else
    lb(idx_pg)=0;
end
lb(idx_sl)=0; lb(idx_ss)=0; lb(idx_sr)=0;
if Psource_min_recharge==0, ub(idx_sr)=0; end

persistent qp_options
if isempty(qp_options)
    qp_options = optimoptions('quadprog','Display','off','Algorithm','interior-point-convex', ...
        'MaxIterations',200,'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-6);
end

t_qp = tic;
[z, custo, exitflag] = quadprog(H, f, Aineq, bineq, Aeq, beq, lb, ub, [], qp_options);
info.tempo_qp_s = toc(t_qp); info.exitflag = exitflag; info.custo = custo;

if exitflag <= 0 || isempty(z)
    info.usou_fallback = true;
    info.fallback_causa = classificar_exitflag_qp(exitflag);
    info.mensagem = sprintf('quadprog falhou (%s); fallback heuristico.', info.fallback_causa);
    PBESS_ref = controle_heuristico(Pload_k, Psource_max_k, grid_status_k, SOC_atual, param);
else
    info.usou_fallback = false; info.fallback_causa = ''; info.mensagem = 'quadprog OK.';
    PBESS_ref = z(idx_u);
end

if SOC_atual <= param.SOC_min && PBESS_ref > 0, PBESS_ref = 0; end
if SOC_atual >= param.SOC_max && PBESS_ref < 0, PBESS_ref = 0; end
if grid_status_k == 0 && PBESS_ref < 0, PBESS_ref = 0; end
PBESS_ref = min(max(PBESS_ref, param.PBESS_min), param.PBESS_max);
PBESS_ref = min(max(PBESS_ref, PBESS_ref_anterior + dUmin), PBESS_ref_anterior + dUmax);
end
