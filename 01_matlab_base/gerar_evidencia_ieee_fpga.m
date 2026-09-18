function gerar_evidencia_ieee_fpga()
% Gera tabela markdown MATLAB-V5 | MATLAB-reduzido | SIL/HIL para o paper.
% Nao altera os .tex do Access (fora de escopo ate haver CSV da placa).

root = fileparts(fileparts(mfilename('fullpath')));
pasta = fullfile(root, '05_resultados', 'hil_de2115');
if ~exist(pasta, 'dir'); mkdir(pasta); end

v5csv = fullfile(pasta, '01_matlab_v5_vs_fpga.csv');
hilcsv = fullfile(pasta, '02_hil_resultados.csv');
md = fullfile(pasta, '04_tabela_ieee_fpga.md');

fid = fopen(md, 'w');
fprintf(fid, '# Evidencia embarcada (rascunho IEEE)\n\n');
fprintf(fid, 'Setup alvo: DE2-115, Nios II, UART 115200, Ts = 1 s, Np=12, Nc=4.\n\n');
fprintf(fid, 'Limitacoes: horizonte menor que a V5; solver embarcado ADMM (nao quadprog);\n');
fprintf(fid, 'planta ainda agregada; bitstream Quartus so no laboratorio.\n\n');

if isfile(v5csv)
    fprintf(fid, '## MATLAB V5 vs MPC reduzido\n\n');
    fprintf(fid, 'Arquivo: `01_matlab_v5_vs_fpga.csv`\n\n');
    T = readtable(v5csv, 'Delimiter', ',');
    fprintf(fid, '| controle | cenario | Np | Nc | Pnao_max | t_qp_max_s | fallback |%%|\n');
    fprintf(fid, '|----------|---------|----|----|----------|------------|----------|\n');
    for i = 1:height(T)
        fprintf(fid, '| %s | %s | %d | %d | %.3f | %.4f | %.2f |\n', ...
            string(T.controle(i)), string(T.cenario(i)), T.Np(i), T.Nc(i), ...
            T.Pnao_max(i), T.t_qp_max_s(i), T.pct_fallback(i));
    end
    fprintf(fid, '\n');
else
    fprintf(fid, '## MATLAB V5 vs reduzido\n\n');
    fprintf(fid, '_Pendente: rode `main_validar_mpc_fpga.m` neste PC (MATLAB R2025b)._\n\n');
end

if isfile(hilcsv)
    fprintf(fid, '## SIL / HIL\n\n');
    H = readtable(hilcsv, 'Delimiter', ',');
    fprintf(fid, '| backend | controle | cenario | Pnao_max | t_us_max | overrun | pct_fallback |\n');
    fprintf(fid, '|---------|----------|---------|----------|----------|---------|--------------|\n');
    for i = 1:height(H)
        fprintf(fid, '| %s | %s | %s | %.3f | %.0f | %d | %.2f |\n', ...
            string(H.backend(i)), string(H.controle(i)), string(H.cenario(i)), ...
            H.Pnao_max(i), H.t_us_max(i), H.n_overrun(i), H.pct_fallback(i));
    end
    fprintf(fid, '\nColuna da placa: repetir `hil_loop_de2115(''backend'',''serial'')` no lab.\n');
else
    fprintf(fid, '## SIL / HIL\n\n_Pendente: `main_sil_hil_fpga.m` e, no lab, backend serial._\n');
end

fprintf(fid, '\n## WCET\n\n');
fprintf(fid, 'Figura: rode `python 07_fpga/scripts/gerar_figura_wcet.py` apos o CSV HIL.\n');
fclose(fid);
fprintf('Markdown: %s\n', md);
end
