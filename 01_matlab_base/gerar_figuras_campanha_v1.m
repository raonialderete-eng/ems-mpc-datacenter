function gerar_figuras_campanha_v1(root)
% Rebuild paper Figs 2--4 from 11 Sep campanha_v1 jobs (not legacy todos_cenarios MATs).
if nargin < 1
    root = fileparts(mfilename('fullpath'));
end
P = ems_pack_paths(root);
camp = P.campanha;
outDir = P.figuras;
if ~isfolder(outDir), mkdir(outDir); end
altDir = P.alt_figuras;
if ~isfolder(altDir), mkdir(altDir); end

jobs = struct( ...
    'carga', {{'j00001','j00003','j00004'}}, ...
    'limite', {{'j00006','j00008','j00009'}}, ...
    'perda', {{'j00011','j00013','j00014'}});

fprintf('=== campanha_v1 KPI check (must match 11 Sep tables) ===\n');
H = load_job(fullfile(camp, 'j00001.mat'));
M = load_job(fullfile(camp, 'j00003.mat'));
V = load_job(fullfile(camp, 'j00004.mat'));
report('carga_faixas', H, M, V);
fig_paineis(H, M, V, 'Load bands', fullfile(outDir, 'comp_carga_faixas_paineis.png'));

H = load_job(fullfile(camp, 'j00006.mat'));
M = load_job(fullfile(camp, 'j00008.mat'));
V = load_job(fullfile(camp, 'j00009.mat'));
report('limite_fonte', H, M, V);
fig_zoom_degrau(H, M, V, fullfile(outDir, 'comp_limite_fonte_zoom_degrau.png'));

H = load_job(fullfile(camp, 'j00011.mat'));
M = load_job(fullfile(camp, 'j00013.mat'));
V = load_job(fullfile(camp, 'j00014.mat'));
report('perda_fonte', H, M, V);
fig_zoom_falha(H, M, V, fullfile(outDir, 'comp_perda_fonte_zoom_falha.png'));

if ~strcmp(outDir, altDir)
    copyfile(fullfile(outDir, 'comp_carga_faixas_paineis.png'), altDir, 'f');
    copyfile(fullfile(outDir, 'comp_limite_fonte_zoom_degrau.png'), altDir, 'f');
    copyfile(fullfile(outDir, 'comp_perda_fonte_zoom_falha.png'), altDir, 'f');
end
fprintf('Wrote PNGs to %s\n', outDir);
end

function S = load_job(fn)
assert(isfile(fn), 'Missing MAT: %s', fn);
D = load(fn, 'out', 'job');
o = D.out;
S.id = D.job.id;
S.ctrl = D.job.ctrl;
S.t = o.t(:)';
S.SOC = o.SOC(:)';
S.PBESS = o.PBESS(:)';
S.Pnao = o.Pnao(:)';
S.L = o.case.L(:)';
S.M = o.case.M(:)';
S.G = o.case.G(:)';
S.P_raw = o.metrics.P_raw_kW;
S.SOC_f = o.metrics.SOC_final;
n = numel(S.Pnao);
S.t_u = S.t(1:n);
S.L_u = S.L(1:n);
S.M_u = S.M(1:n);
S.PBESS_u = S.PBESS(1:n);
end

function report(name, H, M, V)
fprintf('%s  H %s P=%.6f SOC_f=%.6f | M %s P=%.6f SOC_f=%.6f | V5 %s P=%.6f SOC_f=%.6f\n', ...
    name, H.id, H.P_raw, H.SOC_f, M.id, M.P_raw, M.SOC_f, V.id, V.P_raw, V.SOC_f);
end

