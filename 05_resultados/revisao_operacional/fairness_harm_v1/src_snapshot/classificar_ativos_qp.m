function row = classificar_ativos_qp(ctrl, q, z, ef, lam, u_mat, u_prev, p, Gk, SOC)
% Active-set labels from lambda when the QP succeeded; otherwise applied policy.
eps_du = 1e-3;
eps_lam = 1e-5;
dUmax = q.dUmax;
row = struct('exitflag',ef,'fonte_ativos','qp', ...
    'sat_du',false,'sat_u_max',false,'sat_u_min',false, ...
    'soc_min',false,'soc_max',false,'source_limit',false, ...
    'slack_load',false,'slack_source',false,'slack_recharge',false,'slack_event',false, ...
    'ativos','');

qp_ok = ef>0 && ~isempty(z) && isstruct(lam) && ...
    ((startsWith(ctrl,'miope') && isfield(q,'idx_u')) || isfield(q,'idx_du'));
if ~qp_ok
    row.fonte_ativos = 'politica_aplicada';
    du = u_mat - u_prev;
    row.sat_du = abs(du) >= dUmax - eps_du;
    row.sat_u_max = u_mat >= p.PBESS_max - eps_du;
    umin = p.PBESS_min; if Gk==0, umin=0; end
    row.sat_u_min = u_mat <= umin + eps_du;
    row.soc_min = SOC <= p.SOC_min + 1e-4;
    row.soc_max = SOC >= p.SOC_max - 1e-4;
    row.ativos = join_flags(row);
    return
end

if startsWith(ctrl,'miope')
    du_bound_lo = abs(z(q.idx_u) - q.lb(q.idx_u)) < eps_du && lam.lower(q.idx_u) > eps_lam;
    du_bound_hi = abs(q.ub(q.idx_u) - z(q.idx_u)) < eps_du && lam.upper(q.idx_u) > eps_lam;
    row.sat_du = du_bound_lo || du_bound_hi;
    names = q.ineq_name;
    act = lam.ineqlin > eps_lam;
    for i=1:numel(names)
        if ~act(i), continue; end
        switch names{i}
            case 'u_max', row.sat_u_max = true;
            case 'u_min', row.sat_u_min = true;
            case 'SOC_min', row.soc_min = true;
            case 'SOC_max', row.soc_max = true;
            case 'source_limit', row.source_limit = true;
            case 'recharge', row.slack_recharge = true;
        end
    end
    row.slack_load = z(q.idx_sl) > 1e-3;
    row.slack_source = z(q.idx_ss) > 1e-3;
    row.slack_recharge = row.slack_recharge || z(q.idx_sr) > 1e-3;
else
    Nc = q.Nc;
    i1 = q.idx_du(1);
    du_lo = lam.lower(i1) > eps_lam;
    du_hi = lam.upper(i1) > eps_lam;
    row.sat_du = du_lo || du_hi;
    Np = q.Np;
    nlam = numel(lam.ineqlin);
    blocks = {'u_max','u_min','PBESS_max','PBESS_min','SOC_max','SOC_min','source_limit'};
    row0 = 0;
    for b=1:7
        sl = lam.ineqlin(row0+(1:min(Np,nlam-row0)));
        hit = any(sl > eps_lam);
        switch blocks{b}
            case 'u_max', row.sat_u_max = hit;
            case 'u_min', row.sat_u_min = hit;
            case 'SOC_min', row.soc_min = hit;
            case 'SOC_max', row.soc_max = hit;
            case 'source_limit', row.source_limit = hit;
        end
        row0 = row0 + Np;
    end
    if row0 < nlam
        extra = lam.ineqlin(row0+1:end) > eps_lam;
        n_rec = numel(find(q.Psource_min_recharge > 0));
        if n_rec>0
            row.slack_recharge = any(extra(1:min(n_rec,numel(extra))));
        end
        if numel(extra) > n_rec
            row.slack_event = any(extra(n_rec+1:end));
        end
    end
    row.slack_load = any(z(q.idx_slack_load) > 1e-3);
    row.slack_source = any(z(q.idx_slack_source) > 1e-3);
    row.slack_recharge = row.slack_recharge || any(z(q.idx_slack_recharge) > 1e-3);
    row.slack_event = row.slack_event || any(z(q.idx_slack_event) > 1e-3);
end
row.ativos = join_flags(row);
end

function s = join_flags(row)
names = {'sat_du','sat_u_max','sat_u_min','soc_min','soc_max','source_limit', ...
    'slack_load','slack_source','slack_recharge','slack_event'};
on = names(cellfun(@(n) row.(n), names));
if isempty(on), s = 'nenhum'; else, s = strjoin(on,'|'); end
end
