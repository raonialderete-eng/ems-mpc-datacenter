function dest=rodar_causa_fallback()
% Diagnostic campaign for V5 exitflag=-6 on j00014/j00019.
% Does not modify production controllers or the official consolidation.
here=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(fileparts(here)));
dest=fullfile(root,'05_resultados','revisao_operacional','causa_fallback_v1');
if isfolder(dest)
    error('causa_fallback_v1 already exists; choose a new folder if rerunning');
end
mkdir(dest);
copyfile(fullfile(here,'CRITERIOS.json'),fullfile(dest,'CRITERIOS.json'));
copyfile(fullfile(here,'controle_mpc_causa.m'),fullfile(dest,'controle_mpc_causa.m'));
copyfile(fullfile(here,'simular_causa.m'),fullfile(dest,'simular_causa.m'));
copyfile(mfilename('fullpath')+".m",fullfile(dest,'experiment_snapshot.m'));

oldpath=path; cleanupPath=onCleanup(@() path(oldpath)); %#ok<NASGU>
addpath(here,'-begin');
addpath(fullfile(root,'01_matlab_base','revisao_operacional'),'-begin');
addpath(fullfile(root,'01_matlab_base'),'-begin');
addpath(here,'-begin');
clear controle_mpc_auditado montar_qp_auditado simular_ems_auditado controle_mpc_causa simular_causa

diary(fullfile(dest,'execution.log'));
cleanupDiary=onCleanup(@() diary('off')); %#ok<NASGU>

prodFiles={ ...
    fullfile(root,'01_matlab_base','revisao_operacional','controle_mpc_auditado.m'), ...
    fullfile(root,'01_matlab_base','revisao_operacional','montar_qp_auditado.m'), ...
    fullfile(root,'01_matlab_base','revisao_operacional','simular_ems_auditado.m'), ...
    fullfile(root,'01_matlab_base','planta_bess.m')};
hashes=struct('file',{},'sha256',{});
for i=1:numel(prodFiles)
    hashes(i).file=prodFiles{i};
    hashes(i).sha256=sha256_file(prodFiles{i});
end

