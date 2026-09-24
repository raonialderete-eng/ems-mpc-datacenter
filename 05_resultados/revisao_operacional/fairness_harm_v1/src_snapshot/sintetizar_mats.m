function dest = sintetizar_mats(root, dest)
% Phase 1: command windows and post-hoc active sets from existing MATs.
if nargin<1 || isempty(root)
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(fileparts(here)));
end
if nargin<2 || isempty(dest)
    dest = fullfile(root,'05_resultados','revisao_operacional','fairness_sintese_v1');
end
if ~isfolder(dest), mkdir(dest); end
figd = fullfile(dest,'figuras');
if ~isfolder(figd), mkdir(figd); end

camp = fullfile(root,'05_resultados','revisao_operacional','campanha_v1');
anchors = { ...
    'j00003','principal','carga_faixas','miope_qp'; ...
    'j00004','principal','carga_faixas','mpc_qp_v5'; ...
    'j00008','principal','limite_fonte','miope_qp'; ...
    'j00009','principal','limite_fonte','mpc_qp_v5'; ...
    'j00013','principal','perda_fonte','miope_qp'; ...
    'j00014','principal','perda_fonte','mpc_qp_v5'; ...
    'j00018','principal','retorno_fonte','miope_qp'; ...
    'j00019','principal','retorno_fonte','mpc_qp_v5'; ...
    'j00048','fairness400','carga_faixas','miope_qp'; ...
    'j00049','fairness400','carga_faixas','mpc_qp_v5'; ...
    'j00086','fairness400','perda_fonte','miope_qp'; ...
    'j00087','fairness400','perda_fonte','mpc_qp_v5'; ...
    'j00162','nvml_fairness400','nvml_llama2_stress','miope_qp'};

cmdRows = {};
actRows = {};
missing = {};
for a=1:size(anchors,1)
    id = anchors{a,1};
    fn = fullfile(camp,[id '.mat']);
    if ~isfile(fn)
        missing{end+1} = id; %#ok<AGROW>
        continue
    end
    fprintf('MAT %s\n', id);
    S = load(fn);
    o = unwrap_out(S);
    p = o.param;
    c = o.case;
    L = c.L(:)'; G = c.G(:)'; M = c.M(:)';
    n = numel(o.u);
    t = o.t(1:n);
    u = o.u(:)';
    du = [u(1), diff(u)];
    dUn = p.dPBESS_ref_max;
    dUe = dUn;
    if isfield(p,'dPBESS_ref_max_evento'), dUe = p.dPBESS_ref_max_evento; end
    dU = dUn * ones(size(u));
    dU(G(1:n)==0) = dUe;
    sat = abs(du) >= (dU - 1e-3);
    ks = event_indices(L,G,n);
    for e=1:numel(ks)
        k0 = ks(e).k;
        t0 = (k0-1)*p.Ts;
        w0 = max(1, k0-20);
        w1 = min(n, k0+20);
        ix = w0:w1;
        for j=ix
            cmdRows(end+1,:) = {id, anchors{a,2}, anchors{a,3}, anchors{a,4}, ...
                ks(e).tipo, t0, t(j), u(j), du(j), dU(j), double(sat(j)), ...
                o.SOC(j), o.Pnao(j)}; %#ok<AGROW>
        end
        fprintf('  evento %s k=%d\n', ks(e).tipo, k0);
        actRows(end+1,:) = reconstruir_ativo(id, anchors(a,:), ks(e), o, p, c); %#ok<AGROW>
    end
end

hdrC = {'id','pacote','scenario','ctrl','evento','t_evento_s','t','u','du','dUmax','sat_du','SOC','Pnao'};
writecell([hdrC; cmdRows], fullfile(dest,'comando_eventos.csv'));
hdrA = {'id','pacote','scenario','ctrl','evento','t_s','k','exitflag','fonte_ativos', ...
    'sat_du','sat_u_max','sat_u_min','soc_min','soc_max','source_limit', ...
    'slack_load','slack_source','slack_recharge','slack_event','ativos','u_mat','u_qp'};
writecell([hdrA; actRows], fullfile(dest,'ativo_por_evento.csv'));
try
    fprintf('figuras skipped (headless batch)\n');
catch ME
    fprintf('figuras skipped: %s\n', ME.message);
end
fid = fopen(fullfile(dest,'MISSING.txt'),'w');
fprintf(fid,'%s\n', missing{:});
fprintf(fid,'B3_miope MATs not on disk; NVML 400 kW/s uses j00162 (fairness campaign).\n');
fclose(fid);
end

function o = unwrap_out(S)
if isfield(S,'out'), o=S.out; else, o=S; end
end

function ks = event_indices(L,G,n)
ks = struct('k',{},'tipo',{});
dL = [0, abs(diff(L(1:n+1)))];
kL = find(dL >= 1);
kL = kL(kL>=1 & kL<=n);
% NVML traces have hundreds of 1 kW ticks; keep the largest steps only.
if numel(kL) > 8
    [~,ord] = sort(dL(kL),'descend');
    kL = sort(kL(ord(1:min(4,numel(ord)))));
