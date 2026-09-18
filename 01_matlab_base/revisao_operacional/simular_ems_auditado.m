function out=simular_ems_auditado(ctrl,c,p)
% Interval k: measurements at k -> command -> PB(k+1), balance and SOC(k+1).
% Only N-1 physical intervals are integrated; endpoint is not an extra second.
L=c.L(:)'; M=c.M(:)'; G=c.G(:)'; n=numel(L)-1; t=(0:n)*p.Ts;
assert(n>=1 && numel(M)==n+1 && numel(G)==n+1);
lf=L; mf=M; gf=G;
if isfield(c,'Lf'), lf=c.Lf(:)'; end
if isfield(c,'Mf'), mf=c.Mf(:)'; end
if isfield(c,'Gf'), gf=c.Gf(:)'; end
assert(numel(lf)==n+1 && numel(mf)==n+1 && numel(gf)==n+1);
delay=0; if isfield(c,'detection_delay'), delay=c.detection_delay; end
soc=zeros(1,n+1); pb=soc; u=zeros(1,n); pg=u; pun=u; cycle=u; planttime=u;
soc(1)=p.SOC_ref; if isfield(p,'SOC_initial'), soc(1)=p.SOC_initial; end
blank=struct('exitflag',NaN,'usou_fallback',false,'tempo_qp_s',NaN, ...
 'assembly_s',NaN,'iterations',NaN,'hess_cond',NaN,'constraint_cond',NaN, ...
 'ineq_residual',NaN,'eq_residual',NaN,'soc_error_pp',NaN,'soc_sign_mismatch',0, ...
 'soc_pred_violation',NaN,'nvar',0,'slack_source_max',NaN,'fallback_causa','');
diag=repmat(blank,1,n); tw=tic;
for k=1:n
    tk=tic; up=0; gp=L(1); if k>1, up=u(k-1); gp=pg(k-1); end
    % Pass only the common nominal forecast horizon, never the full truth.
    ix=k:min(k+p.Np_mpc-1,n+1); lh=lf(ix); mh=mf(ix); gh=gf(ix);
    km=max(1,k-round(delay/p.Ts));
    lh(1)=L(km); mh(1)=M(km); gh(1)=G(km);
    if ~p.mpc_foresight_load, lh(2:end)=lh(1); end
    if ~p.mpc_foresight_grid, gh(2:end)=gh(1); mh(2:end)=mh(1); end
    pp=p; pp.diagnose_condition=(k==1);
    d=blank;
    switch ctrl
        case 'heuristico'
            u(k)=controle_heuristico(lh(1),mh(1),gh(1),soc(k),p);
        case 'heuristico_foresight'
            u(k)=controle_heuristico_foresight(1,soc(k),up,lh,mh,gh,p);
        case 'miope_qp'
            [u(k),di]=controle_miope_auditado(soc(k),pb(k),up,gp,lh(1),mh(1),gh(1),p);
            d=take_fields(d,di);
        case 'mpc_qp_v5'
            [u(k),di]=controle_mpc_auditado(soc(k),pb(k),up,gp,lh,mh,gh,pp,false);
            d=take_fields(d,di);
        case 'mpc_qp_estocastico_3cen'
            [u(k),di]=controle_mpc_qp_estocastico_3cen(soc(k),pb(k),up,gp,lh,mh,gh,pp);
            d=take_fields(d,di);
        otherwise, error('Unknown controller %s',ctrl);
    end
    % Optional common supervisory slew policy; emergency bypass is explicit.
    if isfield(p,'common_slew') && p.common_slew && G(k)~=0
        u(k)=min(max(u(k),up-p.dPBESS_ref_max),up+p.dPBESS_ref_max);
    end
    tp=tic;
    [soc(k+1),pb(k+1),pg(k),pun(k)]=planta_bess(soc(k),pb(k),u(k),L(k),M(k),G(k),p);
    planttime(k)=toc(tp); diag(k)=d; cycle(k)=toc(tk);
end
out=struct('ctrl',ctrl,'case',c,'param',p,'t',t,'SOC',soc,'PBESS',pb, ...
 'u',u,'Psource',pg,'Pnao',pun,'diagnostics',diag,'cycle_s',cycle, ...
 'plant_s',planttime,'wall_s',toc(tw));
out.metrics=metricas_auditadas(out);
end
function a=take_fields(a,b)
names=fieldnames(a); for j=1:numel(names), if isfield(b,names{j}), a.(names{j})=b.(names{j}); end; end
end
