%% MAIN_SIL_HIL_FPGA
% Software-in-the-loop com o mesmo protocolo/metricas do HIL fisico.
% backend matlab_fpga: roda neste PC (sem Quartus).
% Depois, no lab, repetir com 'serial'.

this_dir = fileparts(mfilename('fullpath'));
cd(this_dir);

cenarios = {'carga_faixas', 'limite_fonte', 'perda_fonte', 'retorno_fonte'};
controles = {'heur', 'mpc'};

for ic = 1:numel(cenarios)
    for it = 1:numel(controles)
        fprintf('\nSIL %s / %s\n', controles{it}, cenarios{ic});
        hil_loop_de2115('backend', 'matlab_fpga', ...
            'controle', controles{it}, 'cenario', cenarios{ic});
    end
end

gerar_evidencia_ieee_fpga();
