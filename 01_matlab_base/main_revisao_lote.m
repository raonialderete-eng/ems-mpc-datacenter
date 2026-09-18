%% MAIN_REVISAO_LOTE
% Estudo IEEE Applied em lotes com salvamento incremental.
% Uso: main_revisao_lote   (continua de onde parou)

clc;
clear;
close all;

pasta_atual = pwd;
[pasta_pai, nome_pasta] = fileparts(pasta_atual);
if strcmp(nome_pasta, '01_matlab_base')
    pasta_projeto = pasta_pai;
else
    pasta_projeto = pasta_atual;
    addpath(fullfile(pasta_projeto, '01_matlab_base'));
    cd(fullfile(pasta_projeto, '01_matlab_base'));
end

pasta_out = fullfile(pasta_projeto, '05_resultados', 'revisao_ieee_applied');
if ~exist(pasta_out, 'dir'), mkdir(pasta_out); end

checkpoint = fullfile(pasta_out, 'checkpoint.mat');
csv_cmp = fullfile(pasta_out, '01_comparacao_controladores.csv');

param0 = parametros();
param0.Tf = 1200;

% Jobs: {cenario, controle, foresight_grid, foresight_load, tag}
jobs = {};
cenarios = {'carga_faixas','limite_fonte','perda_fonte','retorno_fonte','multi_burst'};
controles = {'heuristico','heuristico_foresight','miope_qp','mpc_qp_v5'};
for ic = 1:numel(cenarios)
    for it = 1:numel(controles)
        jobs(end+1,:) = {cenarios{ic}, controles{it}, true, true, controles{it}}; %#ok<SAGROW>
    end
end
% MPC foresight OFF
for c = {'perda_fonte','carga_faixas','multi_burst'}
    jobs(end+1,:) = {c{1}, 'mpc_qp_v5', false, false, 'mpc_fs_off'}; %#ok<SAGROW>
end

if exist(checkpoint, 'file')
    S = load(checkpoint);
    feitos = S.feitos;
    linhas = S.linhas;
    resultados = S.resultados;
    fprintf('Retomando: %d jobs ja feitos\n', numel(feitos));
else
    feitos = {};
    linhas = {};
    resultados = struct();
end

diary(fullfile(pasta_out, 'revisao_lote_log.txt'));
fprintf('LOTE INICIO %s | total jobs=%d\n', datestr(now), size(jobs,1));

for j = 1:size(jobs,1)
    tag = sprintf('%s__%s', jobs{j,1}, jobs{j,5});
    if any(strcmp(feitos, tag))
        fprintf('SKIP %s\n', tag);
        continue;
    end

    param = param0;
    param.mpc_foresight_grid = jobs{j,3};
    param.mpc_foresight_load = jobs{j,4};

    fprintf('\n=== [%d/%d] %s | %s ===\n', j, size(jobs,1), jobs{j,1}, jobs{j,5});
    t1 = tic;
    out = simular_ems(jobs{j,2}, jobs{j,1}, param);
    fprintf('wall=%.1fs Pnao=%.2f Enao=%.3f FB=%.2f%% tqp=%.3f\n', ...
        toc(t1), out.metricas.Pnao_atendida_max, out.metricas.Energia_nao_atendida_kWh, ...
        out.percentual_fallback, out.tempo_qp_medio_s);

    key = matlab.lang.makeValidName(tag);
    resultados.(key) = out;
    m = out.metricas;
    nome = out.nome_controle;
    if strcmp(jobs{j,5}, 'mpc_fs_off'), nome = 'MPC-FS-OFF'; end
    linhas(end+1,:) = {jobs{j,1}, nome, ...
        m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
        m.tempo_com_carga_nao_atendida_s, m.SOC_final, m.SOC_minimo, ...
        m.SOC_no_evento, m.Energia_throughput_kWh, m.N_EFC, ...
        m.rampa_fonte_max, out.percentual_fallback, ...
        out.tempo_qp_medio_s, out.tempo_qp_max_s, out.tempo_wall_s}; %#ok<SAGROW>
    feitos{end+1} = tag; %#ok<SAGROW>

    tab_cmp = cell2table(linhas, 'VariableNames', { ...
        'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_nao_s', ...
        'SOC_final','SOC_min','SOC_evento','Throughput_kWh','EFC', ...
        'Rampa_fonte_max','Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});
    writetable(tab_cmp, csv_cmp);
    save(checkpoint, 'feitos', 'linhas', 'resultados', 'tab_cmp');
end

%% Erro de previsao (perda_fonte)
fcst_file = fullfile(pasta_out, '02_erro_previsao.mat');
if ~exist(fcst_file, 'file')
    fprintf('\n##### ERRO DE PREVISAO #####\n');
    param = param0;
    t = 0:param.Ts:param.Tf;
    [Pload_true, Pmax_true, grid_true] = gera_cenario(t, 'perda_fonte', param);

    mags = [0, -0.10, 0.10, -0.20, 0.20];
    linhas_m = {};
    for im = 1:numel(mags)
        err = mags(im);
        param_e = param;
        param_e.Pload_forecast = Pload_true * (1 + err);
        param_e.grid_forecast = grid_true;
        param_e.Psource_max_forecast = Pmax_true;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param_e);
        m = out.metricas;
        linhas_m(end+1,:) = {err*100, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
            m.SOC_no_evento, m.Energia_throughput_kWh, out.percentual_fallback}; %#ok<SAGROW>
        fprintf('mag %+5.1f%% -> Pnao=%.2f\n', err*100, m.Pnao_atendida_max);
    end
    tab_mag = cell2table(linhas_m, 'VariableNames', ...
        {'Erro_mag_pct','Pnao_max_kW','Energia_nao_kWh','SOC_evento','Throughput_kWh','Fallback_pct'});
    writetable(tab_mag, fullfile(pasta_out, '02_erro_magnitude.csv'));

    shifts = [-10, 0, 10];
    linhas_t = {};
    for ish = 1:numel(shifts)
        sh = shifts(ish);
        grid_fcst = ones(size(grid_true));
        grid_fcst(t >= (500+sh) & t < (650+sh)) = 0;
        param_e = param;
        param_e.Pload_forecast = Pload_true;
        param_e.grid_forecast = grid_fcst;
        param_e.Psource_max_forecast = param.Psource_max_nominal * grid_fcst;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param_e);
        m = out.metricas;
        linhas_t(end+1,:) = {sh, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
            m.SOC_no_evento, out.percentual_fallback}; %#ok<SAGROW>
        fprintf('shift %+d s -> Pnao=%.2f\n', sh, m.Pnao_atendida_max);
    end
    tab_shift = cell2table(linhas_t, 'VariableNames', ...
        {'Shift_s','Pnao_max_kW','Energia_nao_kWh','SOC_evento','Fallback_pct'});
    writetable(tab_shift, fullfile(pasta_out, '02_erro_temporal.csv'));
    save(fcst_file, 'tab_mag', 'tab_shift');
