%% GERAR_GRAFICOS_COMPARATIVOS
% Figuras sobrepostas Heuristico x MPC-QP-V4 x MPC-QP-V5 para o artigo.
%
% Uso:
%   cenarios_plot = {'perda_fonte','limite_fonte'};  % etapa 1
%   cenarios_plot = {'carga_faixas','retorno_fonte'}; % etapa 2
%   cenarios_plot = {'carga_faixas','limite_fonte','perda_fonte','retorno_fonte'};

clc;
clear;
close all;

%% Configuração

% Etapa atual (editar conforme necessário)
if ~exist('cenarios_plot', 'var')
    cenarios_plot = {'perda_fonte', 'limite_fonte'};
end

pasta_atual = pwd;
[pasta_pai, nome_pasta] = fileparts(pasta_atual);
if strcmp(nome_pasta, '01_matlab_base')
    pasta_projeto = pasta_pai;
else
    pasta_projeto = pasta_atual;
end

pasta_res = fullfile(pasta_projeto, '05_resultados');
pasta_fig = fullfile(pasta_res, 'figuras_comparativas');
if ~exist(pasta_fig, 'dir')
    mkdir(pasta_fig);
end

%% Carregar resultados

H  = load(fullfile(pasta_res, 'resultados_heuristico_todos_cenarios.mat'));
V4 = load(fullfile(pasta_res, 'resultados_mpc_qp_v4_todos_cenarios.mat'));
V5 = load(fullfile(pasta_res, 'resultados_mpc_qp_v5_todos_cenarios.mat'));

resH  = H.resultados;
resV4 = V4.resultados;
resV5 = V5.resultados;

% Cores / estilos (legíveis em P&B e colorido)
cH  = [0.15 0.15 0.15];   % cinza escuro
cV4 = [0.00 0.45 0.74];   % azul
cV5 = [0.85 0.33 0.10];   % laranja-queimado
lw  = 1.6;

fprintf('Gerando figuras em:\n%s\n', pasta_fig);

