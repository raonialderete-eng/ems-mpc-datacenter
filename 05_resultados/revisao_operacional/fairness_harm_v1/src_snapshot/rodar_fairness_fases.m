function rodar_fairness_fases()
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(fileparts(here)));
oldpath = path;
cleanupPath = onCleanup(@() path(oldpath)); %#ok<NASGU>
addpath(here,'-begin');
addpath(fullfile(root,'01_matlab_base','revisao_operacional'),'-begin');
addpath(fullfile(root,'01_matlab_base'),'-begin');
clear montar_qp_auditado controle_mpc_auditado controle_miope_auditado

d1 = fullfile(root,'05_resultados','revisao_operacional','fairness_sintese_v1');
d2 = fullfile(root,'05_resultados','revisao_operacional','fairness_harm_v1');
if isfolder(d1), error('fairness_sintese_v1 already exists'); end
if isfolder(d2), error('fairness_harm_v1 already exists'); end

fprintf('MATLAB %s\n', version);
sintetizar_mats(root, d1);
copyfile(fullfile(here,'CRITERIOS.json'), fullfile(d1,'CRITERIOS.json'));
diary(fullfile(d1,'execution.log'));
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
rodar_fairness_harm(root, d2);
escrever_interpretacao(root, d1, d2);
end
