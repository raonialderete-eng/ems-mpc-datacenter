function dest = rodar_randomizacao_fisica(root)
here = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(root)
    root = fileparts(fileparts(fileparts(here)));
end
dest = fullfile(root, '05_resultados', 'revisao_operacional', 'randomizacao_fisica_v1');
if ~isfolder(dest), mkdir(dest); end
crit = jsondecode(fileread(fullfile(here, 'CRITERIOS.json')));
copyfile(fullfile(here, 'CRITERIOS.json'), fullfile(dest, 'CRITERIOS.json'));

src = fullfile(root, '01_matlab_base', 'experimentos', 'fechamento_v2', 'src');
oldpath = path;
cleanupPath = onCleanup(@() path(oldpath)); %#ok<NASGU>
addpath(fullfile(root, '01_matlab_base'), '-begin');
addpath(fullfile(root, '01_matlab_base', 'revisao_operacional'), '-begin');
addpath(src, '-begin');
addpath(here, '-begin');
clear montar_qp_auditado controle_mpc_auditado simular_ems_auditado ...
    controle_miope_auditado controle_ff_feedback_v2 parametros

D = desenhar_lhs(crit);
save(fullfile(dest, 'desenhos.mat'), 'D', 'crit');
writetable(struct2table(D), fullfile(dest, 'desenhos.csv'));

ctrls = crit.controllers;
if ischar(ctrls), ctrls = {ctrls}; end
if ~iscell(ctrls)
    tmp = cell(1, numel(ctrls));
    for i = 1:numel(ctrls), tmp{i} = char(ctrls(i)); end
    ctrls = tmp;
end

p0 = parametros();
resumo = {};
diary(fullfile(dest, 'execution.log'));
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('MATLAB %s | physical_operational_sensitivity n=%d method=%s\n', version, numel(D), D(1).method);

for i = 1:numel(D)
    d = D(i);
    [c, p] = montar_caso_fisico(d, p0);
    for ic = 1:numel(ctrls)
        ctrl = ctrls{ic};
        id = sprintf('%s_%s', d.id, ctrl);
        fn = fullfile(dest, [id '.mat']);
        fprintf('START %s tipo=%s t0=%.1f\n', id, d.tipo, d.t0);
        if isfile(fn)
            S = load(fn); out = S.out;
            fprintf('SKIP %s\n', id);
        else
            out = simular_ems_auditado(ctrl, c, p);
            job = struct('id', id, 'group', 'physical_operational_sensitivity', ...
                'draw', d.id, 'ctrl', ctrl, 'tipo', d.tipo);
            save(fn, 'out', 'job', 'd', '-v7');
        end
        m = out.metrics;
        k0 = find(out.t >= d.t0, 1, 'first');
        if isempty(k0), k0 = 1; end
        soc_pre = out.SOC(k0);
        soc_viol = double(m.SOC_min < p.SOC_min - 1e-6);
        row = {id, d.id, d.tipo, ctrl, d.L_base, d.dL, d.L_evento, d.SOC0, d.M, ...
            d.t0, d.dur, d.tau_b, d.bound_kW, m.P_raw_kW, m.P_filtered_kW, ...
            m.P_raw_kW - d.bound_kW, m.E_raw_kWh, soc_pre, m.SOC_final, m.SOC_min, ...
            m.T_gt1_s, m.source_violation_kW, soc_viol, m.fallback_pct, ...
            m.throughput_kWh, out.wall_s};
        resumo(end+1, :) = row; %#ok<AGROW>
        fprintf('DONE %s P=%.3f bound=%.3f wall=%.1f\n', id, m.P_raw_kW, d.bound_kW, out.wall_s);
    end
end
hdr = {'id','draw','tipo','ctrl','L_base','dL','L_evento','SOC0','M','t0','dur','tau_b', ...
    'bound_kW','P_raw_kW','P_filtered_kW','P_minus_bound','E_raw_kWh','SOC_pre_event', ...
    'SOC_final','SOC_min','T_gt1_s','source_violation_kW','soc_min_violation', ...
    'fallback_pct','throughput_kWh','wall_s'};
writecell([hdr; resumo], fullfile(dest, 'resumo.csv'));
escrever_interpretacao_fisica(dest);
end
