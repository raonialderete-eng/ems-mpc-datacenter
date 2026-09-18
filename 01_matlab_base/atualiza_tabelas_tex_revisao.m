%% ATUALIZA_TABELAS_TEX_REVISAO
% Lê CSVs de 05_resultados/revisao_ieee_applied e atualiza tabelas
% numéricas nos .tex PT/EN (e cópias overleaf_upload).

pasta_proj = 'c:/Users/Rauni/Documents/MPC_DATACENTER';
pasta = fullfile(pasta_proj, '05_resultados', 'revisao_ieee_applied');

csv1 = fullfile(pasta, '01_comparacao_controladores.csv');
if ~exist(csv1, 'file')
    error('CSV de comparacao ainda nao existe: %s', csv1);
end
T = readtable(csv1);
disp('=== Comparacao (Pnao_max) ===');
disp(T(:, {'Cenario','Controle','Pnao_max_kW','Energia_nao_kWh','SOC_final', ...
    'Throughput_kWh','Fallback_pct','t_qp_med_s','t_qp_max_s'}));

% Mapa cenario -> linha na tabela Pnao
cen_map = { ...
    'carga_faixas', 'Carga em faixas', 'Load bands'; ...
    'limite_fonte', 'Limite da fonte', 'Source limit'; ...
    'perda_fonte', 'Perda da fonte', 'Source loss'; ...
    'retorno_fonte', 'Retorno da fonte', 'Source return'};

ctrl_keys = {'Heuristico','Heuristico-FS','Miope-QP','MPC-QP-V5'};
% nomes no CSV podem variar
ctrl_alias = { ...
    'Heuristico', {'Heuristico'}; ...
    'Heuristico-FS', {'Heuristico-FS','Heuristico_FS'}; ...
    'Miope-QP', {'Miope-QP','Miope'}; ...
    'MPC-QP-V5', {'MPC-QP-V5','MPC'}};

rows_pt = {};
rows_en = {};
for ic = 1:size(cen_map,1)
    cen = cen_map{ic,1};
    vals = nan(1,4);
    for jc = 1:4
        aliases = ctrl_alias{jc,2};
        for ia = 1:numel(aliases)
            mask = strcmp(T.Cenario, cen) & strcmp(T.Controle, aliases{ia});
            if any(mask)
                vals(jc) = T.Pnao_max_kW(find(mask,1,'first'));
                break;
            end
        end
    end
    rows_pt{end+1} = sprintf('%s & %s & %s & %s & %s \\\\', ...
        cen_map{ic,2}, fmt_br(vals(1)), fmt_br(vals(2)), fmt_br(vals(3)), fmt_br_bold(vals(4))); %#ok<AGROW>
    rows_en{end+1} = sprintf('%s & %s & %s & %s & %s \\\\', ...
        cen_map{ic,3}, fmt_en(vals(1)), fmt_en(vals(2)), fmt_en(vals(3)), fmt_en_bold(vals(4))); %#ok<AGROW>
end

fprintf('\n=== Linhas PT tab:pnao ===\n');
fprintf('%s\n', rows_pt{:});
fprintf('\n=== Linhas EN tab:punserved ===\n');
fprintf('%s\n', rows_en{:});

% Foresight
f3 = fullfile(pasta, '03_foresight_on_off.csv');
if exist(f3, 'file')
    Tf = readtable(f3);
    disp('=== Foresight ==='); disp(Tf);
end
f4 = fullfile(pasta, '03_sensibilidade_Nprep.csv');
if exist(f4, 'file')
    disp('=== Nprep ==='); disp(readtable(f4));
end
f5 = fullfile(pasta, '03_sensibilidade_tau.csv');
if exist(f5, 'file')
    disp('=== tau ==='); disp(readtable(f5));
end
f1 = fullfile(pasta, '02_erro_magnitude.csv');
if exist(f1, 'file')
    disp('=== Erro magnitude ==='); disp(readtable(f1));
end
f2 = fullfile(pasta, '02_erro_temporal.csv');
if exist(f2, 'file')
    disp('=== Erro temporal ==='); disp(readtable(f2));
end

% Patch TeX files if comparison CSV has all 4 base scenarios with MPC
n_mpc = sum(strcmp(T.Controle,'MPC-QP-V5') | strcmp(T.Controle,'MPC'));
if n_mpc >= 4
    tex_pt = fullfile(pasta_proj, '04_artigo', 'ieee_pt', 'artigo_ems_mpc_datacenter_pt.tex');
    tex_en = fullfile(pasta_proj, '04_artigo', 'ieee_en', 'artigo_ems_mpc_datacenter_en.tex');
    patch_pnao_table(tex_pt, rows_pt, 'Carga em faixas', 'Retorno da fonte');
    patch_pnao_table(tex_en, rows_en, 'Load bands', 'Source return');
    % overleaf copies
    ov_pt = fullfile(pasta_proj, '04_artigo', 'overleaf_upload', 'ieee_pt', 'artigo_ems_mpc_datacenter_pt.tex');
    ov_en = fullfile(pasta_proj, '04_artigo', 'overleaf_upload', 'ieee_en', 'artigo_ems_mpc_datacenter_en.tex');
    if exist(ov_pt,'file'), patch_pnao_table(ov_pt, rows_pt, 'Carga em faixas', 'Retorno da fonte'); end
    if exist(ov_en,'file'), patch_pnao_table(ov_en, rows_en, 'Load bands', 'Source return'); end
    fprintf('\nTabelas Pnao patchadas nos .tex.\n');
