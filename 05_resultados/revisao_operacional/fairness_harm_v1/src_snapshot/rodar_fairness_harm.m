function dest = rodar_fairness_harm(root, dest)
% Phase 2: short comparable-parameter package. Does not touch Table 7.
if nargin<1 || isempty(root)
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(fileparts(here)));
end
if nargin<2 || isempty(dest)
    dest = fullfile(root,'05_resultados','revisao_operacional','fairness_harm_v1');
end
if ~isfolder(dest), mkdir(dest); end

crit = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'CRITERIOS.json')));
src = fullfile(root,'01_matlab_base','experimentos','fechamento_v2','src');
oldpath = path;
cleanupPath = onCleanup(@() path(oldpath)); %#ok<NASGU>
addpath(fullfile(root,'01_matlab_base'),'-begin');
addpath(fullfile(root,'01_matlab_base','revisao_operacional'),'-begin');
addpath(src,'-begin');
clear montar_qp_auditado controle_mpc_auditado simular_ems_auditado ...
    controle_miope_auditado caso_auditado controle_ff_feedback_v2

jobs = harm_jobs(crit);
resumo = {};
for j=1:numel(jobs)
    job = jobs{j};
    fn = fullfile(dest,[job.id '.mat']);
    fprintf('START %s %s %s\n', job.id, job.scenario, job.ctrl);
    if isfile(fn)
        S = load(fn); out = S.out;
        fprintf('SKIP existing %s\n', job.id);
    else
        [c,p] = caso_auditado(job, root);
        out = simular_ems_auditado(job.ctrl, c, p);
        save(fn, 'out','job','-v7');
    end
    m = out.metrics;
    resumo(end+1,:) = {job.id, job.scenario, job.ctrl, job.arm, ...
        m.P_raw_kW, m.P_filtered_kW, m.E_raw_kWh, m.SOC_final, ...
        m.throughput_kWh, m.fallback_pct, out.wall_s}; %#ok<AGROW>
    fprintf('DONE %s P=%.4f Pf=%.4f wall=%.1fs\n', job.id, m.P_raw_kW, m.P_filtered_kW, out.wall_s);
end
hdr = {'id','scenario','ctrl','arm','P_raw_kW','P_filtered_kW','E_raw_kWh', ...
    'SOC_final','throughput_kWh','fallback_pct','wall_s'};
writecell([hdr; resumo], fullfile(dest,'resumo.csv'));
copyfile(fullfile(fileparts(mfilename('fullpath')),'CRITERIOS.json'), fullfile(dest,'CRITERIOS.json'));
end

function jobs = harm_jobs(crit)
w = crit.w_du_miope_alinhado;
base = struct('common_slew',true,'information_policy','persistence', ...
    'dPBESS_ref_max',400,'dPBESS_ref_max_evento',400, ...
    'Pbase_audit',950);
jobs = {};
ctrls = { ...
    'miope_qp','miope_du_alinhado',struct('w_mpc_delta_u',w); ...
    'mpc_qp_v5','v5_mesmo_slew_fill',struct(); ...
    'ff_feedback','ff_mesmo_slew_fill',struct(); ...
    'heuristico','ancora_rampa',struct()};
scen = {'carga_faixas','perda_fonte'};
n = 0;
for s=1:numel(scen)
    for c=1:size(ctrls,1)
        n = n+1;
        job = struct();
        job.id = sprintf('H%02d', n);
        job.group = 'fairness_harm';
        job.scenario = scen{s};
        job.ctrl = ctrls{c,1};
        job.arm = ctrls{c,2};
        job.params = base;
        extra = ctrls{c,3};
        fns = fieldnames(extra);
        for i=1:numel(fns)
            job.params.(fns{i}) = extra.(fns{i});
        end
        jobs{end+1} = job; %#ok<AGROW>
    end
end
end
