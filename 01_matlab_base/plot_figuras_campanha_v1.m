function plot_figuras_campanha_v1(root)
% Plot Figs 2-4 from CSV traces (no MAT load, classic subplot, painters).
if nargin < 1
    root = fileparts(mfilename('fullpath'));
end
P = ems_pack_paths(root);
src = P.traces;
outDir = P.figuras;
if ~isfolder(outDir), mkdir(outDir); end
set(groot, 'DefaultFigureRenderer', 'painters');
set(groot, 'DefaultFigureVisible', 'off');

cH = [38 38 38]/255; cM = [0 114 178]/255; cV = [213 94 0]/255;
T = readtable(fullfile(src, 'carga_faixas.csv'));
tmin = T.t_s / 60;
fig = figure('Color','w','Position',[80 80 850 950]);
subplot(4,1,1);
plot(tmin, T.Pload, 'k', 'LineWidth', 1.6); hold on;
plot(tmin, T.Psource_max, 'k--', 'LineWidth', 1.2);
ylabel('Power [kW]'); title('Load bands --- Heuristic / Myopic / MPC-QP');
legend({'P_{load}','P_{source,max}'}, 'Location','best', 'FontSize', 8); grid on;
three(subplot(4,1,2), tmin, T.PBESS_h, T.PBESS_m, T.PBESS_v, 'P_{BESS} [kW]', cH, cM, cV);
three(subplot(4,1,3), tmin, T.Pnao_h, T.Pnao_m, T.Pnao_v, 'Unserved power [kW]', cH, cM, cV);
ax = three(subplot(4,1,4), tmin, T.SOC_h, T.SOC_m, T.SOC_v, 'SOC [%]', cH, cM, cV);
xlabel(ax, 'Time [min]');
print(fig, fullfile(outDir, 'comp_carga_faixas_paineis.png'), '-dpng', '-r300', '-painters');
close(fig); fprintf('wrote carga\n');

T = readtable(fullfile(src, 'limite_fonte.csv'));
mask = T.t_s >= 150 & T.t_s <= 350;
tm = T.t_s(mask) / 60;
fig = figure('Color','w','Position',[80 80 850 620]);
three(subplot(2,1,1), tm, T.PBESS_h(mask), T.PBESS_m(mask), T.PBESS_v(mask), 'P_{BESS} [kW]', cH, cM, cV);
xline(200/60, 'k:', 'LineWidth', 1.2); title('Source limit --- step zoom (t = 200 s)');
three(subplot(2,1,2), tm, T.Pnao_h(mask), T.Pnao_m(mask), T.Pnao_v(mask), 'Unserved power [kW]', cH, cM, cV);
xline(200/60, 'k:', 'LineWidth', 1.2); xlabel('Time [min]');
print(fig, fullfile(outDir, 'comp_limite_fonte_zoom_degrau.png'), '-dpng', '-r300', '-painters');
close(fig); fprintf('wrote limite\n');

T = readtable(fullfile(src, 'perda_fonte.csv'));
idx0 = find(T.g == 0, 1, 'first');
t0 = T.t_s(idx0);
mask = T.t_s >= max(0, t0-60) & T.t_s <= min(T.t_s(end), t0+180);
tm = T.t_s(mask) / 60;
fig = figure('Color','w','Position',[80 80 850 620]);
three(subplot(2,1,1), tm, T.PBESS_h(mask), T.PBESS_m(mask), T.PBESS_v(mask), 'P_{BESS} [kW]', cH, cM, cV);
xline(t0/60, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Source-loss onset'); title(sprintf('Source loss --- onset zoom (tf = %.0f s)', t0));
ax = three(subplot(2,1,2), tm, T.Pnao_h(mask), T.Pnao_m(mask), T.Pnao_v(mask), 'Unserved power [kW]', cH, cM, cV);
yline(ax, 350, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
xline(t0/60, 'k:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
legend(ax, {'Heuristic','Myopic QP','MPC-QP','Case-study bound (350 kW)'}, 'Location','best', 'FontSize', 8);
xlabel('Time [min]');
print(fig, fullfile(outDir, 'comp_perda_fonte_zoom_falha.png'), '-dpng', '-r300', '-painters');
close(fig); fprintf('wrote perda\n');
end

function ax = three(ax, t, yh, ym, yv, ylab, cH, cM, cV)
plot(ax, t, yh, 'Color', cH, 'LineWidth', 1.6); hold(ax, 'on');
plot(ax, t, ym, 'Color', cM, 'LineWidth', 1.6);
plot(ax, t, yv, 'Color', cV, 'LineWidth', 1.6);
ylabel(ax, ylab); legend(ax, {'Heuristic','Myopic QP','MPC-QP'}, 'Location','best', 'FontSize', 8);
grid(ax, 'on');
end