end
for i=1:numel(kL)
    ks(end+1).k = kL(i); %#ok<AGROW>
    ks(end).tipo = sprintf('degrau_L_%g', L(kL(i)));
end
kG = find(diff(G(1:n+1)) == -1, 1, 'first') + 1;
if ~isempty(kG) && kG<=n
    ks(end+1).k = kG;
    ks(end).tipo = 'G_1to0';
end
end

function row = reconstruir_ativo(id, anc, ev, o, p, c)
k = ev.k;
n = numel(o.u);
up = 0; gp = c.L(1);
if k>1, up = o.u(k-1); gp = o.Psource(k-1); end
[lh,mh,gh] = horizonte_campanha(c, p, k, n);
ctrl = o.ctrl;
u_mat = o.u(k);
ef = NaN; z = []; lam = []; q = struct('dUmax',p.dPBESS_ref_max);
if isfield(o,'diagnostics') && numel(o.diagnostics)>=k
    ef0 = o.diagnostics(k).exitflag;
else
    ef0 = NaN;
end
opts = optimoptions('quadprog','Display','off','Algorithm','interior-point-convex', ...
    'MaxIterations',200,'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-6);
try
    if strcmp(ctrl,'miope_qp')
        q = montar_qp_miope_sintese(o.SOC(k), o.PBESS(k), up, gp, lh(1), mh(1), gh(1), p);
        [z,~,ef,~,lam] = quadprog(q.H,q.f,q.Aineq,q.bineq,q.Aeq,q.beq,q.lb,q.ub,[],opts);
        u_qp = NaN; if ~isempty(z), u_qp = z(q.idx_u); end
    elseif strcmp(ctrl,'mpc_qp_v5')
        q = montar_qp_auditado(1, o.SOC(k), o.PBESS(k), up, gp, lh, mh, gh, p);
        [z,~,ef,~,lam] = quadprog(q.H,q.f,q.Aineq,q.bineq,q.Aeq,q.beq,q.lb,q.ub,[],opts);
        u_qp = NaN;
        if ~isempty(z)
            u_qp = q.u_livre(1) + z(q.idx_du(1));
        end
    else
        u_qp = NaN; ef = ef0;
    end
catch
    ef = ef0; u_qp = NaN;
end
if ~isfinite(ef), ef = ef0; end
cls = classificar_ativos_qp(ctrl, q, z, ef, lam, u_mat, up, p, gh(1), o.SOC(k));
row = {id, anc{2}, anc{3}, anc{4}, ev.tipo, (k-1)*p.Ts, k, ef, cls.fonte_ativos, ...
    double(cls.sat_du), double(cls.sat_u_max), double(cls.sat_u_min), ...
    double(cls.soc_min), double(cls.soc_max), double(cls.source_limit), ...
    double(cls.slack_load), double(cls.slack_source), double(cls.slack_recharge), ...
    double(cls.slack_event), cls.ativos, u_mat, u_qp};
end

function figurar_comando(cmdRows, figd)
if isempty(cmdRows), return; end
ids = unique(cmdRows(:,1));
set(0,'DefaultFigureVisible','off');
for i=1:numel(ids)
    mask = strcmp(cmdRows(:,1), ids{i});
    evs = unique(cmdRows(mask,5));
    for e=1:min(2,numel(evs))
        m2 = mask & strcmp(cmdRows(:,5), evs{e});
        tt = cell2mat(cmdRows(m2,7));
        uu = cell2mat(cmdRows(m2,8));
        t0 = cmdRows{find(m2,1),6};
        fig = figure('Visible','off','Color','w','Renderer','painters');
        plot(tt, uu, 'LineWidth', 1.2); hold on; xline(t0,'--');
        xlabel('t (s)'); ylabel('u (kW)'); grid on;
        title(sprintf('%s %s', ids{i}, evs{e}), 'Interpreter','none');
        safe = regexprep(evs{e},'[^A-Za-z0-9_]+','_');
        print(fig, fullfile(figd, sprintf('%s_%s.png', ids{i}, safe)), '-dpng','-r72');
        close(fig);
    end
end
end

function [lh,mh,gh] = horizonte_campanha(c,p,k,n)
L=c.L(:)'; M=c.M(:)'; G=c.G(:)';
lf=L; mf=M; gf=G;
if isfield(c,'Lf'), lf=c.Lf(:)'; end
if isfield(c,'Mf'), mf=c.Mf(:)'; end
if isfield(c,'Gf'), gf=c.Gf(:)'; end
delay=0; if isfield(c,'detection_delay'), delay=c.detection_delay; end
ix=k:min(k+p.Np_mpc-1,n+1);
lh=lf(ix); mh=mf(ix); gh=gf(ix);
km=max(1,k-round(delay/p.Ts));
lh(1)=L(km); mh(1)=M(km); gh(1)=G(km);
if isfield(p,'mpc_foresight_load') && ~p.mpc_foresight_load, lh(2:end)=lh(1); end
if isfield(p,'mpc_foresight_grid') && ~p.mpc_foresight_grid
    gh(2:end)=gh(1); mh(2:end)=mh(1);
end
end
