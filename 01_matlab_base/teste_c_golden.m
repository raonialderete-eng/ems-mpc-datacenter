%% TESTE_C_GOLDEN
% Gera CSV MATLAB (planta + heuristico, mesmo k) para comparar com ems_golden no lab.
% Aceite: |dPBESS_ref| < 1e-6 e |dPnao_max| < 1e-6 no heuristico.
% MPC: comparar KPI Pnao_max (ADMM C vs quadprog MATLAB), nao bit-a-bit.

this_dir = fileparts(mfilename('fullpath'));
cd(this_dir);
pasta = fullfile(fileparts(this_dir), '05_resultados', 'hil_de2115');
if ~exist(pasta, 'dir'); mkdir(pasta); end

param = parametros_fpga();
cenarios = {'carga_faixas', 'limite_fonte', 'perda_fonte', 'retorno_fonte'};

fid = fopen(fullfile(pasta, '03_matlab_heuristico_passos.csv'), 'w');
fprintf(fid, 'cenario,k,SOC,PBESS,uref,Pload,Pmax,grid,u_heur,u_fs,SOC_next,Pnao\n');

kpi_fid = fopen(fullfile(pasta, '03_matlab_heuristico_kpi.csv'), 'w');
fprintf(kpi_fid, 'cenario,controle,Pnao_max,SOC_final\n');

for ic = 1:numel(cenarios)
    t = 0:param.Ts:param.Tf;
    N = numel(t);
    [Pload, Pmax, grid] = gera_cenario(t, cenarios{ic}, param);

    for modo = {'heur', 'heur_fs'}
        SOC = param.SOC_ref; PBESS = 0; uref = 0; pnao_max = 0;
        for k = 1:N-1
            if strcmp(modo{1}, 'heur')
                u = controle_heuristico(Pload(k), Pmax(k), grid(k), SOC, param);
            else
                u = controle_heuristico_foresight(k, SOC, uref, Pload, Pmax, grid, param);
            end
            [SOC2, PBESS2, ~, pnao] = planta_bess(SOC, PBESS, u, Pload(k), Pmax(k), grid(k), param);
            if strcmp(modo{1}, 'heur')
                fprintf(fid, '%s,%d,%.10f,%.10f,%.10f,%.10f,%.10f,%d,%.10f,nan,%.10f,%.10f\n', ...
                    cenarios{ic}, k-1, SOC, PBESS, uref, Pload(k), Pmax(k), grid(k), u, SOC2, pnao);
            end
            SOC = SOC2; PBESS = PBESS2; uref = u;
            pnao_max = max(pnao_max, pnao);
        end
        fprintf(kpi_fid, '%s,%s,%.10f,%.10f\n', cenarios{ic}, modo{1}, pnao_max, SOC);
    end
end
fclose(fid);
fclose(kpi_fid);
fprintf('CSV de referencia heuristica escrito em %s\n', pasta);
fprintf('No lab: make && ./ems_golden --ctrl heur --cenario perda_fonte\n');
