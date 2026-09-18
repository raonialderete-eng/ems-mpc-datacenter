function gerar_traces_revisao()
% Gera traces de 1200 s (Ts=1 s) na faixa 600-950 kW.
% Preferencia: dataset NLR/Vercellino em ../dataset/
%   1) nrel_facility_1200s.csv  <- DIPLOEE inference 1 MW, 40% util (1 min)
%   2) nrel_training_1200s.csv  <- NVML medido, Llama2-70B LoRA, 16 nos
% Fallback: reconstrucao (so se o dataset nao existir).

aqui = fileparts(mfilename('fullpath'));
pasta = fullfile(aqui, '..', '05_resultados', 'revisao_fase1', 'traces');
if ~exist(pasta, 'dir'), mkdir(pasta); end
backup_se_reconstrucao(pasta);
ds = fullfile(aqui, '..', 'dataset');

P_idle = 600;
P_high = 950;
Ts = 1;
t = (0:Ts:1200)';

ok_fac = false;
ok_tr = false;
if exist(ds, 'dir')
    try
        [p_fac, u_fac, info_fac] = trace_do_facility_diploe(ds, t, P_idle, P_high);
        ok_fac = true;
    catch ME
        warning('Facility DIPLOEE: %s', ME.message);
    end
    try
        [p_tr, u_tr, info_tr] = trace_do_treino_nvml(ds, t, P_idle, P_high);
        ok_tr = true;
    catch ME
        warning('Treino NVML: %s', ME.message);
    end
end

if ok_fac
    T = table(t, p_fac, u_fac, 'VariableNames', {'t_s','P_kW','gpu_util'});
    writetable(T, fullfile(pasta, 'nrel_facility_1200s.csv'));
    fprintf('NREL facility (dataset): %s\n', info_fac);
else
    warning('Facility: usando reconstrucao.');
    [p, u] = reconstrucao_nrel(t, P_idle, P_high);
    writetable(table(t, p, u, 'VariableNames', {'t_s','P_kW','gpu_util'}), ...
        fullfile(pasta, 'nrel_facility_1200s.csv'));
    info_fac = 'RECONSTRUCAO (dataset ausente/falhou)';
end

if ok_tr
    T = table(t, p_tr, u_tr, 'VariableNames', {'t_s','P_kW','gpu_util'});
    writetable(T, fullfile(pasta, 'nrel_training_1200s.csv'));
    % Segundo cenario do bloco 4 le alibaba_gpu_1200s.csv — agora e treino medido.
    writetable(T, fullfile(pasta, 'alibaba_gpu_1200s.csv'));
    fprintf('NREL training NVML (dataset): %s\n', info_tr);
else
    warning('Treino NVML: usando reconstrucao Alibaba.');
    [p, u] = reconstrucao_alibaba(t, P_idle, P_high);
    writetable(table(t, p, u, 'VariableNames', {'t_s','P_kW','gpu_util'}), ...
        fullfile(pasta, 'alibaba_gpu_1200s.csv'));
    info_tr = 'RECONSTRUCAO Alibaba (NVML falhou)';
end

fid = fopen(fullfile(pasta, 'README_TRACES.md'), 'w');
fprintf(fid, ['# Traces Fase 1 — fonte\n\n', ...
    'Ts=1 s, Tf=1200 s, faixa afinizada [%g, %g] kW (planta do artigo).\n\n', ...
    '## nrel_facility_1200s.csv\n%s\n\n', ...
    '## nrel_training_1200s.csv / alibaba_gpu_1200s.csv\n%s\n\n', ...
    'A afinizacao preserva a FORMA do sinal oficial para o EMS 600-950 kW.\n', ...
    'Citacao: Vercellino et al., arXiv:2604.07345; NLR DOI 10.7799/3025227.\n'], ...
    P_idle, P_high, info_fac, info_tr);
fclose(fid);
fprintf('Traces em %s\n', pasta);
end

