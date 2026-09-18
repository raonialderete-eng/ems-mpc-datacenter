function out = hil_loop_de2115(varargin)
% HIL_LOOP_DE2115
% Planta e cenario no MATLAB; controlador na FPGA / SIL / exe C.
%
%   out = hil_loop_de2115('backend','matlab_fpga','cenario','perda_fonte')
%   out = hil_loop_de2115('backend','serial','porta','COM3')
%   out = hil_loop_de2115('backend','c_exe','exe','../07_fpga/c_golden/ems_golden.exe')

p = inputParser;
addParameter(p, 'backend', 'matlab_fpga');
addParameter(p, 'cenario', 'carga_faixas');
addParameter(p, 'controle', 'mpc');  % heur | heur_fs | mpc
addParameter(p, 'porta', 'COM3');
addParameter(p, 'baud', 115200);
addParameter(p, 'exe', fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    '07_fpga', 'c_golden', 'ems_golden.exe'));
addParameter(p, 'param', []);
parse(p, varargin{:});
opt = p.Results;

if isempty(opt.param)
    param = parametros_fpga();
else
    param = opt.param;
end

t = 0:param.Ts:param.Tf;
N = numel(t);
Np = param.Np_mpc;
[Pload, Psource_max, grid_status, nome] = gera_cenario(t, opt.cenario, param);

SOC = zeros(1, N); PBESS = zeros(1, N); PBESS_ref = zeros(1, N);
Psource = zeros(1, N); Pnao = zeros(1, N);
t_us = nan(1, N); exitflags = nan(1, N); fallback = false(1, N); evento = false(1, N);
SOC(1) = param.SOC_ref;

ser = [];
proc = [];
cleanup = onCleanup(@() hil_fechar(ser, proc)); %#ok<NASGU>

switch opt.backend
    case 'serial'
        ser = serialport(opt.porta, opt.baud);
        configureTerminator(ser, 'LF');
        % ADMM no Nios pode passar de 10 s/passo; heuristico responde ja.
        ser.Timeout = 1200;
        pause(0.3);
        flush(ser);
    case 'c_exe'
        if ~isfile(opt.exe)
            error(['Exe C nao encontrado: %s\n' ...
                'Compile no lab: cd 07_fpga/c_golden && make'], opt.exe);
        end
        proc = hil_abrir_exe(opt.exe, opt.controle);
    case 'matlab_fpga'
        clear_mpc_qp_fpga_cache();
    otherwise
        error('backend desconhecido: %s', opt.backend);
end

n_overrun = 0;
t_wall = tic;
for k = 1:N-1
    if k == 1
        uref = 0;
        Psrc_ant = Pload(k);
    else
        uref = PBESS_ref(k-1);
        Psrc_ant = Psource(k-1);
    end
    idx = k:min(k + Np - 1, N);
    pad = Np - numel(idx);
    Lh = [Pload(idx), Pload(idx(end)) * ones(1, pad)];
    Mh = [Psource_max(idx), Psource_max(idx(end)) * ones(1, pad)];
    Gh = [grid_status(idx), grid_status(idx(end)) * ones(1, pad)];

    t0 = tic;
    switch opt.backend
        case 'matlab_fpga'
            [u, info] = hil_ctrl_matlab(opt.controle, k, SOC(k), PBESS(k), ...
                uref, Psrc_ant, Pload, Psource_max, grid_status, param);
            PBESS_ref(k) = u;
            if isfield(info, 'tempo_qp_s') && ~isempty(info.tempo_qp_s)
                t_us(k) = 1e6 * info.tempo_qp_s;
            else
                t_us(k) = 1e6 * toc(t0);
            end
            if isfield(info, 'exitflag'); exitflags(k) = info.exitflag; end
            if isfield(info, 'usou_fallback'); fallback(k) = info.usou_fallback; end
            if isfield(info, 'modo_evento'); evento(k) = info.modo_evento; end
        otherwise
            req = sprintf(['REQ %d %.8f %.8f %.8f %.8f %d%s%s%s'], ...
                k-1, SOC(k), PBESS(k), uref, Psrc_ant, Np, ...
                sprintf(' %.8f', Lh), sprintf(' %.8f', Mh), sprintf(' %d', Gh));
            rsp = hil_troca_linha(opt.backend, ser, proc, req);
            tok = sscanf(rsp, 'RSP %f %f %f %f %f');
            if numel(tok) < 5
                error('Resposta HIL invalida em k=%d: %s', k, rsp);
            end
            PBESS_ref(k) = tok(1);
            t_us(k) = tok(2);
            exitflags(k) = tok(3);
            fallback(k) = tok(4) ~= 0;
            evento(k) = tok(5) ~= 0;
    end
    if t_us(k) > 1e6 * param.Ts
        n_overrun = n_overrun + 1;
    end

    [SOC(k+1), PBESS(k+1), Psource(k), Pnao(k)] = planta_bess( ...
        SOC(k), PBESS(k), PBESS_ref(k), Pload(k), Psource_max(k), grid_status(k), param);
end

PBESS_ref(N) = PBESS_ref(N-1);
if grid_status(N) == 1
    Psource(N) = max(0, min(Pload(N) - PBESS(N), Psource_max(N)));
else
    Psource(N) = 0;
end
Pnao(N) = max(0, Pload(N) - Psource(N) - PBESS(N));

