%% MAIN_VALIDAR_MPC_FPGA
% Compara V5 (Np=60) vs MPC FPGA-ready (Np/Nc reduzidos) vs heuristico.
% Gera CSV em 05_resultados/hil_de2115/ para a tabela IEEE.
%
% Nao exige Quartus. Rode neste PC (MATLAB R2025b).

clc;
this_dir = fileparts(mfilename('fullpath'));
cd(this_dir);
addpath(this_dir);

pasta = fullfile(fileparts(this_dir), '05_resultados', 'hil_de2115');
if ~exist(pasta, 'dir'); mkdir(pasta); end

cenarios = {'carga_faixas', 'limite_fonte', 'perda_fonte', 'retorno_fonte'};
FAZER_VARREDURA = true;

fid_plat = fopen(fullfile(pasta, '00_plataforma.txt'), 'w');
fprintf(fid_plat, 'MATLAB: %s\n', version);
fprintf(fid_plat, 'Computer: %s\n', computer);
fprintf(fid_plat, 'Quartus: ausente neste PC (somente laboratorio)\n');
fprintf(fid_plat, 'FPGA golden MATLAB: Np=12 Nc=4 Nprep=12\n');
fclose(fid_plat);

%% --- Comparacao principal (horizonte congelado) ---

param_v5 = parametros();
param_fpga = parametros_fpga();
param_fpga_off = parametros_fpga();
param_fpga_off.mpc_foresight_grid = false;
param_fpga_off.mpc_foresight_load = false;

linhas = {};
linhas{end+1} = sprintf(['controle,cenario,Np,Nc,Nprep,foresight,' ...
    'Pnao_max,E_nao_kWh,SOC_final,t_qp_med_s,t_qp_max_s,t_qp_p95_s,' ...
    'n_fallback,pct_fallback,wall_s']);

rodadas = {};
for ic = 1:numel(cenarios)
    rodadas{end+1} = {'heuristico', cenarios{ic}, parametros_fpga()}; %#ok<AGROW>
    rodadas{end+1} = {'mpc_qp_v5', cenarios{ic}, param_v5}; %#ok<AGROW>
    rodadas{end+1} = {'mpc_qp_fpga', cenarios{ic}, param_fpga}; %#ok<AGROW>
end
rodadas{end+1} = {'mpc_qp_fpga', 'perda_fonte', param_fpga_off};

fprintf('=== Comparacao principal (%d rodadas) ===\n', numel(rodadas));
for ir = 1:numel(rodadas)
    tipo = rodadas{ir}{1};
    cen = rodadas{ir}{2};
    par = rodadas{ir}{3};
    fprintf('\n>> %s | %s | Np=%d Nc=%d FS=%d\n', tipo, cen, par.Np_mpc, ...
        par.Nc_mpc, par.mpc_foresight_grid);
    out = simular_ems(tipo, cen, par);
    linhas{end+1} = formatar_linha_fpga(out); %#ok<AGROW>
    save(fullfile(pasta, sprintf('sil_%s_%s.mat', tipo, cen)), 'out');
end

%% --- Varredura Np/Nc (criterio de aceite, dois cenarios-chave) ---

if FAZER_VARREDURA
    Nps = [8, 12, 20];
    Ncs = [3, 4, 6];
    cen_var = {'carga_faixas', 'perda_fonte'};
    fprintf('\n=== Varredura Np/Nc ===\n');
    for inp = 1:numel(Nps)
        for inc = 1:numel(Ncs)
            if Ncs(inc) > Nps(inp)
                continue;
            end
            for ic = 1:numel(cen_var)
                par = parametros_fpga();
                par.Np_mpc = Nps(inp);
                par.Nc_mpc = Ncs(inc);
                par.Nprep_evento_mpc = min(par.Nprep_evento_mpc, par.Np_mpc);
                fprintf('\n>> varredura Np=%d Nc=%d | %s\n', par.Np_mpc, par.Nc_mpc, cen_var{ic});
                out = simular_ems('mpc_qp_fpga', cen_var{ic}, par);
                linhas{end+1} = formatar_linha_fpga(out); %#ok<AGROW>
            end
        end
    end
end

csv_path = fullfile(pasta, '01_matlab_v5_vs_fpga.csv');
fid = fopen(csv_path, 'w');
for i = 1:numel(linhas)
    fprintf(fid, '%s\n', linhas{i});
