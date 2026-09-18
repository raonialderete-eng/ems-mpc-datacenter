function report=testar_revisao(dest)
base=fileparts(fileparts(mfilename('fullpath'))); addpath(base); addpath(fileparts(mfilename('fullpath')));
assert(~isfile(dest),'Refuse to overwrite test report');
p=parametros(); p.Pbase_audit=950; p.diagnose_condition=true;
L=[750*ones(1,20) 950*ones(1,40)]; M=800*ones(size(L)); G=ones(size(L));
[u,a]=controle_mpc_auditado(60,0,0,750,L,M,G,p,false);
pi=p; pi.identical_scenarios=true;
[ui,b]=controle_mpc_auditado(60,0,0,750,L,M,G,pi,true);
assert(abs(u-ui)<1e-5 && a.exitflag>0 && b.exitflag>0);
% Original V5 matches algebra when original and fixed Pbase are both 950.
clear_mpc_qp_v5_cache();
[uv,v]=controle_mpc_qp_v5(1,60,0,0,750,L,M,G,p);
assert(abs(u-uv)<1e-3 && v.exitflag>0);
[us,s]=controle_mpc_auditado(60,0,0,750,L,M,G,p,true);
assert(s.exitflag>0 && s.ineq_residual<1e-3 && s.eq_residual<1e-3);
assert(s.nvar==615); % nominal == early without announced grid loss
% Event and high-load scenarios must produce three distinct QPs.
G(25:45)=0; M=800*G;
[~,se]=controle_mpc_auditado(60,0,0,750,L,M,G,p,true);
assert(se.nvar==915 && se.nsc_unique==3);
% Direct QP prediction and physical one-step update agree when sign agrees.
q=montar_qp_auditado(1,60,0,0,750,L,M,G,p);
z=zeros(numel(q.f),1); z(1)=100;
pred=q.PBESS_livre+q.PBESS_mat*z;
[sn,pn]=planta_bess(60,0,100,L(1),M(1),G(1),p);
assert(abs(pn-pred(1))<1e-12);
assert(abs(sn-(60-pred(1)/.95/500/3600*100))<1e-12);
% No-preview controller cannot use different future truths.
pc=p; pc.Np_mpc=6; pc.Nc_mpc=2; pc.mpc_foresight_load=false; pc.mpc_foresight_grid=false;
c=struct('L',750*ones(1,12),'M',800*ones(1,12),'G',ones(1,12));
d=c; d.L(4:end)=950; d.G(4:end)=0; d.M=800*d.G;
oc=simular_ems_auditado('mpc_qp_v5',c,pc); od=simular_ems_auditado('mpc_qp_v5',d,pc);
assert(max(abs(oc.u(1:3)-od.u(1:3)))<1e-6);
% Current measurement overrides wrong current forecast.
e=c; e.Lf=900*ones(1,12); e.Gf=zeros(1,12); e.Mf=zeros(1,12);
oe=simular_ems_auditado('mpc_qp_v5',e,pc);
assert(max(abs(oc.u-oe.u))<1e-6);
report=struct('passed',true,'deterministic_u',u,'legacy_u',uv,'identical_u',ui, ...
 'stochastic_u',us,'stochastic_event_exitflag',se.exitflag,'matlab',version, ...
 'tests',{{'identical scenarios','V5 algebra equivalence','QP feasibility','scenario dimension','plant indexing','no-preview causality','current measurement override'}});
save(dest,'report'); disp(report);
end
