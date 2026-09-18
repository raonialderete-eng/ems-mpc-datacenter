function executar_campanha(root,runid,groups)
% New run directory; resume only identical code/input/config fingerprints.
addpath(fullfile(root,'01_matlab_base')); addpath(fullfile(root,'01_matlab_base','revisao_operacional'));
if nargin<3, groups={}; end
jobfile=fullfile(root,'04_artigo','revisao_operacional','jobs.json');
txt=fileread(jobfile); jobs=jsondecode(txt);
% Decode heterogeneous JSON as cell array for optional job fields.
if ~iscell(jobs), jobs=num2cell(jobs); end
dest=fullfile(root,'05_resultados','revisao_operacional',runid);
if ~isfolder(dest), mkdir(dest); end
lock=fullfile(dest,'RUNNING.lock'); assert(~isfile(lock),'Run already active; inspect lock first.');
fid=fopen(lock,'w'); fprintf(fid,'%s',datestr(now,30)); fclose(fid);
guard=onCleanup(@() delete(lock)); %#ok<NASGU>
finger=campaign_hash(root,txt);
statefile=fullfile(dest,'fingerprint.txt');
if isfile(statefile)
    assert(strcmp(strtrim(fileread(statefile)),finger),'Fingerprint mismatch: create a NEW runid');
else
    fid=fopen(statefile,'w'); fprintf(fid,'%s',finger); fclose(fid);
    save(fullfile(dest,'registered_jobs.mat'),'jobs');
end
diary(fullfile(dest,['log_' datestr(now,'yyyymmdd_HHMMSS') '.txt']));
clean=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('MATLAB %s | %s | %s\n',version,runid,finger);
for j=1:numel(jobs)
    job=jobs{j}; if ~isempty(groups) && ~ismember(job.group,groups), continue; end
    fn=fullfile(dest,[job.id '.mat']); if isfile(fn), continue; end
    fprintf('START %s %s %s %s\n',job.id,job.group,job.scenario,job.ctrl);
    [c,p]=caso_auditado(job,root); out=simular_ems_auditado(job.ctrl,c,p);
    save([fn '.partial'],'out','job','finger','-v7'); movefile([fn '.partial'],fn);
    fprintf('DONE %s raw=%.6f filtered=%.6f E=%.6f fb=%.3f%% wall=%.2fs\n', ...
        job.id,out.metrics.P_raw_kW,out.metrics.P_filtered_kW,out.metrics.E_raw_kWh,out.metrics.fallback_pct,out.wall_s);
end
fprintf('REQUESTED GROUPS FINISHED %s\n',datestr(now,30));
end
function h=campaign_hash(root,txt)
files=[dir(fullfile(root,'01_matlab_base','*.m'));dir(fullfile(root,'01_matlab_base','revisao_operacional','*.m'))];
data=txt;
for i=1:numel(files), data=[data files(i).name fileread(fullfile(files(i).folder,files(i).name))]; end %#ok<AGROW>
data=[data fileread(fullfile(root,'05_resultados','revisao_operacional','dataset_v1','manifest.json')) version];
md=java.security.MessageDigest.getInstance('SHA-256'); md.update(unicode2native(data,'UTF-8'));
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
