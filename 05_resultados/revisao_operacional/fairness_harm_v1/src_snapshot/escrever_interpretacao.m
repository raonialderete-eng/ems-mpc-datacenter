function escrever_interpretacao(root, d1, d2)
T = readtable(fullfile(d2,'resumo.csv'), 'TextType','string');
pick = @(sc,ct) T(T.scenario==sc & T.ctrl==ct, :);
mf = pick("carga_faixas","miope_qp");
vf = pick("carga_faixas","mpc_qp_v5");
ff = pick("carga_faixas","ff_feedback");
hf = pick("carga_faixas","heuristico");
mp = pick("perda_fonte","miope_qp");
vp = pick("perda_fonte","mpc_qp_v5");
fp = pick("perda_fonte","ff_feedback");
hp = pick("perda_fonte","heuristico");

lines = {
'# Fairness síntese (Fase 1) e parâmetros comparáveis (Fase 2)'
''
'Consolidação oficial e Tabela 7 **intocadas**.'
''
'## Conclusão travada da Fase 2'
''
'Harmonizamos os parâmetros diretamente comparáveis e verificamos que a diferença principal persiste; as arquiteturas, contudo, mantêm diferenças estruturais em seus objetivos, incluindo termos de horizonte, terminal, slack e recarga.'
''
'English: We harmonized the directly comparable parameters and verified that the main difference persists; the architectures, however, retain structural differences in their objectives, including horizon, terminal, slack and recharge terms.'
''
'**Não usar:** “agora a comparação é completamente justa”; objetivos idênticos; fairness integral.'
''
'## Escolha do coeficiente Δu'
''
sprintf('Compensar `/Pbase^2` no míope: `w_mpc_delta_u = 50 * 950^2 = 45125000`, de modo que `w_eff = w_V5 = 50` no termo Δu em modo normal. O V5 **não** recebe a divisão por `Pbase^2`. Terminal, slacks de horizonte e recarga/evento do V5 **não** foram reotimizados. Em modo evento o V5 ainda usa `0.1*w_delta_u` (diferença estrutural restante).')
''
'Fill: persistence. `dUmax = dUmax_evento = 400`. `common_slew`. `Pbase=950`, `Rbase=100`. Cenários: `carga_faixas` e `perda_fonte`.'
''
'## Fase 1'
''
sprintf('Janelas ±20 s e conjunto ativo: `%s` (`comando_eventos.csv`, `ativo_por_evento.csv`). Builders separados: `montar_qp_miope_sintese` vs `montar_qp_auditado`. MATs B3 NVML ausentes no disco; âncora NVML 400 kW/s = `j00162`.', strrep(d1,'\','/'))
''
'## Fase 2 — números'
''
sprintf('- faixas míope alinhado: P_raw=%.4f P_filt=%.4f kW', mf.P_raw_kW, mf.P_filtered_kW)
sprintf('- faixas V5: P_raw=%.4f P_filt=%.4f kW', vf.P_raw_kW, vf.P_filtered_kW)
sprintf('- faixas FF+FB: P_raw=%.4f P_filt=%.4f kW', ff.P_raw_kW, ff.P_filtered_kW)
sprintf('- faixas heurístico (âncora de rampa, não mesmo custo): P_raw=%.4f kW', hf.P_raw_kW)
sprintf('- perda míope alinhado: P_raw=%.4f kW', mp.P_raw_kW)
sprintf('- perda V5: P_raw=%.4f kW', vp.P_raw_kW)
sprintf('- perda FF+FB: P_raw=%.4f kW', fp.P_raw_kW)
sprintf('- perda heurístico (âncora): P_raw=%.4f kW', hp.P_raw_kW)
''
'Critério pré-registrado: na perda, se o míope alinhado continuar ~593 kW e o V5 ~350 kW, a diferença principal persiste após harmonizar rampa + coeficiente Δu + fill. Em faixas, ambos no zero filtrado com 400 kW/s não contradiz a perda.'
''
sprintf('CSV: `%s/resumo.csv`.', strrep(d2,'\','/'))
};
fid = fopen(fullfile(d2,'INTERPRETACAO.md'),'w');
fprintf(fid,'%s\n', lines{:});
fclose(fid);
copyfile(fullfile(d2,'INTERPRETACAO.md'), fullfile(d1,'INTERPRETACAO.md'));
end
