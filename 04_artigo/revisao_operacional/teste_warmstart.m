function teste_warmstart(root,dest)
assert(~isfile(dest));
addpath(fullfile(root,'01_matlab_base')); addpath(fullfile(root,'01_matlab_base','revisao_operacional'));
p=parametros(); p.Pbase_audit=950;
L=[750*ones(1,20),950*ones(1,40)]; M=800*ones(size(L)); G=ones(size(L));
q=montar_qp_auditado(1,60,0,0,750,L,M,G,p);
opts=optimoptions('quadprog','Display','off','Algorithm','interior-point-convex','MaxIterations',150, ...
 'ConstraintTolerance',1e-5,'OptimalityTolerance',1e-5,'StepTolerance',1e-8);
[z,~,ef]=quadprog(q.H,q.f,q.Aineq,q.bineq,q.Aeq,q.beq,q.lb,q.ub,[],opts); assert(ef>0);
rows=zeros(20,5);
for k=1:20
    supplied=mod(k,2)==0; x0=[]; if supplied,x0=z;end
    t=tic; [zz,~,flag,o]=quadprog(q.H,q.f,q.Aineq,q.bineq,q.Aeq,q.beq,q.lb,q.ub,x0,opts); elapsed=toc(t);
    rows(k,:)=[supplied,elapsed,o.iterations,flag,max(abs(zz-z))];
end
tab=array2table(rows,'VariableNames',{'provided_x0','solve_s','iterations','exitflag','max_solution_difference'});
assert(all(tab.exitflag>0)); writetable(tab,dest); disp(tab);
end
