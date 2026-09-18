function gerar_figuras_revisao(resultados, pasta_out)
% Gera painéis comparativos Heur / Heur+FS / Miope / MPC.

cenarios_plot = {'carga_faixas', 'perda_fonte', 'multi_burst'};
mapas = {
    'heuristico', 'Heur'
    'heuristico_foresight', 'Heur+FS'
    'miope_qp', 'Miope'
    'mpc_qp_v5', 'MPC'
    };
cores = lines(4);

for ic = 1:numel(cenarios_plot)
    cen = cenarios_plot{ic};
    fig = figure('Visible', 'off', 'Position', [100 100 1100 900]);
    tem = false;
    labs_used = {};

    for j = 1:size(mapas, 1)
        key = matlab.lang.makeValidName(sprintf('%s__%s', cen, mapas{j,1}));
        if ~isfield(resultados, key)
            continue;
        end
        out = resultados.(key);
        tem = true;
        tmin = out.t / 60;
        c = cores(j, :);
        labs_used{end+1} = mapas{j,2}; %#ok<AGROW>

        subplot(5,1,1); hold on;
        if numel(labs_used) == 1
            plot(tmin, out.Pload, 'k-', 'LineWidth', 1.2);
            ylabel('P_{load} [kW]');
            title(strrep(cen, '_', '\_'));
        end

        subplot(5,1,2); hold on;
        plot(tmin, out.Psource, '-', 'Color', c, 'LineWidth', 1.1);
        ylabel('P_{source}');

        subplot(5,1,3); hold on;
        plot(tmin, out.PBESS, '-', 'Color', c, 'LineWidth', 1.1);
        ylabel('P_{BESS}');

        subplot(5,1,4); hold on;
        plot(tmin, out.SOC, '-', 'Color', c, 'LineWidth', 1.1);
        ylabel('SOC [%]');

        subplot(5,1,5); hold on;
        plot(tmin, out.Pnao_atendida, '-', 'Color', c, 'LineWidth', 1.1);
        ylabel('P_{nao}');
        xlabel('t [min]');
    end

    if tem
        subplot(5,1,2);
        legend(labs_used, 'Location', 'best');
        fn = fullfile(pasta_out, sprintf('fig_%s.png', cen));
        try
            print(fig, fn, '-dpng', '-r150');
        catch
            try
                exportgraphics(fig, fn, 'Resolution', 150);
            catch ME2
                warning('Falha ao salvar figura %s: %s', fn, ME2.message);
            end
        end
        fprintf('Figura salva: %s\n', fn);
    end
    close(fig);
end

end