for i_c = 1:numel(cenarios_plot)

    tipo = cenarios_plot{i_c};
    fprintf('\n=== %s ===\n', tipo);

    iH  = find(strcmp({resH.tipo_cenario},  tipo), 1);
    iV4 = find(strcmp({resV4.tipo_cenario}, tipo), 1);
    iV5 = find(strcmp({resV5.tipo_cenario}, tipo), 1);

    if isempty(iH) || isempty(iV4) || isempty(iV5)
        warning('Cenario %s incompleto nos .mat — pulando.', tipo);
        continue;
    end

    rH  = resH(iH);
    rV4 = resV4(iV4);
    rV5 = resV5(iV5);

    tmin = rV5.t / 60;
    nome = char(rV5.nome_cenario);

    %% Figura principal: 4 painéis

    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Name', tipo, 'Units', 'inches', 'Position', [1 1 8.5 9.5]);

    % 1) Carga e limite (referência do cenário — comum)
    subplot(4,1,1)
    plot(tmin, rV5.Pload, 'k-', 'LineWidth', lw); hold on
    plot(tmin, rV5.Psource_max, 'k--', 'LineWidth', 1.2);
    grid on
    ylabel('Potência [kW]')
    title(sprintf('%s — comparação Heurístico / V4 / V5', nome), ...
        'Interpreter', 'none')
    legend('P_{load}', 'P_{source,max}', 'Location', 'best')
    set(gca, 'FontSize', 10)

    % 2) PBESS
    subplot(4,1,2)
    plot(tmin, rH.PBESS,  '-',  'Color', cH,  'LineWidth', lw); hold on
    plot(tmin, rV4.PBESS, '-',  'Color', cV4, 'LineWidth', lw);
    plot(tmin, rV5.PBESS, '-',  'Color', cV5, 'LineWidth', lw);
    grid on
    ylabel('P_{BESS} [kW]')
    legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', 'Location', 'best')
    set(gca, 'FontSize', 10)

    % 3) Pnao
    subplot(4,1,3)
    plot(tmin, rH.Pnao_atendida,  '-', 'Color', cH,  'LineWidth', lw); hold on
    plot(tmin, rV4.Pnao_atendida, '-', 'Color', cV4, 'LineWidth', lw);
    plot(tmin, rV5.Pnao_atendida, '-', 'Color', cV5, 'LineWidth', lw);
    grid on
    ylabel('P_{não atend.} [kW]')
    legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', 'Location', 'best')
    set(gca, 'FontSize', 10)

    % 4) SOC
    subplot(4,1,4)
    plot(tmin, rH.SOC,  '-', 'Color', cH,  'LineWidth', lw); hold on
    plot(tmin, rV4.SOC, '-', 'Color', cV4, 'LineWidth', lw);
    plot(tmin, rV5.SOC, '-', 'Color', cV5, 'LineWidth', lw);
    grid on
    ylabel('SOC [%]')
    xlabel('Tempo [min]')
    legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', 'Location', 'best')
    set(gca, 'FontSize', 10)

    arq = fullfile(pasta_fig, sprintf('comp_%s_paineis.png', tipo));
    salvar_figura_png(fig, arq);
    close(fig);
    fprintf('Salvo: %s\n', arq);

    %% Zoom na falha (só perda / retorno)

    if strcmp(tipo, 'perda_fonte') || strcmp(tipo, 'retorno_fonte')

        idx0 = find(rV5.grid_status == 0, 1, 'first');
        t0 = rV5.t(idx0);
        t_a = max(0, t0 - 60);
        t_b = min(rV5.t(end), t0 + 180);
        mask = (rV5.t >= t_a) & (rV5.t <= t_b);
        tm = rV5.t(mask) / 60;

        figz = figure('Visible', 'off', 'Color', 'w', ...
            'Units', 'inches', 'Position', [1 1 8.5 6.5]);

        subplot(2,1,1)
        plot(tm, rH.PBESS(mask),  '-', 'Color', cH,  'LineWidth', lw); hold on
        plot(tm, rV4.PBESS(mask), '-', 'Color', cV4, 'LineWidth', lw);
        plot(tm, rV5.PBESS(mask), '-', 'Color', cV5, 'LineWidth', lw);
        xline(t0/60, 'k:', 'LineWidth', 1.2);
        grid on
        ylabel('P_{BESS} [kW]')
        title(sprintf('%s — zoom em torno da falha (t_f = %.0f s)', nome, t0), ...
            'Interpreter', 'none')
        legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', 'Início da falha', ...
            'Location', 'best')
        set(gca, 'FontSize', 10)

        subplot(2,1,2)
        plot(tm, rH.Pnao_atendida(mask),  '-', 'Color', cH,  'LineWidth', lw); hold on
        plot(tm, rV4.Pnao_atendida(mask), '-', 'Color', cV4, 'LineWidth', lw);
        plot(tm, rV5.Pnao_atendida(mask), '-', 'Color', cV5, 'LineWidth', lw);
        yline(350, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
        xline(t0/60, 'k:', 'LineWidth', 1.2);
        grid on
        ylabel('P_{não atend.} [kW]')
        xlabel('Tempo [min]')
        legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', ...
            'Piso físico (~350 kW)', 'Início da falha', 'Location', 'best')
        set(gca, 'FontSize', 10)

        arqz = fullfile(pasta_fig, sprintf('comp_%s_zoom_falha.png', tipo));
        salvar_figura_png(figz, arqz);
        close(figz);
        fprintf('Salvo: %s\n', arqz);
    end

    %% Zoom no degrau de carga (limite_fonte / carga_faixas)

    if strcmp(tipo, 'limite_fonte')
        t0 = 200; % degrau para 950 kW
        t_a = 150; t_b = 350;
        mask = (rV5.t >= t_a) & (rV5.t <= t_b);
        tm = rV5.t(mask) / 60;

        figz = figure('Visible', 'off', 'Color', 'w', ...
            'Units', 'inches', 'Position', [1 1 8.5 6.5]);

        subplot(2,1,1)
        plot(tm, rH.PBESS(mask),  '-', 'Color', cH,  'LineWidth', lw); hold on
        plot(tm, rV4.PBESS(mask), '-', 'Color', cV4, 'LineWidth', lw);
        plot(tm, rV5.PBESS(mask), '-', 'Color', cV5, 'LineWidth', lw);
        xline(t0/60, 'k:', 'LineWidth', 1.2);
        grid on
        ylabel('P_{BESS} [kW]')
        title(sprintf('%s — zoom no degrau de carga (t = %.0f s)', nome, t0), ...
            'Interpreter', 'none')
        legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', 'Degrau de carga', ...
            'Location', 'best')
        set(gca, 'FontSize', 10)

        subplot(2,1,2)
        plot(tm, rH.Pnao_atendida(mask),  '-', 'Color', cH,  'LineWidth', lw); hold on
        plot(tm, rV4.Pnao_atendida(mask), '-', 'Color', cV4, 'LineWidth', lw);
        plot(tm, rV5.Pnao_atendida(mask), '-', 'Color', cV5, 'LineWidth', lw);
        xline(t0/60, 'k:', 'LineWidth', 1.2);
        grid on
        ylabel('P_{não atend.} [kW]')
        xlabel('Tempo [min]')
        legend('Heurístico', 'MPC-QP-V4', 'MPC-QP-V5', 'Degrau de carga', ...
            'Location', 'best')
        set(gca, 'FontSize', 10)

        arqz = fullfile(pasta_fig, sprintf('comp_%s_zoom_degrau.png', tipo));
        salvar_figura_png(figz, arqz);
        close(figz);
        fprintf('Salvo: %s\n', arqz);
    end

end

fprintf('\nFIGURAS COMPARATIVAS CONCLUIDAS\n');

%% -------- função local --------
function salvar_figura_png(fig, caminho)
% Salva PNG de forma robusta em modo -batch (evita travar no exportgraphics).
set(fig, 'Renderer', 'painters');
set(fig, 'PaperPositionMode', 'auto');
try
    print(fig, caminho, '-dpng', '-r300');
catch
    saveas(fig, caminho);
end
end
