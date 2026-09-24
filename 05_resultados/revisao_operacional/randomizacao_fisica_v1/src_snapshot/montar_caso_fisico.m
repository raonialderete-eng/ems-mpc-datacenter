function [c, p] = montar_caso_fisico(d, p0)
p = p0;
p.Pbase_audit = 950;
p.information_policy = 'persistence';
p.mpc_foresight_grid = true;
p.mpc_foresight_load = true;
p.tau_b = d.tau_b;
p.SOC_initial = d.SOC0;
p.Psource_max_nominal = d.M;
p.ab = exp(-p.Ts / p.tau_b);
p.bb = 1 - p.ab;
t = 0:p.Ts:p.Tf;
N = numel(t);
L = d.L_base * ones(1, N);
L(t >= d.t0) = d.L_evento;
G = ones(1, N);
M = d.M * ones(1, N);
if strcmp(d.tipo, 'perda')
    G(t >= d.t0 & t < d.t0 + d.dur) = 0;
    M = d.M * G;
end
c = struct('L', L, 'M', M, 'G', G, 'Lf', L, 'Mf', M, 'Gf', G);
end