else
    fprintf('\nAinda sem 4 cenarios MPC no CSV (n_mpc=%d); patch adiado.\n', n_mpc);
end

if exist(fullfile(pasta, 'ESTUDO_CONCLUIDO.txt'), 'file')
    fprintf('\nESTUDO CONCLUIDO presente.\n');
    % Patch foresight / Nprep / tau if available
    if exist(f3,'file')
        patch_foresight(tex_pt, tex_en, ov_pt, ov_en, readtable(f3));
    end
    if exist(f4,'file')
        patch_nprep(tex_pt, tex_en, ov_pt, ov_en, readtable(f4));
    end
    if exist(f5,'file')
        patch_tau(tex_pt, tex_en, ov_pt, ov_en, readtable(f5));
    end
else
    fprintf('\nEstudo ainda em andamento.\n');
end

function s = fmt_br(v)
if isnan(v)
    s = '---';
else
    s = strrep(sprintf('%.2f', v), '.', '{,}');
end
end

function s = fmt_br_bold(v)
if isnan(v)
    s = '---';
else
    s = ['\textbf{' strrep(sprintf('%.2f', v), '.', '{,}') '}'];
end
end

function s = fmt_en(v)
if isnan(v)
    s = '---';
else
    s = sprintf('%.2f', v);
end
end

function s = fmt_en_bold(v)
if isnan(v)
    s = '---';
else
    s = sprintf('\\textbf{%.2f}', v);
end
end

function patch_pnao_table(texfile, rows, first_label, last_label)
if ~exist(texfile,'file'), return; end
txt = fileread(texfile);
% Replace body between first and last scenario rows (4 lines)
pat = [regexptranslate('escape', first_label) '.*?' regexptranslate('escape', last_label) '[^\n]*\\\\'];
repl = strjoin(rows, newline);
txt2 = regexprep(txt, pat, repl, 'once', 'dotexceptnewline');
% multiline
txt2 = regexprep(txt, pat, repl, 'once', 'lineanchors');
% Use manual find
i1 = strfind(txt, first_label);
i2 = strfind(txt, last_label);
if isempty(i1) || isempty(i2), warning('labels not found in %s', texfile); return; end
i1 = i1(1);
i2 = i2(1);
% extend i2 to end of line (\\\\)
eol = regexp(txt(i2:end), '\\\\', 'once');
if isempty(eol), return; end
i2e = i2 + eol + 1; % include \\
txt2 = [txt(1:i1-1), strjoin(rows, newline), txt(i2e+1:end)];
fid = fopen(texfile, 'w');
fwrite(fid, txt2);
fclose(fid);
fprintf('Patched %s\n', texfile);
end

function patch_foresight(tex_pt, tex_en, ov_pt, ov_en, Tf)
% Expect columns Foresight, Pnao_max_kW, Energia_nao_kWh, and optionally SOC
try
    on = Tf(strcmpi(string(Tf.Foresight),'ON'),:);
    off = Tf(strcmpi(string(Tf.Foresight),'OFF'),:);
    if isempty(on) || isempty(off), return; end
    soc_on = NaN; soc_off = NaN;
    if ismember('SOC_final', Tf.Properties.VariableNames)
        soc_on = on.SOC_final; soc_off = off.SOC_final;
    elseif ismember('t_qp_med', Tf.Properties.VariableNames)
        % lote table may lack SOC — keep existing TeX SOC if missing
    end
    files = {tex_pt, tex_en, ov_pt, ov_en};
    for i = 1:numel(files)
        f = files{i}; if ~exist(f,'file'), continue; end
        txt = fileread(f);
        is_pt = contains(f, '_pt');
        if is_pt
            if ~isnan(soc_on)
                line_on = sprintf('Foresight ON & %s & %s & %s \\\\', ...
                    fmt_br(on.Pnao_max_kW), fmt_br(on.Energia_nao_kWh), fmt_br(soc_on));
                line_off = sprintf('Foresight OFF & %s & %s & %s \\\\', ...
                    fmt_br(off.Pnao_max_kW), fmt_br(off.Energia_nao_kWh), fmt_br(soc_off));
            else
                continue;
            end
            txt = regexprep(txt, 'Foresight ON &[^\\]+\\\\', line_on, 'once');
            txt = regexprep(txt, 'Foresight OFF &[^\\]+\\\\', line_off, 'once');
        else
            if ~isnan(soc_on)
                line_on = sprintf('Foresight ON & %.2f & %.2f & %.2f \\\\', ...
                    on.Pnao_max_kW, on.Energia_nao_kWh, soc_on);
                line_off = sprintf('Foresight OFF & %.2f & %.2f & %.2f \\\\', ...
                    off.Pnao_max_kW, off.Energia_nao_kWh, soc_off);
            else
                continue;
            end
            txt = regexprep(txt, 'Foresight ON &[^\\]+\\\\', line_on, 'once');
            txt = regexprep(txt, 'Foresight OFF &[^\\]+\\\\', line_off, 'once');
        end
        fid = fopen(f,'w'); fwrite(fid, txt); fclose(fid);
        fprintf('Patched foresight %s\n', f);
    end
