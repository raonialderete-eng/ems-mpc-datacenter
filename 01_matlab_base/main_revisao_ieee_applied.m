%% MAIN_REVISAO_IEEE_APPLIED
% Pacote mínimo IEEE Applied (sem HIL):
%   0) Audit planta / preditor SOC
%   1) Comparação Heur | Heur+FS | Míope | MPC±FS (4 cenários + multi_burst)
%   2) Erro de previsão (magnitude e deslocamento temporal) em perda_fonte
%   3) Log de plataforma computacional
%
% Saídas: 05_resultados/revisao_ieee_applied/
% Checkpoint: retoma casos já salvos em 01_checkpoint.mat / CSV parcial.

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
if ~exist(pasta_out, 'dir')
    mkdir(pasta_out);
end

ckpt_file = fullfile(pasta_out, '01_checkpoint.mat');
csv_cmp = fullfile(pasta_out, '01_comparacao_controladores.csv');

log_file = fullfile(pasta_out, 'revisao_log.txt');
retomando = exist(ckpt_file, 'file') == 2;
if ~retomando && exist(log_file, 'file')
    delete(log_file);
end
diary(log_file);
diary on;

fprintf('========================================\n');
fprintf('REVISAO IEEE APPLIED - %s\n', datestr(now));
fprintf('Saida: %s\n', pasta_out);
if retomando
    fprintf('MODO: RETOMADA a partir de checkpoint\n');
else
    fprintf('MODO: EXECUCAO COMPLETA\n');
end
fprintf('========================================\n');

%% Plataforma
plat = struct();
plat.matlab_version = version;
plat.computer = computer;
try
    if ispc
        [~, cpu] = system('wmic cpu get name');
        plat.cpu = strtrim(cpu);
    else
        plat.cpu = 'n/a';
    end
catch
    plat.cpu = 'n/a';
end
plat.quadprog_algorithm = 'interior-point-convex';
plat.MaxIterations_mpc = 250;
plat.Ts = 1;
save(fullfile(pasta_out, '00_plataforma.mat'), 'plat');
fid = fopen(fullfile(pasta_out, '00_plataforma.txt'), 'w');
fprintf(fid, 'MATLAB: %s\nComputer: %s\nCPU:\n%s\nAlgorithm: %s\nMaxIter MPC: %d\n', ...
    plat.matlab_version, plat.computer, plat.cpu, plat.quadprog_algorithm, plat.MaxIterations_mpc);
fclose(fid);

param0 = parametros();
t0 = tic;

%% 0) Audit
audit_mat = fullfile(pasta_out, '00_audit_consistencia.mat');
if exist(audit_mat, 'file')
    fprintf('\n##### 0) AUDIT CONSISTENCIA (cache) #####\n');
    S = load(audit_mat, 'rel_audit'); %#ok<NASGU>
else
    fprintf('\n##### 0) AUDIT CONSISTENCIA #####\n');
    rel_audit = audit_consistencia_planta(param0);
    save(audit_mat, 'rel_audit');
end

%% Carrega checkpoint
linhas = {};
resultados = struct();
feitos = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if exist(ckpt_file, 'file')
    C = load(ckpt_file);
    if isfield(C, 'linhas'), linhas = C.linhas; end
    if isfield(C, 'resultados'), resultados = C.resultados; end
    if isfield(C, 'feitos_keys')
        for ii = 1:numel(C.feitos_keys)
            feitos(C.feitos_keys{ii}) = true;
        end
    end
    fprintf('Checkpoint: %d casos ja concluidos\n', feitos.Count);
end

%% 1) Comparação de controladores
fprintf('\n##### 1) COMPARACAO CONTROLADORES #####\n');

cenarios = {'carga_faixas','limite_fonte','perda_fonte','retorno_fonte','multi_burst'};
controles = {'heuristico','heuristico_foresight','miope_qp','mpc_qp_v5'};