function [p, u, info] = trace_do_facility_diploe(ds, t, P_idle, P_high)
csv = fullfile(ds, '03_whole-facility_profiles', 'inference', 'simulated_data', ...
    'inference_1MW_283nodes_40u_power.csv');
if ~exist(csv, 'file')
    error('CSV facility nao encontrado: %s', csv);
end
fid = fopen(csv, 'r');
if fid < 0
    error('Nao abriu %s', csv);
end
fgetl(fid);
C = textscan(fid, '%s %f %f', 'Delimiter', ',', 'CollectOutput', false);
fclose(fid);
P = C{2};  % Watt (instalacao DIPLOEE ~0.25-0.80 MW)
n = numel(P);
win = 21;  % 21 amostras de 1 min cobrem 1200 s
if n < win
    error('Facility CSV curto demais (%d linhas).', n);
end
Pmax = movmax(P, [0 win-1]);
Pmin = movmin(P, [0 win-1]);
rg = Pmax - Pmin;
rg(n-win+2:end) = 0;
[rg_max, i0] = max(rg);
idx = i0:(i0+win-1);
Pwin = P(idx);
t_min = (0:win-1)' * 60;
p_1s = interp1(t_min, Pwin, t, 'linear', Pwin(end));
[p, u] = afinizar(p_1s, P_idle, P_high);
info = sprintf(['DIPLOEE inference_1MW 40%% util, janela 20 min indice %d, ', ...
    'P_raw=[%.0f, %.0f] W, range_janela=%.0f W. Interpolado 1 min -> 1 s.'], ...
    i0, min(Pwin), max(Pwin), rg_max);
end

function [p, u, info] = trace_do_treino_nvml(ds, t, P_idle, P_high)
pasta = fullfile(ds, '00_raw_datasets', 'training_llama2_70b_lora', '16node');
d = dir(fullfile(pasta, 'nvml_wattameter_emissions_parsed_slurmid_10742842_*.log'));
if isempty(d)
    error('Logs NVML slurmid 10742842 nao encontrados.');
end
fprintf('NVML: %d nos (slurmid 10742842)\n', numel(d));
tk_all = {};
Pk_all = {};
t_start = NaT;
t_end = NaT;
n_ok = 0;
for k = 1:numel(d)
    [tk, Pk] = ler_nvml(fullfile(d(k).folder, d(k).name));
    if isempty(tk)
        continue;
    end
    n_ok = n_ok + 1;
    tk_all{n_ok} = tk; %#ok<AGROW>
    Pk_all{n_ok} = Pk; %#ok<AGROW>
    if isnat(t_start)
        t_start = tk(1);
        t_end = tk(end);
    else
        t_start = max(t_start, tk(1));
        t_end = min(t_end, tk(end));
    end
end
dur = seconds(t_end - t_start);
if n_ok < 1 || dur < 200
    error('Sobreposicao NVML curta (%.1f s, %d nos).', dur, n_ok);
end
grid_s = (0:1:floor(dur))';
Psum = zeros(size(grid_s));
for k = 1:n_ok
    dtk = seconds(tk_all{k} - t_start);
    Pk1 = interp1(dtk, Pk_all{k}, grid_s, 'linear', 0);
    Pk1(isnan(Pk1)) = 0;
    Psum = Psum + Pk1;
end
win = min(numel(t), numel(Psum));
if numel(Psum) < win
    error('Serie NVML < 1200 s.');
end
Pmax = movmax(Psum, [0 win-1]);
Pmin = movmin(Psum, [0 win-1]);
rg = Pmax - Pmin;
rg((numel(Psum)-win+2):end) = 0;
[rg_max, i0] = max(rg);
seg = Psum(i0:min(i0+win-1, numel(Psum)));
if numel(seg) < numel(t)
    seg(end+1:numel(t), 1) = seg(end);
