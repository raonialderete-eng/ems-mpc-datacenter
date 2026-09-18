function m=metricas_auditadas(o)
p=o.param; x=o.Pnao; L=o.case.L(1:end-1); lim=max(1,.001*max(L)); xf=x; xf(x<lim)=0;
m=struct('P_raw_kW',max(x),'P_filtered_kW',max(xf),'filter_kW',lim, ...
 'E_raw_kWh',sum(x)*p.Ts/3600,'E_filtered_kWh',sum(xf)*p.Ts/3600, ...
 'T_gt1_s',sum(x>=1)*p.Ts,'T_gt50_s',sum(x>50)*p.Ts, ...
 'T_gt100_s',sum(x>100)*p.Ts,'T_gt350_s',sum(x>350)*p.Ts, ...
 'SOC_final',o.SOC(end),'SOC_min',min(o.SOC),'SOC_max',max(o.SOC), ...
 'throughput_kWh',sum(abs(o.PBESS(2:end)))*p.Ts/3600, ...
 'u_total_variation',sum(abs(diff([0 o.u]))),'source_violation_kW', ...
 max([0 o.Psource-o.case.M(1:end-1)]),'fallback_pct',mean([o.diagnostics.usou_fallback])*100);
m.EFC=m.throughput_kWh/(2*p.Ebat);
% Each onset (grid loss or crossing source capacity) gets its own recovery.
active=o.case.G(1:end-1)==0 | L>o.case.M(1:end-1);
starts=find(diff([false active])==1); rec=nan(size(starts)); holdn=ceil(10/p.Ts);
for j=1:numel(starts)
    for k=starts(j):numel(x)-holdn+1
        if all(x(k:k+holdn-1)<1), rec(j)=(k-starts(j))*p.Ts; break; end
    end
end
m.recovery_event_starts_s=(starts-1)*p.Ts; m.recovery_s=rec;
m.SOC_at_events=o.SOC(starts);
m.soc_prediction_max_error_pp=max([o.diagnostics.soc_error_pp],[],'omitnan');
m.soc_sign_mismatches=sum([o.diagnostics.soc_sign_mismatch]);
m.soc_prediction_violation_pp=max([o.diagnostics.soc_pred_violation],[],'omitnan');
m.ineq_residual=max([o.diagnostics.ineq_residual],[],'omitnan');
m.eq_residual=max([o.diagnostics.eq_residual],[],'omitnan');
m.hess_cond=o.diagnostics(1).hess_cond; m.constraint_gram_cond=o.diagnostics(1).constraint_cond;
for name={'cycle','qp','assembly'}
    nm=name{1};
    if strcmp(nm,'cycle'), v=o.cycle_s;
    elseif strcmp(nm,'qp'), v=[o.diagnostics.tempo_qp_s];
    else, v=[o.diagnostics.assembly_s]; end
    v=v(isfinite(v));
    if isempty(v), v=NaN; end
    m.([nm '_first_s'])=v(1); m.([nm '_p50_s'])=median(v);
    m.([nm '_p95_s'])=prctile(v,95); m.([nm '_p99_s'])=prctile(v,99); m.([nm '_max_s'])=max(v);
end
m.overruns=sum(o.cycle_s>p.Ts);
end