for ic = 1:numel(cenarios)
    for it = 1:numel(controles)
        tipo_c = cenarios{ic};
        tipo_t = controles{it};
        keyv = matlab.lang.makeValidName(sprintf('%s__%s', tipo_c, tipo_t));

        if feitos.isKey(keyv) && feitos(keyv)
            fprintf('\n--- %s | %s --- [SKIP checkpoint]\n', tipo_c, tipo_t);
            continue;
        end

        param = param0;
        param.Tf = 1200;
        param.mpc_foresight_grid = true;
        param.mpc_foresight_load = true;

        fprintf('\n--- %s | %s ---\n', tipo_c, tipo_t);
        out = simular_ems(tipo_t, tipo_c, param);
        resultados.(keyv) = out;
        m = out.metricas;
        linhas(end+1,:) = {tipo_c, out.nome_controle, ...
            m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
            m.tempo_com_carga_nao_atendida_s, m.SOC_final, m.SOC_minimo, ...
            m.SOC_no_evento, m.Energia_throughput_kWh, m.N_EFC, ...
            m.rampa_fonte_max, out.percentual_fallback, ...
            out.tempo_qp_medio_s, out.tempo_qp_max_s, out.tempo_wall_s}; %#ok<SAGROW>
        feitos(keyv) = true;

        feitos_keys = feitos.keys; %#ok<NASGU>
        save(ckpt_file, 'linhas', 'resultados', 'feitos_keys', '-v7.3');
        tab_tmp = cell2table(linhas, 'VariableNames', { ...
            'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_nao_s', ...
            'SOC_final','SOC_min','SOC_evento','Throughput_kWh','EFC', ...
            'Rampa_fonte_max','Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});
        writetable(tab_tmp, csv_cmp);
        fprintf('  checkpoint OK (%s) wall=%.1fs\n', keyv, out.tempo_wall_s);
    end
end

% MPC sem foresight
for tipo_c_cell = {'perda_fonte','multi_burst','carga_faixas'}
    tipo_c = tipo_c_cell{1};
    keyv = matlab.lang.makeValidName(sprintf('%s__mpc_fs_off', tipo_c));
    if feitos.isKey(keyv) && feitos(keyv)
        fprintf('\n--- %s | MPC-FS-OFF --- [SKIP checkpoint]\n', tipo_c);
        continue;
    end

    param = param0;
    param.Tf = 1200;
    param.mpc_foresight_grid = false;
    param.mpc_foresight_load = false;
    fprintf('\n--- %s | MPC-FS-OFF ---\n', tipo_c);
    out = simular_ems('mpc_qp_v5', tipo_c, param);
    out.nome_controle = 'MPC-FS-OFF';
    resultados.(keyv) = out;
    m = out.metricas;
    linhas(end+1,:) = {tipo_c, 'MPC-FS-OFF', ...
        m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
        m.tempo_com_carga_nao_atendida_s, m.SOC_final, m.SOC_minimo, ...
        m.SOC_no_evento, m.Energia_throughput_kWh, m.N_EFC, ...
        m.rampa_fonte_max, out.percentual_fallback, ...
        out.tempo_qp_medio_s, out.tempo_qp_max_s, out.tempo_wall_s}; %#ok<SAGROW>
    feitos(keyv) = true;
    feitos_keys = feitos.keys; %#ok<NASGU>
    save(ckpt_file, 'linhas', 'resultados', 'feitos_keys', '-v7.3');
    tab_tmp = cell2table(linhas, 'VariableNames', { ...
        'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_nao_s', ...
        'SOC_final','SOC_min','SOC_evento','Throughput_kWh','EFC', ...
        'Rampa_fonte_max','Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});
    writetable(tab_tmp, csv_cmp);
    fprintf('  checkpoint OK (%s) wall=%.1fs\n', keyv, out.tempo_wall_s);
end

tab_cmp = cell2table(linhas, 'VariableNames', { ...
    'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','T_nao_s', ...
    'SOC_final','SOC_min','SOC_evento','Throughput_kWh','EFC', ...
    'Rampa_fonte_max','Fallback_pct','t_qp_med_s','t_qp_max_s','t_wall_s'});
writetable(tab_cmp, csv_cmp);
save(fullfile(pasta_out, '01_comparacao_controladores.mat'), 'tab_cmp', 'resultados', '-v7.3');
disp(tab_cmp);

%% 2) Erro de previsão (perda_fonte)
fprintf('\n##### 2) ERRO DE PREVISAO #####\n');

param = param0;
param.Tf = 1200;
t = 0:param.Ts:param.Tf;
[Pload_true, Pmax_true, grid_true] = gera_cenario(t, 'perda_fonte', param);

err_mat = fullfile(pasta_out, '02_erro_previsao.mat');
if exist(err_mat, 'file')
    E = load(err_mat);
    tab_mag = E.tab_mag; %#ok<NASGU>
    tab_shift = E.tab_shift; %#ok<NASGU>
    fprintf('Erro de previsao: cache carregado\n');
else
    mags = [0, -0.10, 0.10, -0.20, 0.20];
    linhas_m = {};
    for im = 1:numel(mags)
        err = mags(im);
        Pload_fcst = Pload_true * (1 + err);
        param_e = param;
        param_e.Pload_forecast = Pload_fcst;
        param_e.grid_forecast = grid_true;
        param_e.Psource_max_forecast = Pmax_true;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param_e);
        m = out.metricas;
        linhas_m(end+1,:) = {err*100, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
            m.SOC_no_evento, m.Energia_throughput_kWh, out.percentual_fallback}; %#ok<SAGROW>
        fprintf('mag %+5.1f%% -> Pnao_max=%.2f Enao=%.3f\n', err*100, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh);
        tab_mag = cell2table(linhas_m, 'VariableNames', ...
            {'Erro_mag_pct','Pnao_max_kW','Energia_nao_kWh','SOC_evento','Throughput_kWh','Fallback_pct'});
        writetable(tab_mag, fullfile(pasta_out, '02_erro_magnitude.csv'));
    end

    shifts = [-10, 0, 10];
    linhas_t = {};
    for ish = 1:numel(shifts)
        sh = shifts(ish);
        grid_fcst = ones(size(grid_true));
        t_ini = 500 + sh;
        t_fim = 650 + sh;
        grid_fcst(t >= t_ini & t < t_fim) = 0;
        Pmax_fcst = param.Psource_max_nominal * grid_fcst;
        param_e = param;
        param_e.Pload_forecast = Pload_true;
        param_e.grid_forecast = grid_fcst;
        param_e.Psource_max_forecast = Pmax_fcst;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param_e);
        m = out.metricas;
        linhas_t(end+1,:) = {sh, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh, ...
            m.SOC_no_evento, out.percentual_fallback}; %#ok<SAGROW>
        fprintf('shift %+d s -> Pnao_max=%.2f Enao=%.3f\n', sh, m.Pnao_atendida_max, m.Energia_nao_atendida_kWh);
        tab_shift = cell2table(linhas_t, 'VariableNames', ...
            {'Shift_s','Pnao_max_kW','Energia_nao_kWh','SOC_evento','Fallback_pct'});
        writetable(tab_shift, fullfile(pasta_out, '02_erro_temporal.csv'));
    end
    save(err_mat, 'tab_mag', 'tab_shift');
end

%% 3) Foresight ON/OFF + Nprep + tau
fprintf('\n##### 3) FORESIGHT / Nprep / tau #####\n');
sens_mat = fullfile(pasta_out, '03_sensibilidades.mat');
if exist(sens_mat, 'file')
    fprintf('Sensibilidades: cache carregado\n');