end

%% Sensibilidades enxutas
sens_file = fullfile(pasta_out, '03_sensibilidades.mat');
if ~exist(sens_file, 'file')
    fprintf('\n##### SENSIBILIDADES #####\n');
    param = param0; param.mpc_foresight_grid = true; param.mpc_foresight_load = true;
    out_on = simular_ems('mpc_qp_v5', 'perda_fonte', param);
    param.mpc_foresight_grid = false;
    out_off = simular_ems('mpc_qp_v5', 'perda_fonte', param);
    tab_fs = table(["ON";"OFF"], ...
        [out_on.metricas.Pnao_atendida_max; out_off.metricas.Pnao_atendida_max], ...
        [out_on.metricas.Energia_nao_atendida_kWh; out_off.metricas.Energia_nao_atendida_kWh], ...
        [out_on.tempo_qp_medio_s; out_off.tempo_qp_medio_s], ...
        [out_on.tempo_qp_max_s; out_off.tempo_qp_max_s], ...
        'VariableNames', {'Foresight','Pnao_max_kW','Energia_nao_kWh','t_qp_med','t_qp_max'});
    writetable(tab_fs, fullfile(pasta_out, '03_foresight_on_off.csv'));

    lista_Nprep = [0, 10, 30, 45];
    linhas_n = {};
    for i = 1:numel(lista_Nprep)
        param = param0; param.Nprep_evento_mpc = lista_Nprep(i);
        param.mpc_foresight_grid = true; param.mpc_foresight_load = true;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
        linhas_n(end+1,:) = {lista_Nprep(i), out.metricas.Pnao_atendida_max, ...
            out.metricas.Energia_nao_atendida_kWh, out.tempo_qp_medio_s}; %#ok<SAGROW>
    end
    tab_N = cell2table(linhas_n, 'VariableNames', {'Nprep','Pnao_max_kW','Energia_nao_kWh','t_qp_med'});
    writetable(tab_N, fullfile(pasta_out, '03_sensibilidade_Nprep.csv'));

    lista_tau = [1, 2, 4];
    linhas_tau = {};
    for i = 1:numel(lista_tau)
        param = param0; param.tau_b = lista_tau(i);
        param.ab = exp(-param.Ts/param.tau_b); param.bb = 1 - param.ab;
        param.mpc_foresight_grid = true; param.mpc_foresight_load = true;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
        linhas_tau(end+1,:) = {lista_tau(i), out.metricas.Pnao_atendida_max, ...
            out.metricas.Energia_nao_atendida_kWh, out.percentual_fallback, out.tempo_qp_medio_s}; %#ok<SAGROW>
    end
    tab_tau = cell2table(linhas_tau, 'VariableNames', {'tau_b','Pnao_max_kW','Energia_nao_kWh','Fallback_pct','t_qp_med'});
    writetable(tab_tau, fullfile(pasta_out, '03_sensibilidade_tau.csv'));
    save(sens_file, 'tab_fs', 'tab_N', 'tab_tau', 'out_on', 'out_off');
end

%% Figuras
try
    if exist(checkpoint, 'file')
        S = load(checkpoint);
        gerar_figuras_revisao(S.resultados, pasta_out);
    end
catch ME
    warning('%s', ME.message);
end

% Plataforma
plat = struct('matlab_version', version, 'computer', computer, ...
    'quadprog_algorithm', 'interior-point-convex', 'MaxIterations_mpc', 150);
save(fullfile(pasta_out, '00_plataforma.mat'), 'plat');

fid = fopen(fullfile(pasta_out, 'ESTUDO_CONCLUIDO.txt'), 'w');
fprintf(fid, 'Concluido %s\n', datestr(now));
fclose(fid);
fprintf('\nLOTE CONCLUIDO %s\n', datestr(now));
diary off;