function fig_paineis(H, M, V, titleStr, fn)
tmin = V.t_u / 60;
fig = figure('Color', 'w', 'Position', [80 80 850 950], 'Visible', 'off');
tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
plot(ax, tmin, V.L_u, 'k', 'LineWidth', 1.6); hold(ax, 'on');
plot(ax, tmin, V.M_u, 'k--', 'LineWidth', 1.2);
ylabel(ax, 'Power [kW]'); title(ax, [titleStr, ' --- Heuristic / Myopic / MPC-QP']);
legend(ax, {'P_{load}', 'P_{source,max}'}, 'Location', 'best', 'FontSize', 8);
grid(ax, 'on');
plot_three(nexttile(tl), tmin, H.PBESS_u, M.PBESS_u, V.PBESS_u, 'P_{BESS} [kW]');
plot_three(nexttile(tl), tmin, H.Pnao, M.Pnao, V.Pnao, 'Unserved power [kW]');
ax = plot_three(nexttile(tl), tmin, H.SOC(1:numel(tmin)), M.SOC(1:numel(tmin)), V.SOC(1:numel(tmin)), 'SOC [%]');
xlabel(ax, 'Time [min]');
save_png(fig, fn);
end

function fig_zoom_degrau(H, M, V, fn)
t0 = 200;
mask = (V.t_u >= 150) & (V.t_u <= 350);
tm = V.t_u(mask) / 60;
fig = figure('Color', 'w', 'Position', [80 80 850 620], 'Visible', 'off');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = plot_three(nexttile(tl), tm, H.PBESS_u(mask), M.PBESS_u(mask), V.PBESS_u(mask), 'P_{BESS} [kW]');
xline(ax, t0/60, 'k:', 'LineWidth', 1.2);
title(ax, sprintf('Source limit --- step zoom (t = %.0f s)', t0));
ax = plot_three(nexttile(tl), tm, H.Pnao(mask), M.Pnao(mask), V.Pnao(mask), 'Unserved power [kW]');
xline(ax, t0/60, 'k:', 'LineWidth', 1.2);
xlabel(ax, 'Time [min]');
save_png(fig, fn);
end

function fig_zoom_falha(H, M, V, fn)
idx0 = find(V.G == 0, 1, 'first');
t0 = V.t(idx0);
mask = (V.t_u >= max(0, t0-60)) & (V.t_u <= min(V.t_u(end), t0+180));
tm = V.t_u(mask) / 60;
fig = figure('Color', 'w', 'Position', [80 80 850 620], 'Visible', 'off');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = plot_three(nexttile(tl), tm, H.PBESS_u(mask), M.PBESS_u(mask), V.PBESS_u(mask), 'P_{BESS} [kW]');
xline(ax, t0/60, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Source-loss onset');
title(ax, sprintf('Source loss --- onset zoom (tf = %.0f s)', t0));
ax = plot_three(nexttile(tl), tm, H.Pnao(mask), M.Pnao(mask), V.Pnao(mask), 'Unserved power [kW]');
yline(ax, 350, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
xline(ax, t0/60, 'k:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
legend(ax, {'Heuristic', 'Myopic QP', 'MPC-QP', 'Case-study bound (350 kW)'}, 'Location', 'best', 'FontSize', 8);
xlabel(ax, 'Time [min]');
save_png(fig, fn);
end

function ax = plot_three(ax, t, yh, ym, yv, ylab)
cH = [38 38 38]/255; cM = [0 114 178]/255; cV = [213 94 0]/255;
plot(ax, t, yh, 'Color', cH, 'LineWidth', 1.6); hold(ax, 'on');
plot(ax, t, ym, 'Color', cM, 'LineWidth', 1.6);
plot(ax, t, yv, 'Color', cV, 'LineWidth', 1.6);
ylabel(ax, ylab);
legend(ax, {'Heuristic', 'Myopic QP', 'MPC-QP'}, 'Location', 'best', 'FontSize', 8);
grid(ax, 'on'); ax.FontSize = 9;
end

function save_png(fig, fn)
print(fig, fn, '-dpng', '-r300');
close(fig);
fprintf('Wrote %s\n', fn);
end
