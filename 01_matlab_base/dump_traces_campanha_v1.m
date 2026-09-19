function dump_traces_campanha_v1(root)
% Write 11 Sep traces to CSV so figures can be built without MATLAB graphics.
if nargin < 1
    root = fileparts(mfilename('fullpath'));
end
P = ems_pack_paths(root);
camp = P.campanha;
outDir = P.traces;
if ~isfolder(outDir), mkdir(outDir); end
pairs = {
    'carga_faixas','j00001','j00003','j00004';
    'limite_fonte','j00006','j00008','j00009';
    'perda_fonte','j00011','j00013','j00014'};
fid = fopen(fullfile(outDir, 'kpi_check.csv'), 'w');
fprintf(fid, 'scenario,id_h,P_h,SOC_h,id_m,P_m,SOC_m,id_v,P_v,SOC_v\n');
for i = 1:size(pairs,1)
    name = pairs{i,1};
    H = load_job(fullfile(camp, [pairs{i,2} '.mat']));
    M = load_job(fullfile(camp, [pairs{i,3} '.mat']));
    V = load_job(fullfile(camp, [pairs{i,4} '.mat']));
    fprintf('%s  H %s P=%.6f SOC_f=%.6f | M %s P=%.6f SOC_f=%.6f | V5 %s P=%.6f SOC_f=%.6f\n', ...
        name, H.id, H.P_raw, H.SOC_f, M.id, M.P_raw, M.SOC_f, V.id, V.P_raw, V.SOC_f);
    fprintf(fid, '%s,%s,%.12g,%.12g,%s,%.12g,%.12g,%s,%.12g,%.12g\n', ...
        name, H.id, H.P_raw, H.SOC_f, M.id, M.P_raw, M.SOC_f, V.id, V.P_raw, V.SOC_f);
    n = numel(V.Pnao);
    T = table(V.t_u(:), V.L_u(:), V.M_u(:), V.G(1:n)', ...
        H.PBESS_u(:), M.PBESS_u(:), V.PBESS_u(:), ...
        H.Pnao(:), M.Pnao(:), V.Pnao(:), ...
        H.SOC(1:n)', M.SOC(1:n)', V.SOC(1:n)', ...
        'VariableNames', {'t_s','Pload','Psource_max','g', ...
        'PBESS_h','PBESS_m','PBESS_v','Pnao_h','Pnao_m','Pnao_v','SOC_h','SOC_m','SOC_v'});
    writetable(T, fullfile(outDir, [name '.csv']));
end
fclose(fid);
fprintf('CSV traces in %s\n', outDir);
end

function S = load_job(fn)
assert(isfile(fn), 'Missing MAT: %s', fn);
D = load(fn, 'out', 'job');
o = D.out;
S.id = D.job.id;
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