end
fclose(fid);
fprintf('\nCSV escrito: %s\n', csv_path);

%% --- Criterio de aceite (horizonte congelado 12/4) ---

T = readtable(csv_path, 'Delimiter', ',', 'ReadVariableNames', true);
fprintf('\n=== ACEITE FPGA-READY (Np=12 Nc=4, foresight ON) ===\n');
aceite_ok = true;
aceite_ok = cheque_pnao(T, 'MPC-QP-FPGA', 'carga_faixas', 1.0, aceite_ok);
aceite_ok = cheque_pnao(T, 'MPC-QP-FPGA', 'limite_fonte', 1.0, aceite_ok);
aceite_ok = cheque_pnao(T, 'MPC-QP-FPGA', 'perda_fonte', 360, aceite_ok);

idx_on = T.Np == 12 & T.Nc == 4 & T.foresight == 1 & strcmp(T.controle, 'MPC-QP-FPGA') ...
    & contains(string(T.cenario), 'Perda');
idx_off = T.Np == 12 & T.Nc == 4 & T.foresight == 0 & strcmp(T.controle, 'MPC-QP-FPGA') ...
    & contains(string(T.cenario), 'Perda');
if any(idx_on) && any(idx_off)
    p_on = T.Pnao_max(find(idx_on, 1));
    p_off = T.Pnao_max(find(idx_off, 1));
    fprintf('perda_fonte foresight ON=%.2f OFF=%.2f (OFF deve ser pior)\n', p_on, p_off);
    if ~(p_off > p_on + 10)
        warning('Foresight OFF nao ficou claramente pior que ON.');
        aceite_ok = false;
    end
end

if aceite_ok
    fprintf('ACEITE: OK — horizonte 12/4 preserva as claims qualitativas.\n');
else
    fprintf('ACEITE: FALHOU — revisar Np/Nc antes do C/Nios.\n');
end

function s = formatar_linha_fpga(out)
fs = 1;
if isfield(out.param, 'mpc_foresight_grid')
    fs = double(logical(out.param.mpc_foresight_grid));
end
s = sprintf('%s,%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.4f,%.3f', ...
    out.nome_controle, strrep(out.nome_cenario, ',', ';'), ...
    out.param.Np_mpc, out.param.Nc_mpc, out.param.Nprep_evento_mpc, fs, ...
    out.metricas.Pnao_atendida_max, out.metricas.Energia_nao_atendida_kWh, ...
    out.metricas.SOC_final, nz(out.tempo_qp_medio_s), nz(out.tempo_qp_max_s), ...
    nz(out.tempo_qp_p95_s), out.contador_fallback, out.percentual_fallback, ...
    out.tempo_wall_s);
end

function x = nz(x)
if isempty(x) || ~isfinite(x); x = NaN; end
end

function ok = cheque_pnao(T, nome, chave_cen, limiar, ok)
mask = strcmp(T.controle, nome) & T.Np == 12 & T.Nc == 4 & T.foresight == 1 ...
    & contains(lower(string(T.cenario)), erase(chave_cen, '_'));
% nomes de cenario sao descritivos; casa por chave simples
if strcmp(chave_cen, 'carga_faixas')
    mask = strcmp(T.controle, nome) & T.Np == 12 & T.Nc == 4 & T.foresight == 1 ...
        & contains(string(T.cenario), 'faixas');
elseif strcmp(chave_cen, 'limite_fonte')
    mask = strcmp(T.controle, nome) & T.Np == 12 & T.Nc == 4 & T.foresight == 1 ...
        & contains(string(T.cenario), 'Limite');
elseif strcmp(chave_cen, 'perda_fonte')
    mask = strcmp(T.controle, nome) & T.Np == 12 & T.Nc == 4 & T.foresight == 1 ...
        & contains(string(T.cenario), 'Perda');
end
if ~any(mask)
    fprintf('  [FALTA] %s / %s\n', nome, chave_cen);
    ok = false;
    return;
end
p = T.Pnao_max(find(mask, 1));
fprintf('  %s | %s | Pnao_max=%.3f (limiar %.3f)\n', nome, chave_cen, p, limiar);
if p > limiar
    fprintf('    FAIL\n');
    ok = false;
else
    fprintf('    OK\n');
end
end
