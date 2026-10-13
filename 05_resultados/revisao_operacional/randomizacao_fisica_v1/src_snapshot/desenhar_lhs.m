function D = desenhar_lhs(crit)
n = crit.n;
rng(crit.seed, 'twister');
names = {'L_base','dL','SOC0','M','t0','dur','tau_b'};
lo = [crit.factors.L_base_kW(1), crit.factors.dL_kW(1), crit.factors.SOC0_pct(1), ...
    crit.factors.M_kW(1), crit.factors.t0_s(1), crit.factors.dur_s(1), crit.factors.tau_b_s(1)];
hi = [crit.factors.L_base_kW(2), crit.factors.dL_kW(2), crit.factors.SOC0_pct(2), ...
    crit.factors.M_kW(2), crit.factors.t0_s(2), crit.factors.dur_s(2), crit.factors.tau_b_s(2)];
try
    X = lhsdesign(n, 7, 'criterion', 'maximin', 'iterations', 40);
    method = 'lhsdesign_maximin';
catch
    X = zeros(n, 7);
    for j = 1:7
        X(:, j) = (randperm(n)' - 0.5) / n;
    end
    method = 'latin_ranks_fallback';
end
U = lo + X .* (hi - lo);
D = struct('id', {}, 'tipo', {}, 'L_base', {}, 'dL', {}, 'L_evento', {}, ...
    'SOC0', {}, 'M', {}, 't0', {}, 'dur', {}, 'tau_b', {}, 'bound_kW', {}, 'method', {});
tipos = [repmat({'perda'}, 1, crit.n_perda), repmat({'limite'}, 1, crit.n_limite)];
for i = 1:n
    d = struct();
    d.id = sprintf('D%02d', i);
    d.tipo = tipos{i};
    d.L_base = U(i, 1);
    d.dL = U(i, 2);
    d.L_evento = min(crit.constraints.L_evento_cap_kW, d.L_base + d.dL);
    d.SOC0 = U(i, 3);
    d.M = U(i, 4);
    d.t0 = U(i, 5);
    d.dur = U(i, 6);
    d.tau_b = U(i, 7);
    if d.t0 + d.dur >= crit.constraints.t0_plus_dur_lt_s
        d.dur = max(80, crit.constraints.t0_plus_dur_lt_s - d.t0 - 1);
    end
    if strcmp(d.tipo, 'limite') && d.L_evento <= d.M
        d.M = min(d.M, max(600, d.L_evento - 80));
        if d.L_evento <= d.M
            d.L_evento = min(950, d.M + 80);
        end
    end
    if strcmp(d.tipo, 'perda')
        d.bound_kW = max(d.L_evento - crit.constraints.PBESS_max_kW, 0);
    else
        d.bound_kW = max(d.L_evento - d.M - crit.constraints.PBESS_max_kW, 0);
    end
    d.method = method;
    D(i) = d;
end
end
