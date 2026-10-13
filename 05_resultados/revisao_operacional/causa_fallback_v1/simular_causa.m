function out=simular_causa(c,p)
% Same loop as revisao_operacional/simular_ems_auditado, MPC via controle_mpc_causa.
L=c.L(:)'; M=c.M(:)'; G=c.G(:)'; n=numel(L)-1; t=(0:n)*p.Ts;
lf=L; mf=M; gf=G;
if isfield(c,'Lf'), lf=c.Lf(:)'; end
if isfield(c,'Mf'), mf=c.Mf(:)'; end
if isfield(c,'Gf'), gf=c.Gf(:)'; end
soc=zeros(1,n+1); pb=soc; u=zeros(1,n); pg=u; pun=u; cycle=u;
soc(1)=p.SOC_ref; if isfield(p,'SOC_initial'), soc(1)=p.SOC_initial; end
blank=struct('exitflag',NaN,'usou_fallback',false,'tempo_qp_s',NaN, ...
 'assembly_s',NaN,'iterations',NaN,'hess_cond',NaN,'constraint_cond',NaN, ...
 'ineq_residual',NaN,'eq_residual',NaN,'soc_error_pp',NaN,'soc_sign_mismatch',0, ...
 'soc_pred_violation',NaN,'nvar',0,'slack_source_max',NaN,'fallback_causa','','recovery','');
diag=repmat(blank,1,n); tw=tic;
delay=0; if isfield(c,'detection_delay'), delay=c.detection_delay; end
for k=1:n
    tk=tic; up=0; gp=L(1); if k>1, up=u(k-1); gp=pg(k-1); end
    ix=k:min(k+p.Np_mpc-1,n+1); lh=lf(ix); mh=mf(ix); gh=gf(ix);
    km=max(1,k-round(delay/p.Ts));
    lh(1)=L(km); mh(1)=M(km); gh(1)=G(km);
    if isfield(p,'mpc_foresight_load') && ~p.mpc_foresight_load, lh(2:end)=lh(1); end
    if isfield(p,'mpc_foresight_grid') && ~p.mpc_foresight_grid, gh(2:end)=gh(1); mh(2:end)=mh(1); end
    pp=p; pp.diagnose_condition=false;
    [u(k),di]=controle_mpc_causa(soc(k),pb(k),up,gp,lh,mh,gh,pp,false);
    d=blank;
    fn=fieldnames(d);
    for j=1:numel(fn)
        if isfield(di,fn{j}), d.(fn{j})=di.(fn{j}); end
    end
    [soc(k+1),pb(k+1),pg(k),pun(k)]=planta_bess(soc(k),pb(k),u(k),L(k),M(k),G(k),p);
    diag(k)=d; cycle(k)=toc(tk);
end
out=struct('ctrl','mpc_qp_v5','case',c,'param',p,'t',t,'SOC',soc,'PBESS',pb, ...
 'u',u,'Psource',pg,'Pnao',pun,'diagnostics',diag,'cycle_s',cycle,'wall_s',toc(tw));
out.metrics=metricas_auditadas(out);
end