else
    param = param0; param.Tf = 1200;
    param.mpc_foresight_grid = true; param.mpc_foresight_load = true;
    out_on = simular_ems('mpc_qp_v5', 'perda_fonte', param);
    param.mpc_foresight_grid = false;
    out_off = simular_ems('mpc_qp_v5', 'perda_fonte', param);
    tab_fs = table(["ON";"OFF"], ...
        [out_on.metricas.Pnao_atendida_max; out_off.metricas.Pnao_atendida_max], ...
        [out_on.metricas.Energia_nao_atendida_kWh; out_off.metricas.Energia_nao_atendida_kWh], ...
        [out_on.metricas.SOC_final; out_off.metricas.SOC_final], ...
        [out_on.percentual_fallback; out_off.percentual_fallback], ...
        [out_on.tempo_qp_medio_s; out_off.tempo_qp_medio_s], ...
        [out_on.tempo_qp_max_s; out_off.tempo_qp_max_s], ...
        'VariableNames', {'Foresight','Pnao_max_kW','Energia_nao_kWh','SOC_final','Fallback_pct','t_qp_med','t_qp_max'});
    writetable(tab_fs, fullfile(pasta_out, '03_foresight_on_off.csv'));

    lista_Nprep = [0, 10, 20, 30, 45];
    linhas_n = {};
    for i = 1:numel(lista_Nprep)
        param = param0; param.Tf = 1200;
        param.Nprep_evento_mpc = lista_Nprep(i);
        param.mpc_foresight_grid = true; param.mpc_foresight_load = true;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
        linhas_n(end+1,:) = {lista_Nprep(i), out.metricas.Pnao_atendida_max, ...
            out.metricas.Energia_nao_atendida_kWh, out.percentual_fallback, out.tempo_qp_medio_s}; %#ok<SAGROW>
        tab_N = cell2table(linhas_n, 'VariableNames', {'Nprep','Pnao_max_kW','Energia_nao_kWh','Fallback_pct','t_qp_med'});
        writetable(tab_N, fullfile(pasta_out, '03_sensibilidade_Nprep.csv'));
    end

    lista_tau = [1, 2, 4];
    linhas_tau = {};
    for i = 1:numel(lista_tau)
        param = param0; param.Tf = 1200;
        param.tau_b = lista_tau(i);
        param.ab = exp(-param.Ts/param.tau_b);
        param.bb = 1 - param.ab;
        param.mpc_foresight_grid = true; param.mpc_foresight_load = true;
        out = simular_ems('mpc_qp_v5', 'perda_fonte', param);
        linhas_tau(end+1,:) = {lista_tau(i), out.metricas.Pnao_atendida_max, ...
            out.metricas.Energia_nao_atendida_kWh, out.percentual_fallback, out.tempo_qp_medio_s}; %#ok<SAGROW>
        tab_tau = cell2table(linhas_tau, 'VariableNames', {'tau_b','Pnao_max_kW','Energia_nao_kWh','Fallback_pct','t_qp_med'});
        writetable(tab_tau, fullfile(pasta_out, '03_sensibilidade_tau.csv'));
    end
    save(sens_mat, 'tab_fs', 'tab_N', 'tab_tau', 'out_on', 'out_off', '-v7.3');
end

%% Figuras-chave
fprintf('\n##### 4) FIGURAS #####\n');
try
    gerar_figuras_revisao(resultados, pasta_out);
catch ME
    warning('Figuras: %s', ME.message);
end

elapsed = toc(t0);
fid = fopen(fullfile(pasta_out, 'ESTUDO_CONCLUIDO.txt'), 'w');
fprintf(fid, 'Revisao IEEE Applied concluida em %s\nTempo total: %.1f s (%.1f min)\n', ...
    datestr(now), elapsed, elapsed/60);
fclose(fid);

fprintf('\nCONCLUIDO em %.1f min\n', elapsed/60);
diary off;
