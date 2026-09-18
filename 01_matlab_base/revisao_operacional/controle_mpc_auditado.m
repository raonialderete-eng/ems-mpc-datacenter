function [u,info] = controle_mpc_auditado(SOC,PB,u0,pg0,L,M,G,p,stochastic)
% Same V5 algebra, common command sequence, scenario-specific auxiliaries.
tall=tic;
if nargin<9, stochastic=false; end
L=L(:)'; M=M(:)'; G=G(:)';
ls={L}; ms={M}; gs={G}; prob=1;
if stochastic
    prob=[1 1 1]/3;
    if isfield(p,'scenario_prob'), prob=p.scenario_prob; end
    assert(numel(prob)==3 && all(prob>0) && abs(sum(prob)-1)<1e-12);
    hi=L; hi(2:end)=1.2*hi(2:end);
    ge=G; me=M;
    % Only already visible announced outages may be shifted. Do not peek
    % beyond the forecast window supplied to every anticipative controller.
    starts=find(diff([1 G])==-1); ends=find(diff([G 1])==1);
    for j=1:numel(starts)
        if starts(j)==1, continue; end % current outage is measured, not shifted
        old=starts(j):ends(j); ge(old)=1; me(old)=p.Psource_max_nominal;
        a=max(2,starts(j)-round(10/p.Ts)); b=max(1,ends(j)-round(10/p.Ts));
        % A terminal zero is right-censored, not an observed restoration.
        % Preserve unavailability through the horizon in that case. Only
        % shift the end when an actual 0->1 transition is visible.
        if ends(j)==numel(G) && G(end)==0, b=numel(G); end
        if b>=a, ge(a:b)=0; me(a:b)=0; end
    end
    ge(1)=G(1); me(1)=M(1);
    ls={L,hi,L}; ms={M,M,me}; gs={G,G,ge};
    if isfield(p,'identical_scenarios') && p.identical_scenarios
        ls={L,L,L}; ms={M,M,M}; gs={G,G,G};
    end
end
nsc=numel(prob); qs=cell(1,nsc);
for s=1:nsc
    qs{s}=montar_qp_auditado(1,SOC,PB,u0,pg0,ls{s},ms{s},gs{s},p);
end
% Collapse duplicate scenarios exactly, summing their probabilities. This
% avoids redundant equalities and preserves the expected objective.
keep=true(1,nsc);
for s=2:nsc
    for j=1:s-1
        if keep(j) && isequal(ls{s},ls{j}) && isequal(ms{s},ms{j}) && isequal(gs{s},gs{j})
            prob(j)=prob(j)+prob(s); keep(s)=false; break;
        end
    end
end
qs=qs(keep); prob=prob(keep); nsc=numel(qs); q=qs{1};
nc=q.Nc; nv=numel(q.f); na=nv-nc; nz=nc+nsc*na;
H=sparse(nz,nz); f=zeros(nz,1); A=sparse(0,nz); B=[]; E=sparse(0,nz); D=[];
lb=-inf(nz,1); ub=inf(nz,1); maps=cell(1,nsc);
for s=1:nsc
    x=qs{s}; ix=[1:nc nc+(s-1)*na+(1:na)]; maps{s}=ix;
    H(ix,ix)=H(ix,ix)+prob(s)*x.H; f(ix)=f(ix)+prob(s)*x.f;
    am=sparse(size(x.Aineq,1),nz); am(:,ix)=x.Aineq;
    em=sparse(size(x.Aeq,1),nz); em(:,ix)=x.Aeq;
    A=[A;am]; B=[B;x.bineq]; E=[E;em]; D=[D;x.beq]; %#ok<AGROW>
    lb(ix)=max(lb(ix),x.lb); ub(ix)=min(ub(ix),x.ub);
end
assembly=toc(tall);
persistent opts
if isempty(opts)
    opts=optimoptions('quadprog','Display','off','Algorithm','interior-point-convex', ...
        'MaxIterations',150,'ConstraintTolerance',1e-5,'OptimalityTolerance',1e-5,'StepTolerance',1e-8);
end
ts=tic;
[z,cost,ef,output]=quadprog(H,f,A,B,E,D,lb,ub,[],opts);
solve=toc(ts);
info=struct('exitflag',ef,'custo',cost,'usou_fallback',ef<=0||isempty(z), ...
    'fallback_causa','','tempo_qp_s',solve,'assembly_s',assembly,'iterations',output.iterations, ...
    'hess_cond',NaN,'constraint_cond',NaN,'ineq_residual',NaN,'eq_residual',NaN, ...
    'soc_error_pp',NaN,'soc_sign_mismatch',0,'soc_pred_violation',NaN, ...
    'nvar',nz,'nsc_unique',nsc,'modo_evento',q.modo_evento,'slack_source_max',NaN);
du=min(cellfun(@(x)x.dUmax,qs));
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
    zn=z(maps{1}); pred=q.PBESS_livre+q.PBESS_mat*zn;
    sp=q.SOC_livre+q.SOC_mat*zn;
    kk=p.Ts/3600/p.Ebat*100*ones(size(pred));
    kk(pred>=0)=kk(pred>=0)/p.eta_descarga; kk(pred<0)=kk(pred<0)*p.eta_carga;
    exact=SOC-cumsum(kk.*pred);
    info.soc_error_pp=max(abs(sp-exact));
    info.soc_sign_mismatch=sum((pred<0)~=(q.PBESS_livre<0));
    info.soc_pred_violation=max([0;exact-p.SOC_max;p.SOC_min-exact]);
    info.slack_source_max=max(zn(q.idx_slack_source));
    info.u_sequence=q.u_livre+q.u_mat*zn;
end
if isfield(p,'diagnose_condition') && p.diagnose_condition
    info.hess_cond=condest(H);
    C=[A;E]; info.constraint_cond=condest(C'*C+speye(nz)*1e-12);
end
info.controller_s=toc(tall);
end
