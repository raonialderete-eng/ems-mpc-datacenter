function [c,p]=caso_auditado(job,root)
p=parametros(); p.Pbase_audit=950; p.SOC_initial=60;
if isfield(job,'params') && isstruct(job.params)
    f=fieldnames(job.params); for i=1:numel(f), p.(f{i})=job.params.(f{i}); end
end
p.ab=exp(-p.Ts/p.tau_b); p.bb=1-p.ab;
t=0:p.Ts:p.Tf;
if startsWith(job.scenario,'diploee_') || startsWith(job.scenario,'nvml_')
    fn=fullfile(root,'05_resultados','revisao_operacional','dataset_v1',[job.scenario '.mat']);
    assert(isfile(fn),'Official profile missing: %s',fn); c=load(fn,'L','M','G');
else
    [c.L,c.M,c.G]=gera_cenario(t,job.scenario,p);
end
c.L=c.L(:)'; c.M=c.M(:)'; c.G=c.G(:)';
c.Lf=c.L; c.Mf=c.M; c.Gf=c.G;
if isfield(job,'forecast_load_factor'), c.Lf=c.Lf*job.forecast_load_factor; end
if isfield(job,'forecast_shift')
    sh=job.forecast_shift;
    c.Gf=double(~(t>=500+sh & t<650+sh)); c.Mf=p.Psource_max_nominal*c.Gf;
end
if isfield(job,'event_mode')
    switch job.event_mode
        case 'false_alarm', c.G(:)=1; c.M(:)=p.Psource_max_nominal;
        case 'missed_event', c.Gf(:)=1; c.Mf(:)=p.Psource_max_nominal;
        case 'detection_delay'
            c.Gf(:)=1; c.Mf(:)=p.Psource_max_nominal;
            c.detection_delay=job.delay;
            p.mpc_foresight_grid=false;
    end
end
end
