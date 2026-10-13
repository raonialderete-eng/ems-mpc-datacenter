function [u,info] = controle_mpc_causa(SOC,PB,u0,pg0,L,M,G,p,stochastic)
% Isolated copy of the audited MPC for the -6 diagnostic campaign.
% Production controle_mpc_auditado.m is not modified.
tall=tic;
if nargin<9, stochastic=false; end
L=L(:)'; M=M(:)'; G=G(:)';
ls={L}; ms={M}; gs={G}; prob=1;
if stochastic
    error('causa_fallback: stochastic not in this campaign');
end
qs={montar_qp_auditado(1,SOC,PB,u0,pg0,ls{1},ms{1},gs{1},p)};
q=qs{1};
H=q.H; f=q.f; A=q.Aineq; B=q.bineq; E=q.Aeq; D=q.beq; lb=q.lb; ub=q.ub;
assembly=toc(tall);
opts=optimoptions('quadprog','Display','off','Algorithm','interior-point-convex', ...
    'MaxIterations',150,'ConstraintTolerance',1e-5,'OptimalityTolerance',1e-5,'StepTolerance',1e-8);
alpha=1;
if isfield(p,'solver_objective_scale') && ~isempty(p.solver_objective_scale) && p.solver_objective_scale>0
    alpha=p.solver_objective_scale;
end
ts=tic;
[z,cost,ef,output]=quadprog(alpha*H,alpha*f,A,B,E,D,lb,ub,[],opts);
if alpha~=1 && ~isempty(cost) && isfinite(cost), cost=cost/alpha; end
solve=toc(ts);
iters=NaN; if exist('output','var') && isstruct(output) && isfield(output,'iterations'), iters=output.iterations; end
info=struct('exitflag',ef,'custo',cost,'usou_fallback',ef<=0||isempty(z), ...
    'fallback_causa','','tempo_qp_s',solve,'assembly_s',assembly,'iterations',iters, ...
    'hess_cond',NaN,'constraint_cond',NaN,'ineq_residual',NaN,'eq_residual',NaN, ...
    'soc_error_pp',NaN,'soc_sign_mismatch',0,'soc_pred_violation',NaN, ...
    'nvar',numel(f),'nsc_unique',1,'modo_evento',q.modo_evento,'slack_source_max',NaN, ...
    'recovery','');
du=q.dUmax;
if info.usou_fallback && isfield(p,'qp_recovery') && p.qp_recovery
    [z2,~,ef2]=quadprog(0.001*H,0.001*f,A,B,E,D,lb,ub,[],opts);
    if ef2>0 && ~isempty(z2)
        z=z2; ef=ef2; info.usou_fallback=false; info.recovery='scaled_ipm';
        info.exitflag=ef;
    else
        as=optimoptions('quadprog','Display','off','Algorithm','active-set','MaxIterations',1000, ...
            'OptimalityTolerance',1e-8,'ConstraintTolerance',1e-7,'StepTolerance',1e-12);
        try
            [z3,~,ef3]=quadprog(0.001*H,0.001*f,A,B,E,D,lb,ub,[],as);
        catch
            z3=[]; ef3=-99;
        end
        if ef3>0 && ~isempty(z3)
            z=z3; ef=ef3; info.usou_fallback=false; info.recovery='active_set';
            info.exitflag=ef;
        end
    end
end
if info.usou_fallback
    info.fallback_causa=classificar_exitflag_qp(ef);
    if G(1)==0
        u=max(0,min(L(1),p.PBESS_max));
    elseif q.PBESS_min_event(1)>0
        u=max(0,min(q.PBESS_min_event(1),p.PBESS_max));
        u=min(max(u,u0-du),u0+du);
    else
        u=controle_heuristico(L(1),M(1),G(1),SOC,p);
        u=min(max(u,u0-du),u0+du);
    end
else
    u=u0+z(1);
end
if SOC<=p.SOC_min && u>0, u=0; end
if SOC>=p.SOC_max && u<0, u=0; end
if G(1)==0 && u<0, u=0; end
u=min(max(u,p.PBESS_min),p.PBESS_max);
if ~(G(1)==0 && info.usou_fallback), u=min(max(u,u0-du),u0+du); end
if ~isempty(z) && all(isfinite(z))
    info.ineq_residual=max([0;A*z-B;lb-z;z-ub]);
    info.eq_residual=max(abs(E*z-D));
end
info.controller_s=toc(tall);
end
