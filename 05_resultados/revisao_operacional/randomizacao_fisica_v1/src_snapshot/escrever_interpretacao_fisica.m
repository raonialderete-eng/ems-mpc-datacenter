function escrever_interpretacao_fisica(dest)
T = readtable(fullfile(dest, 'resumo.csv'), 'TextType', 'string');
ctrls = ["mpc_qp_v5", "miope_qp", "ff_feedback"];
lines = {
'# Physical / operational randomization sensitivity'
''
'Grupo `physical_operational_sensitivity`. **Não** é extensão informal dos 200 pares Monte Carlo.'
''
'Os 200 pares Monte Carlo avaliam incerteza de previsão sob uma trajetória física comum. Este experimento adicional de randomização física avalia a sensibilidade das conclusões a variações de condições operacionais e parâmetros da planta.'
''
'Consolidação oficial e Tabela 7 **intocadas**. Previsão alinhada à planta. Erro de previsão fora deste sorteio.'
''
};

fid = fopen(fullfile(dest, 'INTERPRETACAO.md'), 'w');
fprintf(fid, '%s\n', lines{:});
fprintf(fid, 'Desenhos: %d (16 perda / 16 limite). Controladores: V5, míope, FF+FB.\n\n', ...
    numel(unique(T.draw)));
fprintf(fid, '| ctrl | n | med P-bound | p95 P-bound | frac |P-bound|<=1 kW | med E kWh | med SOC_pre | med SOC_final |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:numel(ctrls)
    S = T(T.ctrl == ctrls(i), :);
    db = S.P_minus_bound;
    fprintf(fid, '| %s | %d | %.3f | %.3f | %.3f | %.4f | %.3f | %.3f |\n', ...
        ctrls(i), height(S), median(db), prctile(db, 95), mean(abs(db) <= 1), ...
        median(S.E_raw_kWh), median(S.SOC_pre_event), median(S.SOC_final));
end
fprintf(fid, '\nCSV: `resumo.csv`. Método LHS: ver `desenhos.csv` coluna `method`.\n');
fprintf(fid, '\n**Não usar:** IC bootstrap destes 32 como se fossem os 200 pares; população de data centers; mistura com Tabela 7.\n');
fclose(fid);
end
