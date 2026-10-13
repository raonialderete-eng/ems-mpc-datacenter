addpath('C:/Users/Rauni/Documents/MPC_DATACENTER/01_matlab_base/admm_pc');
addpath('C:/Users/Rauni/Documents/MPC_DATACENTER/01_matlab_base');
try
  audit_form_same_state('carga_faixas', 1);
  audit_form_same_state('perda_fonte', 501);
  ref_kkt_dumps();
catch me
  disp(getReport(me));
  exit(1);
end
exit(0);
