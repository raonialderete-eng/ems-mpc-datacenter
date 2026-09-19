function P = ems_pack_paths(here)
% Resolve dataset/campaign/trace/figure directories for the full repo or
% an extracted reviewer pack (no hardcoded machine path).
if nargin < 1 || isempty(here)
    here = pwd;
end
P.root = locate_root(here);
pack = isfolder(fullfile(P.root,'dataset_v1')) && isfolder(fullfile(P.root,'matlab_base'));
P.dataset = first_existing({ ...
    fullfile(P.root,'dataset_v1'), ...
    fullfile(P.root,'05_resultados','revisao_operacional','dataset_v1')});
P.campanha = first_existing({ ...
    fullfile(P.root,'campanha_v1_principal'), ...
    fullfile(P.root,'05_resultados','revisao_operacional','campanha_v1')});
P.traces = first_existing({ ...
    fullfile(P.root,'traces_figuras'), ...
    fullfile(P.root,'05_resultados','figuras_comparativas','traces_campanha_v1')}, true);
if isempty(P.traces)
    if pack
        P.traces = fullfile(P.root,'traces_figuras');
    else
        P.traces = fullfile(P.root,'05_resultados','figuras_comparativas','traces_campanha_v1');
    end
end
if pack
    P.figuras = fullfile(P.root,'figuras_artigo');
else
    P.figuras = fullfile(P.root,'04_artigo','ieee_access','figuras');
end
P.alt_figuras = first_existing({ ...
    fullfile(P.root,'05_resultados','figuras_comparativas'), ...
    P.figuras}, true);
if isempty(P.alt_figuras)
    P.alt_figuras = P.figuras;
end
end

function root = locate_root(here)
d = here;
for k = 1:8
    if isfolder(fullfile(d,'dataset_v1')) && isfolder(fullfile(d,'matlab_base'))
        root = d; return;
    end
    if isfolder(fullfile(d,'05_resultados','revisao_operacional','campanha_v1')) ...
            && isfolder(fullfile(d,'01_matlab_base'))
        root = d; return;
    end
    nd = fileparts(d);
    if strcmp(nd, d), break; end
    d = nd;
end
error('ems_pack_paths: cannot find pack or repository root from %s', here);
end

function p = first_existing(cands, allow_empty)
if nargin < 2, allow_empty = false; end
p = '';
for i = 1:numel(cands)
    if isfolder(cands{i})
        p = cands{i}; return;
    end
end
if ~allow_empty
    error('ems_pack_paths: none of the candidate directories exist');
end
end
