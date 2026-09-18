pasta_out = fullfile('c:\Users\Rauni\Documents\MPC_DATACENTER','05_resultados','revisao_ieee_applied');
S = load(fullfile(pasta_out,'01_comparacao_controladores.mat'),'resultados');
gerar_figuras_revisao(S.resultados, pasta_out);
fprintf('FIGS OK\n');