metricas = calcula_metricas(t, Pload, Psource, PBESS, SOC, Psource_max, Pnao, param, ...
    'grid_status', grid_status, 'PBESS_ref', PBESS_ref);

out = struct();
out.backend = opt.backend;
out.controle = opt.controle;
out.nome_cenario = char(nome);
out.tipo_cenario = opt.cenario;
out.param = param;
out.t = t; out.Pload = Pload; out.Psource_max = Psource_max; out.grid_status = grid_status;
out.SOC = SOC; out.PBESS = PBESS; out.PBESS_ref = PBESS_ref;
out.Psource = Psource; out.Pnao_atendida = Pnao;
out.metricas = metricas;
out.t_us = t_us; out.exitflags = exitflags;
out.contador_fallback = sum(fallback);
out.percentual_fallback = 100 * sum(fallback) / max(1, N-1);
out.n_overrun = n_overrun;
out.tempo_wall_s = toc(t_wall);
tu = t_us(~isnan(t_us));
if isempty(tu)
    out.t_us_med = NaN; out.t_us_max = NaN; out.t_us_p99 = NaN;
else
    out.t_us_med = mean(tu); out.t_us_max = max(tu); out.t_us_p99 = prctile(tu, 99);
end

pasta = fullfile(fileparts(fileparts(mfilename('fullpath'))), '05_resultados', 'hil_de2115');
if ~exist(pasta, 'dir'); mkdir(pasta); end
fn = sprintf('hil_%s_%s_%s.mat', opt.backend, opt.controle, opt.cenario);
save(fullfile(pasta, fn), 'out');
hil_append_csv(pasta, out);
fprintf('HIL %s/%s/%s  Pnao_max=%.3f  fallback=%.2f%%  overrun=%d  t_us_max=%.0f\n', ...
    opt.backend, opt.controle, opt.cenario, metricas.Pnao_atendida_max, ...
    out.percentual_fallback, n_overrun, out.t_us_max);
end

function [u, info] = hil_ctrl_matlab(ctrl, k, SOC, PBESS, uref, Psrc, Pload, Pmax, grid, param)
info = struct('tempo_qp_s', 0, 'exitflag', 1, 'usou_fallback', false, 'modo_evento', false);
switch ctrl
    case 'heur'
        u = controle_heuristico(Pload(k), Pmax(k), grid(k), SOC, param);
    case 'heur_fs'
        u = controle_heuristico_foresight(k, SOC, uref, Pload, Pmax, grid, param);
    otherwise
        [u, info] = controle_mpc_qp_fpga(k, SOC, PBESS, uref, Psrc, Pload, Pmax, grid, param);
end
end

function rsp = hil_troca_linha(backend, ser, proc, req)
if strcmp(backend, 'serial')
    writeline(ser, strtrim(req));
    while true
        rsp = strtrim(char(readline(ser)));
        if strncmp(rsp, 'RSP', 3)
            return
        end
        if isempty(rsp)
            error('serial timeout (FPGA parou? OpenCore Plus ~1 h: regrave o .sof)');
        end
        % banner KEY0 / lixo: espera o RSP deste REQ
    end
else
    fprintf(proc.stdin, '%s\n', strtrim(req));
    proc.stdin.flush();
    rsp = char(proc.stdout.readLine());
    if isempty(rsp); error('pipe C fechou'); end
end
end

function proc = hil_abrir_exe(exe, ctrl)
map = containers.Map({'heur','heur_fs','mpc'}, {'heur','heur_fs','mpc'});
if ~isKey(map, ctrl); ctrl = 'mpc'; end
pb = java.lang.ProcessBuilder({exe, '--hil', '--ctrl', map(ctrl)});
pb.redirectErrorStream(true);
proc = struct();
proc.j = pb.start();
proc.stdout = java.io.BufferedReader(java.io.InputStreamReader(proc.j.getInputStream()));
proc.stdin = java.io.BufferedWriter(java.io.OutputStreamWriter(proc.j.getOutputStream()));
end

function hil_fechar(ser, proc)
if ~isempty(ser)
    try delete(ser); catch; end
end
if ~isempty(proc) && isfield(proc, 'j')
    try proc.j.destroy(); catch; end
end
end

function hil_append_csv(pasta, out)
csvp = fullfile(pasta, '02_hil_resultados.csv');
hdr = ['backend,controle,cenario,Pnao_max,E_nao_kWh,SOC_final,' ...
    'n_fallback,pct_fallback,n_overrun,t_us_med,t_us_max,t_us_p99,wall_s'];
if ~isfile(csvp)
    fid = fopen(csvp, 'w'); fprintf(fid, '%s\n', hdr); fclose(fid);
end
fid = fopen(csvp, 'a');
fprintf(fid, '%s,%s,%s,%.6f,%.6f,%.6f,%d,%.4f,%d,%.3f,%.3f,%.3f,%.3f\n', ...
    out.backend, out.controle, out.tipo_cenario, ...
    out.metricas.Pnao_atendida_max, out.metricas.Energia_nao_atendida_kWh, ...
    out.metricas.SOC_final, out.contador_fallback, out.percentual_fallback, ...
    out.n_overrun, nz(out.t_us_med), nz(out.t_us_max), nz(out.t_us_p99), out.tempo_wall_s);
fclose(fid);
end

function x = nz(x)
if isempty(x) || ~isfinite(x); x = NaN; end
end