catch ME
    warning('%s', ME.message);
end
end

function patch_nprep(tex_pt, tex_en, ov_pt, ov_en, Tn)
files = {tex_pt, tex_en, ov_pt, ov_en};
for i = 1:numel(files)
    f = files{i}; if ~exist(f,'file'), continue; end
    txt = fileread(f);
    is_pt = contains(f, '_pt');
    lines = cell(height(Tn),1);
    for r = 1:height(Tn)
        if is_pt
            lines{r} = sprintf('%d & %s & %s & %s \\\\', Tn.Nprep(r), ...
                fmt_br(Tn.Pnao_max_kW(r)), fmt_br(Tn.Energia_nao_kWh(r)), fmt_br(Tn.t_qp_med(r)));
        else
            lines{r} = sprintf('%d & %.2f & %.2f & %.3f \\\\', Tn.Nprep(r), ...
                Tn.Pnao_max_kW(r), Tn.Energia_nao_kWh(r), Tn.t_qp_med(r));
        end
    end
    % replace block from first Nprep row "0 &" through last "\\\\" before \bottomrule in nprep table
    % simpler: replace known old 5-line block if present
    i0 = regexp(txt, '(?m)^0 & .*\\\\$', 'start', 'once');
    if isempty(i0), continue; end
    % find end of consecutive Nprep data lines
    chunk = txt(i0:end);
    [~, ends] = regexp(chunk, '(?m)^\d+ & .*\\\\$', 'start', 'end');
    if isempty(ends), continue; end
    i1 = i0; i2 = i0 + ends(end) - 1;
    txt2 = [txt(1:i1-1), strjoin(lines, newline), txt(i2+1:end)];
    % Only apply inside tab:nprep — verify nearby label
    if contains(txt(max(1,i1-400):i1), 'tab:nprep') || contains(txt(max(1,i1-800):i1), 'N_')
        fid = fopen(f,'w'); fwrite(fid, txt2); fclose(fid);
        fprintf('Patched Nprep %s\n', f);
    end
end
end

function patch_tau(tex_pt, tex_en, ov_pt, ov_en, Tt)
files = {tex_pt, tex_en, ov_pt, ov_en};
for i = 1:numel(files)
    f = files{i}; if ~exist(f,'file'), continue; end
    txt = fileread(f);
    is_pt = contains(f, '_pt');
    lines = cell(height(Tt),1);
    for r = 1:height(Tt)
        if is_pt
            lines{r} = sprintf('%d & %s & %s & %s & %s \\\\', Tt.tau_b(r), ...
                fmt_br(Tt.Pnao_max_kW(r)), fmt_br(Tt.Energia_nao_kWh(r)), ...
                fmt_br(Tt.Fallback_pct(r)), fmt_br(Tt.t_qp_med(r)));
        else
            lines{r} = sprintf('%d & %.2f & %.2f & %.2f & %.3f \\\\', Tt.tau_b(r), ...
                Tt.Pnao_max_kW(r), Tt.Energia_nao_kWh(r), Tt.Fallback_pct(r), Tt.t_qp_med(r));
        end
    end
    i0 = regexp(txt, '(?m)^1 & 350.*\\\\$', 'start', 'once');
    if isempty(i0)
        i0 = regexp(txt, '(?m)^1 & .*\\\\$', 'start');
        % pick one near tab:tau
        i0 = [];
        idxs = regexp(txt, '(?m)^1 & .*\\\\$');
        for k = 1:numel(idxs)
            ctx = txt(max(1,idxs(k)-500):idxs(k));
            if contains(ctx, 'tab:tau') || contains(ctx, 'tau_b')
                i0 = idxs(k); break;
            end
        end
    end
    if isempty(i0), continue; end
    chunk = txt(i0:end);
    [~, ends] = regexp(chunk, '(?m)^\d+ & .*\\\\$', 'start', 'end');
    if numel(ends) < 3, continue; end
    i1 = i0; i2 = i0 + ends(min(3,numel(ends))) - 1;
    txt2 = [txt(1:i1-1), strjoin(lines, newline), txt(i2+1:end)];
    fid = fopen(f,'w'); fwrite(fid, txt2); fclose(fid);
    fprintf('Patched tau %s\n', f);
end
end
