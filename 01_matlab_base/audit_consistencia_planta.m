function rel = audit_consistencia_planta(param)
% AUDIT_CONSISTENCIA_PLANTA
% Verifica índices k/k+1, saturações e alinhamento do preditor SOC (1 passo).
% Roda um degrau de descarga e um de carga; imprime e devolve relatório.

if nargin < 1 || isempty(param)
    param = parametros();
end

rel = struct();
tol = 1e-9;

%% 1) Degrau de descarga: u = PBESS_max

SOC0 = 50;
PBESS0 = 0;
u = param.PBESS_max;
Pload = 750;
Pmax = 800;
g = 1;

[SOC1, PBESS1, Psource, Pnao] = planta_bess(SOC0, PBESS0, u, Pload, Pmax, g, param);

% Dinâmica esperada
PBESS1_esp = param.ab * PBESS0 + param.bb * u;
PBESS1_esp = min(max(PBESS1_esp, param.PBESS_min), param.PBESS_max);

% Balanço após PBESS(k+1)
Psource_esp = min(max(Pload - PBESS1, 0), Pmax);
Pnao_esp = max(Pload - Psource_esp - PBESS1, 0);

% SOC descarga
dSOC_esp = (PBESS1 * param.Ts / 3600) / (param.Ebat * param.eta_descarga) * 100;
SOC1_esp = min(max(SOC0 - dSOC_esp, param.SOC_min), param.SOC_max);

rel.descarga.PBESS_ok = abs(PBESS1 - PBESS1_esp) < tol;
rel.descarga.Psource_ok = abs(Psource - Psource_esp) < 1e-6;
rel.descarga.Pnao_ok = abs(Pnao - Pnao_esp) < 1e-6;
rel.descarga.SOC_ok = abs(SOC1 - SOC1_esp) < 1e-6;
rel.descarga.PBESS1 = PBESS1;
rel.descarga.SOC1 = SOC1;
rel.descarga.Pnao = Pnao;

%% 2) Degrau de carga: u = PBESS_min

u = param.PBESS_min;
[SOC1c, PBESS1c, Psource_c, Pnao_c] = planta_bess(SOC0, PBESS0, u, Pload, Pmax, g, param);

PBESS1c_esp = param.ab * PBESS0 + param.bb * u;
PBESS1c_esp = min(max(PBESS1c_esp, param.PBESS_min), param.PBESS_max);
dSOC_c = (PBESS1c * param.Ts / 3600) * param.eta_carga / param.Ebat * 100;  % negativo
SOC1c_esp = min(max(SOC0 - dSOC_c, param.SOC_min), param.SOC_max);

% Preditor Pd/Pc alinhado
K0 = (param.Ts / 3600) / param.Ebat * 100;
Kd = K0 / param.eta_descarga;
Kc = K0 * param.eta_carga;
Pd = max(PBESS1c, 0);
Pc = max(-PBESS1c, 0);
SOC_pred = SOC0 - Kd * Pd + Kc * Pc;

rel.carga.SOC_planta = SOC1c;
rel.carga.SOC_pred_PdPc = SOC_pred;
rel.carga.erro_pred_vs_planta = SOC_pred - SOC1c;
rel.carga.alinhado = abs(SOC_pred - SOC1c) < 1e-6;
rel.carga.PBESS_ok = abs(PBESS1c - PBESS1c_esp) < tol;

%% 3) Preditor antigo (η único) vs planta na carga

eta = 0.95;
Ksoc_old = (param.Ts / 3600) / (param.Ebat * eta) * 100;
SOC_old = SOC0 - Ksoc_old * PBESS1c;  % PBESS1c < 0 => sobe demais
rel.carga.SOC_pred_antigo = SOC_old;
rel.carga.erro_antigo_pct_rel = 100 * (SOC_old - SOC1c) / max(abs(SOC1c - SOC0), eps);

%% Impressão

fprintf('\n=== AUDIT CONSISTENCIA PLANTA ===\n');
fprintf('Descarga: PBESS=%d Psource=%d Pnao=%d SOC=%d\n', ...
    rel.descarga.PBESS_ok, rel.descarga.Psource_ok, rel.descarga.Pnao_ok, rel.descarga.SOC_ok);
fprintf('  PBESS1=%.4f SOC1=%.6f Pnao=%.4f\n', PBESS1, SOC1, Pnao);
fprintf('Carga: PBESS=%d alinhamento_PdPc=%d\n', rel.carga.PBESS_ok, rel.carga.alinhado);
fprintf('  SOC_planta=%.6f SOC_PdPc=%.6f SOC_antigo=%.6f erro_antigo_rel=%.2f%%\n', ...
    SOC1c, SOC_pred, SOC_old, rel.carga.erro_antigo_pct_rel);
fprintf('=================================\n');

end