end
seg = seg(1:numel(t));
[p, u] = afinizar(seg, P_idle, P_high);
info = sprintf(['NVML medido Llama2-70B LoRA, %d nos, slurmid 10742842, ', ...
    'janela i0=%d, P_raw=[%.0f, %.0f] W (soma GPU), range=%.0f W.'], ...
    n_ok, i0, min(seg), max(seg), rg_max);
end

function [tk, Pk] = ler_nvml(path)
fid = fopen(path, 'r');
if fid < 0
    tk = []; Pk = [];
    return;
end
C = textscan(fid, '%s %f %f %f %f %f %f %f %f %f', 'CommentStyle', '#');
fclose(fid);
if isempty(C{1})
    tk = []; Pk = [];
    return;
end
ts = strtrim(C{1});
try
    tk = datetime(ts, 'InputFormat', 'yyyy-MM-dd_HH:mm:ss.SSSSSS');
catch
    tk = datetime(strrep(ts, '_', ' '), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSSSSS');
end
Pk = (C{3} + C{4} + C{5} + C{6}) * 1e-3;  % mW -> W (4 GPUs)
ok = ~isnat(tk) & ~isnan(Pk);
tk = tk(ok);
Pk = Pk(ok);
end

function backup_se_reconstrucao(pasta)
src = fullfile(pasta, 'README_TRACES.md');
if ~exist(src, 'file')
    return;
end
txt = fileread(src);
if contains(txt, 'reconstrucao', 'IgnoreCase', true) || contains(txt, 'Alibaba')
    dst_dir = fullfile(pasta, 'reconstrucao');
    if ~exist(dst_dir, 'dir'), mkdir(dst_dir); end
    nomes = {'nrel_facility_1200s.csv','alibaba_gpu_1200s.csv','README_TRACES.md'};
    for i = 1:numel(nomes)
        f = fullfile(pasta, nomes{i});
        if exist(f, 'file')
            copyfile(f, fullfile(dst_dir, nomes{i}));
        end
    end
end
end

function [p, u] = afinizar(praw, P_idle, P_high)
praw = double(praw(:));
pmin = min(praw);
pmax = max(praw);
if pmax > pmin + 1e-9
    u = (praw - pmin) / (pmax - pmin);
else
    u = 0.5 * ones(size(praw));
end
p = P_idle + (P_high - P_idle) * u;
end

function [p, u] = reconstrucao_nrel(t, P_idle, P_high)
rng(20260907, 'twister');
u = 0.12 * ones(size(t));
u(t >= 80 & t < 520) = 0.72;
u(t >= 180 & t < 520) = 0.88;
u(t >= 300 & t < 480) = 0.96;
u(t >= 360 & t < 375) = 0.45;
bursts = [560 590 0.92; 620 640 0.78; 700 730 0.95; 780 800 0.70; 880 910 0.90; 980 1005 0.82];
for i = 1:size(bursts,1)
    u(t >= bursts(i,1) & t < bursts(i,2)) = bursts(i,3);
end
tail = t >= 1050 & t < 1180;
u(tail) = 0.20 + 0.08 * sin(2*pi*(t(tail)-1050)/60);
u = min(max(u + 0.015*randn(size(t)), 0), 1);
p = P_idle + (P_high - P_idle) * u;
end

function [p, u] = reconstrucao_alibaba(t, P_idle, P_high)
rng(20260908, 'twister');
u = 0.08 * ones(size(t));
jobs = [40 160 0.18; 160 420 0.91; 260 290 0.35; 450 510 0.55; ...
        530 610 0.22; 640 820 0.87; 850 880 0.40; 900 960 0.73; 1020 1100 0.28];
for i = 1:size(jobs,1)
    idx = t >= jobs(i,1) & t < jobs(i,2);
    u(idx) = max(u(idx), jobs(i,3));
end
for a = [70 200 335 670 940 1075]
    idx = t >= a & t < a+12;
    u(idx) = max(u(idx), 0.98);
end
u = min(max(u + 0.02*randn(size(t)), 0), 1);
p = P_idle + (P_high - P_idle) * u;
end