csvFb=fullfile(root,'05_resultados','revisao_operacional','consolidacao_corrigida_20260911_v1','fallback_eventos.csv');
T=readtable(csvFb,'TextType','string');
mask=T.ctrl=="mpc_qp_v5" & (T.id=="j00014" | T.id=="j00019") & T.exitflag==-6;
T=T(mask,:);
assert(height(T)==47,'Expected 47 principal -6 rows, got %d',height(T));
n14=sum(T.id=="j00014"); n19=sum(T.id=="j00019");
assert(n14==19 && n19==28,'Split 19/28 failed: %d/%d',n14,n19);
letter14=[462:473 475:478 481:483];
got14=sort(T.time_s(T.id=="j00014")');
assert(isequal(got14,letter14),'j00014 instants mismatch the letter');

mat14=fullfile(root,'05_resultados','revisao_operacional','campanha_v1','j00014.mat');
mat19=fullfile(root,'05_resultados','revisao_operacional','campanha_v1','j00019.mat');
jobs=struct('id',{},'mat',{},'k',{},'time_s',{},'stratum',{},'exitflag_mat',{});
for i=1:height(T)
    if T.id(i)=="j00014", fn=mat14; else, fn=mat19; end
    jobs(i)=struct('id',char(T.id(i)),'mat',fn,'k',double(T.step_0based(i))+1, ...
        'time_s',double(T.time_s(i)),'stratum','flag_-6','exitflag_mat',-6);
end
extra=struct('id',{'j00014','j00014','j00014','j00014'}, ...
    'mat',{mat14,mat14,mat14,mat14},'k',{1,200,450,490}, ...
    'time_s',{0,199,449,489},'stratum',{'control_k1','control_mid','control_prep','control_after_fb'}, ...
    'exitflag_mat',{NaN,NaN,NaN,NaN});
jobs=[jobs, extra];

fid=fopen(fullfile(dest,'index_passos.json'),'w');
fprintf(fid,'%s',jsonencode(jobs,PrettyPrint=true)); fclose(fid);

opts=optimoptions('quadprog','Display','off','Algorithm','interior-point-convex', ...
    'MaxIterations',150,'ConstraintTolerance',1e-5,'OptimalityTolerance',1e-5,'StepTolerance',1e-8);
asOpts=optimoptions('quadprog','Display','off','Algorithm','active-set','MaxIterations',1000, ...
    'OptimalityTolerance',1e-8,'ConstraintTolerance',1e-7,'StepTolerance',1e-12);
alpha=0.001;
lminTol=-1e-8;

cache=struct();
rows=struct([]);
fprintf('PART A  n=%d QPs\n',numel(jobs));
for i=1:numel(jobs)
    j=jobs(i);
    if ~isfield(cache,j.id)
        d=load(j.mat); cache.(j.id)=d.out;
    end
    o=cache.(j.id);
    k=j.k;
    efMat=o.diagnostics(k).exitflag;
    if strcmp(j.stratum,'flag_-6')
        assert(efMat==-6,'MAT exitflag at k=%d is %g',k,efMat);
    end
    [H,f,A,B,E,D,lb,ub,u0,qinfo]=rebuild_qp(o,k);
    Hs=(H+H')/2;
    symH=full(max(abs(H-H'),[],'all'));
    [~,cholflag]=chol(Hs);
    ev=eig(full(Hs));
    lmin=min(real(ev));
    lneg=sum(real(ev)<lminTol);
    nH=norm(full(Hs),2); nf=norm(f,2);
    cH=NaN;
    try, cH=condest(Hs); catch, try, cH=cond(full(Hs)); catch, end, end

    z0=[]; ef0=NaN; it0=NaN;
    try
        [z0,~,ef0,out0]=quadprog(H,f,A,B,E,D,lb,ub,[],opts);
        if isstruct(out0) && isfield(out0,'iterations'), it0=out0.iterations; end
    catch err
        ef0=-99; warning('IPM official failed: %s',err.message);
    end
    zs=[]; efs=NaN; its=NaN; lam=[];
    try
        [zs,~,efs,outs,lam]=quadprog(alpha*H,alpha*f,A,B,E,D,lb,ub,[],opts);
        if isstruct(outs) && isfield(outs,'iterations'), its=outs.iterations; end
    catch err
        efs=-99; warning('IPM scaled failed: %s',err.message);
    end
    za=[]; efa=NaN; ita=NaN;
    try
        zinit=zs;
        [za,~,efa,outa]=quadprog(alpha*H,alpha*f,A,B,E,D,lb,ub,zinit,asOpts);
        if isstruct(outa) && isfield(outa,'iterations'), ita=outa.iterations; end
    catch err
        efa=-99;
        try
            [za,~,efa,outa]=quadprog(alpha*H,alpha*f,A,B,E,D,lb,ub,[],asOpts);
            if isstruct(outa) && isfield(outa,'iterations'), ita=outa.iterations; end
        catch err2
            warning('active-set failed: %s / %s',err.message,err2.message);
        end
    end

    u_hist=o.u(k);
    u_ipm=NaN; u_sc=NaN; u_as=NaN;
    if ~isempty(z0), u_ipm=u0+z0(1); end
    if ~isempty(zs), u_sc=u0+zs(1); end
    if ~isempty(za), u_as=u0+za(1); end
    u_qp=u_sc; if ~isfinite(u_qp), u_qp=u_as; end
    if ~isfinite(u_qp), u_qp=u_ipm; end

    eq=NaN; ineq=NaN; station=NaN;
    zuse=zs; if isempty(zuse), zuse=za; end
    if ~isempty(zuse)
        eq=max(abs(E*zuse-D));
        ineq=max([0;A*zuse-B;lb-zuse;zuse-ub]);
        if ~isempty(lam) && isstruct(lam)
            st=alpha*(H*zuse+f);
            if isfield(lam,'ineqlin'), st=st+A'*lam.ineqlin; end
            if isfield(lam,'eqlin'), st=st+E'*lam.eqlin; end
            if isfield(lam,'lower'), st=st-lam.lower; end
            if isfield(lam,'upper'), st=st+lam.upper; end
            station=norm(st,inf);
        end
    end

    spd=(cholflag==0) && (lmin>=lminTol);
    label=classify_cause(lmin,lminTol,spd,ef0,efs,efa,j.stratum);

    r=struct('id',j.id,'stratum',j.stratum,'k',k,'time_s',j.time_s, ...
        'exitflag_mat',efMat,'ef0',ef0,'ef_scaled',efs,'ef_activeset',efa, ...
        'chol_flag',cholflag,'lambda_min',lmin,'n_neg_eig',lneg, ...
        'hess_sym_max',symH,'hess_cond',cH,'norm_H',nH,'norm_f',nf, ...
        'nvar',size(H,1),'modo_evento',qinfo.modo_evento, ...
        'u_applied',u_hist,'u_ipm',u_ipm,'u_scaled',u_sc,'u_activeset',u_as, ...
        'u_qp',u_qp,'du_applied_minus_qp',u_hist-u_qp, ...
        'eq_kW',eq,'ineq',ineq,'stationarity',station, ...
        'iter_ipm',it0,'iter_scaled',its,'iter_as',ita,'label',label, ...
        'ef0_matches_mat',double(ef0==efMat));
    if isempty(rows), rows=r; else, rows(end+1)=r; end %#ok<AGROW>
    fprintf('A %d/%d %s t=%g ef0=%g scaled=%g as=%g lmin=%.3g %s\n', ...
        i,numel(jobs),j.id,j.time_s,ef0,efs,efa,lmin,label);
end
writetable(struct2table(rows),fullfile(dest,'causa_por_passo.csv'));
save(fullfile(dest,'causa_por_passo.mat'),'rows');

% --- Part B1/B2 influence on historical trajectory ---
infl=struct([]);
for jobId=["j00014","j00019"]
    o=cache.(char(jobId));
    p=o.param; Ts=p.Ts;
    G=o.case.G(:)';
    kev=find(G(1:end-1)==0,1,'first');
    if isempty(kev)
        % return-of-source: first restoration after an outage, else first G==1 after min
        kev=find(diff(G(1:end-1))==1,1,'first');
        if isempty(kev), kev=numel(o.u); end
    end
    sel=rows(strcmp({rows.id},char(jobId)) & strcmp({rows.stratum},'flag_-6'));
    ks=sort([sel.k]);
    k0=ks(1);
    % one-step local
    dSOC_step=nan(size(ks)); dPB_step=nan(size(ks));
    for ii=1:numel(ks)
        k=ks(ii); rr=sel([sel.k]==k);
        uqp=rr.u_qp;
        if ~isfinite(uqp), continue; end
        [s1,p1]=planta_bess(o.SOC(k),o.PBESS(k),uqp,o.case.L(k),o.case.M(k),o.case.G(k),p);
        dSOC_step(ii)=s1-o.SOC(k+1);
        dPB_step(ii)=p1-o.PBESS(k+1);
    end
    % chained: QP command on fallback steps, historical otherwise
    soc=o.SOC(k0); pb=o.PBESS(k0);
    Eprep_hist=0; Eprep_cf=0; u_tv_hist=0; u_tv_cf=0; uph=0; upc=0;
    if k0>1, uph=o.u(k0-1); upc=o.u(k0-1); end
    for k=k0:(kev-1)
        uh=o.u(k);
        hit=sel([sel.k]==k);
        if ~isempty(hit) && isfinite(hit.u_qp), uc=hit.u_qp; else, uc=uh; end
        [soc,pb]=planta_bess(soc,pb,uc,o.case.L(k),o.case.M(k),o.case.G(k),p);
        Eprep_hist=Eprep_hist+max(uh,0)*Ts/3600;
        Eprep_cf=Eprep_cf+max(uc,0)*Ts/3600;
        u_tv_hist=u_tv_hist+abs(uh-uph); u_tv_cf=u_tv_cf+abs(uc-upc);
        uph=uh; upc=uc;
    end
    w.job=char(jobId);
    w.k_first_fb=k0; w.k_event=kev; w.t_event_s=(kev-1)*Ts;
    w.n_fallback=numel(ks);
    w.SOC_hist_event=o.SOC(kev);
    w.SOC_cf_event=soc;
    w.dSOC_pp=soc-o.SOC(kev);
    w.PBESS_hist_event=o.PBESS(kev);
    w.PBESS_cf_event=pb;
    w.Eprep_discharge_hist_kWh=Eprep_hist;
    w.Eprep_discharge_cf_kWh=Eprep_cf;
    w.dEprep_kWh=Eprep_cf-Eprep_hist;
    w.mean_abs_du=mean(abs([sel.du_applied_minus_qp]),'omitnan');
    w.max_abs_du=max(abs([sel.du_applied_minus_qp]),[],'omitnan');
    w.mean_dSOC_onestep_pp=mean(dSOC_step,'omitnan');
    w.max_abs_dSOC_onestep_pp=max(abs(dSOC_step),[],'omitnan');
    w.note='B2 chained uses historical u off fallback; local bound not a pure closed loop';
    if isempty(infl), infl=w; else, infl(end+1)=w; end %#ok<AGROW>
end
writetable(struct2table(infl),fullfile(dest,'influencia_janela.csv'));

% --- Part B3 closed loop ---
cl=struct([]);
specs=struct('name',{'replay_oficial','escala_0p001','qp_recovery'}, ...
    'scale',{[],0.001,[]},'recovery',{false,false,true});
for jobId=["j00014","j00019"]
    o=cache.(char(jobId));
    % historical metrics
    cl=append_cl(cl,summarize_out(o,char(jobId),'historico_mat',kev_of(o)));
    for s=1:numel(specs)
        p=o.param;
        if ~isempty(specs(s).scale), p.solver_objective_scale=specs(s).scale; end
        p.qp_recovery=specs(s).recovery;
        fprintf('START CLOSED %s %s\n',jobId,specs(s).name);
        if strcmp(specs(s).name,'replay_oficial')
            out=simular_ems_auditado('mpc_qp_v5',o.case,o.param);
        else
            out=simular_causa(o.case,p);
        end
        save(fullfile(dest,sprintf('%s_%s.mat',char(jobId),specs(s).name)),'out','-v7');
        cl=append_cl(cl,summarize_out(out,char(jobId),specs(s).name,kev_of(o)));
        fprintf('DONE CLOSED %s %s peak=%.6f fb=%d SOC_ev=%.4f\n',jobId,specs(s).name, ...
            out.metrics.P_raw_kW,sum([out.diagnostics.usou_fallback]),cl(end).SOC_event);
    end
end
writetable(struct2table(cl),fullfile(dest,'malha_fechada.csv'));

n47=sum(strcmp({rows.stratum},'flag_-6'));
nMatch=sum([rows.ef0_matches_mat] & strcmp({rows.stratum},'flag_-6'));
labc=count_labels({rows(strcmp({rows.stratum},'flag_-6')).label});
status=struct('complete',true,'n_principal_minus6',n47,'ef0_matches_mat',nMatch, ...
    'labels',labc,'production_modified',false, ...
    'official_kpis_unchanged',true, ...
    'hashes',hashes, ...
    'matlab',version);
fid=fopen(fullfile(dest,'status.json'),'w'); fprintf(fid,'%s',jsonencode(status,PrettyPrint=true)); fclose(fid);
for i=1:numel(hashes)
    assert(strcmp(sha256_file(hashes(i).file),hashes(i).sha256),'Production source changed');
end
fprintf('OUTPUT %s\n',dest);
end

function [H,f,A,B,E,D,lb,ub,u0,q]=rebuild_qp(o,k)
p=o.param; n=numel(o.u);
L=o.case.L(:)'; M=o.case.M(:)'; G=o.case.G(:)';
lf=L; mf=M; gf=G;
if isfield(o.case,'Lf'), lf=o.case.Lf(:)'; end
if isfield(o.case,'Mf'), mf=o.case.Mf(:)'; end
if isfield(o.case,'Gf'), gf=o.case.Gf(:)'; end
delay=0; if isfield(o.case,'detection_delay'), delay=o.case.detection_delay; end
ix=k:min(k+p.Np_mpc-1,n+1); lh=lf(ix); mh=mf(ix); gh=gf(ix);
km=max(1,k-round(delay/p.Ts));
lh(1)=L(km); mh(1)=M(km); gh(1)=G(km);
if isfield(p,'mpc_foresight_load') && ~p.mpc_foresight_load, lh(2:end)=lh(1); end
if isfield(p,'mpc_foresight_grid') && ~p.mpc_foresight_grid, gh(2:end)=gh(1); mh(2:end)=mh(1); end
soc=o.SOC(k); pb=o.PBESS(k); u0=0; pg0=L(1);
if k>1, u0=o.u(k-1); pg0=o.Psource(k-1); end
q=montar_qp_auditado(1,soc,pb,u0,pg0,lh,mh,gh,p);
H=q.H; f=q.f; A=q.Aineq; B=q.bineq; E=q.Aeq; D=q.beq; lb=q.lb; ub=q.ub;
end

function label=classify_cause(lmin,lminTol,spd,ef0,efs,efa,stratum)
if lmin<lminTol
    label='hessiana_indefinida'; return;
end
if ~strcmp(stratum,'flag_-6') && ef0>0
    label='ok'; return;
end
if spd && (efs>0 || efa>0)
    label='ipm_falso_nao_convexo'; return;
end
if ef0==0 && ~(efs>0 || efa>0)
    label='iteracoes'; return;
end
if (ef0==-2 || efs==-2) && ~(efs>0 || efa>0)
    label='inviavel'; return;
end
label='inconclusivo';
end

function kev=kev_of(o)
G=o.case.G(:)';
kev=find(G(1:end-1)==0,1,'first');
if isempty(kev)
    kev=find(diff(G(1:end-1))==1,1,'first');
    if isempty(kev), kev=numel(o.u); end
end
end

function s=summarize_out(out,job,name,kev)
fb=sum([out.diagnostics.usou_fallback]);
ef=[out.diagnostics.exitflag];
s=struct('job',job,'run',name, ...
    'P_raw_kW',out.metrics.P_raw_kW,'E_raw_kWh',out.metrics.E_raw_kWh, ...
    'SOC_final',out.metrics.SOC_final,'throughput_kWh',out.metrics.throughput_kWh, ...
    'fallback_count',fb,'fallback_pct',out.metrics.fallback_pct, ...
    'SOC_event',out.SOC(kev),'PBESS_event',out.PBESS(kev), ...
    'n_exitflag_m6',sum(ef==-6), ...
    'Eprep_kWh',sum(max(out.u(1:kev-1),0))*out.param.Ts/3600);
end

function cl=append_cl(cl,s)
if isempty(cl), cl=s; else, cl(end+1)=s; end
end

function c=count_labels(labs)
c=struct();
for L=["ipm_falso_nao_convexo","hessiana_indefinida","inviavel","iteracoes","ok","inconclusivo"]
    c.(char(L))=sum(strcmp(labs,char(L)));
end
end

function h=sha256_file(fn)
fid=fopen(fn,'rb'); assert(fid>=0); c=onCleanup(@() fclose(fid)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(fread(fid,Inf,'*uint8'));
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
