# Handoff — sessão futura de execução na DE2-115

**Situação atualizada em 13/09/2026:** o autor já recebeu a DE2-115 e planeja estruturar os testes na semana seguinte. A indisponibilidade da placa foi uma condição da preparação inicial. Comunicação, firmware e validação física continuam pendentes; este guia não é evidência de HIL. A execução ocorrerá em outra conversa, acompanhada pelo autor. O pacote `preparacao_artigo_20260911_v1/README.md` reúne formulação, resultados corrigidos e diagnóstico numérico para definir a referência de software antes da bancada.

## 1. O que levar

- Projeto inteiro, incluindo dataset se for necessário reproduzir a campanha computacional.
- Terasic DE2-115 / Cyclone IV E EP4CE115F29C7, alimentação original e USB-Blaster.
- Comunicação RS-232 compatível com a placa; identificar adaptador e COM. USB-Blaster não substitui a UART RS-232.
- MATLAB e, para referência SIL, Optimization Toolbox.
- Uma versão coerente de Quartus/Platform Designer e Nios EDS instalada na bancada.
- Compilador C no PC ou Nios EDS. Nenhum compilador C foi encontrado no PATH nem configurado como compilador MATLAB no ambiente de preparação.

Antes de iniciar, ler `07_fpga/HANDOFF_LAB.md` como referência histórica. Os scripts novos de sessão devem ser usados para preservar resultados, pois a rotina antiga escreve em nomes fixos.

## 2. Registro da sessão

Escolher um nome novo, por exemplo `2026MMDD_heur_01`. Registrar versão Quartus/Nios/MATLAB, placa, clock, memória, firmware/bitstream, COM, baud, PC e cabos. Preservar log de compilação, mapa de memória e hashes do código. Não reutilizar nome de sessão.

As saídas novas ficam em `05_resultados/revisao_operacional/laboratorio/<sessao>/`.

## 3. Antes da UART

1. Confirmar alimentação, device e USB-Blaster.
2. Compilar/gravar o projeto hello LED já existente. Fotografar placa e Programmer.
3. Gerar o sistema Nios com a versão correta de Qsys; não misturar versões.
4. Compilar hello UART e confirmar comunicação.
5. Conferir relatório de memória antes de carregar o solver: matrizes estáticas do ADMM podem exceder a memória configurada. Não presumir que 256 KB bastam; ajustar memória no projeto somente após verificar linker/mapa e registrar a configuração.

## 4. Validar C/ADMM no PC

O pacote de cópia local fica em `07_fpga/revisao_operacional/pacote/c_golden/` quando preparado. Compilar pelo script `build_pc.ps1`, passando o caminho de GCC se ele não estiver no PATH. Executáveis e resultados devem ir para uma pasta de sessão nova.

Executar teste de protocolo C primeiro; depois teste de integração com `backend='c_exe'`. Isso é validação em software do C/ADMM, não FPGA. Comparar heurístico amostra a amostra com referência MATLAB. Para MPC, comparar KPIs, restrições e fallback, porque ADMM e quadprog não precisam produzir comandos bit a bit iguais.

Referências históricas de pico: heurístico ~90,9796 kW em faixas/limite e ~592,6123 kW em perda/retorno; MPC reduzido SIL ~0 kW filtrado e ~351,1695 kW na perda/retorno. Usar também a referência nova da sessão, com métricas brutas.

Critérios: heurístico com erro de pico <1e-3 kW; MPC com diferença de pico <=2 kW em relação ao SIL reduzido como critério inicial de engenharia. Qualquer violação física, resposta inválida ou fallback recorrente deve ser investigado, mesmo se o pico atender ao critério. Esse limiar não prova equivalência de trajetórias.

## 5. Testar parser MATLAB e gerar referência SIL

Na raiz do projeto, no MATLAB:

```matlab
root = pwd;
addpath(fullfile(root,'07_fpga','revisao_operacional'));
testar_protocolo;
executar_sessao_de2115(root,'sil_referencia_01','matlab_fpga');
```

A referência executa heurístico e MPC nos quatro cenários. A pasta precisa ser nova. Arquivos `_steps.csv` contêm séries por intervalo; `_summary.csv` contêm métricas e tempos; `_protocol.txt` documenta requisições.

## 6. Executar C por pipe

```matlab
executar_sessao_de2115(root,'c_pc_01','c_exe','', ...
    fullfile(root,'07_fpga','revisao_operacional','build_pc','ems_golden.exe'));
```

Se o build estiver em outra pasta, usar seu caminho real. O script rejeita respostas inválidas e não espera indefinidamente pelo processo. Um arquivo `_FAILED.mat` preserva o contexto de falhas.

## 7. Gravar firmware e executar HIL físico

Compilar o firmware e gravar bitstream/ELF seguindo o projeto local. Validar clock e contador usado no tempo do solver: a resolução e origem de `clock()` no Nios precisam ser verificadas; se inválidas, usar o temporizador do BSP e registrar a mudança. O tempo completo medido no PC permanece separado do tempo informado pelo firmware.

Para o modo HIL, usar SW[0]=1. Selecionar primeiro heurístico com SW[2]=0 e reiniciar. Depois MPC com SW[2]=1 e reiniciar. Confirmar o significado no firmware efetivamente compilado.

```matlab
executar_sessao_de2115(root,'placa_heur_01','serial','COM3','',{'heur'});
% Depois de mudar o modo do firmware e reiniciar:
executar_sessao_de2115(root,'placa_mpc_01','serial','COM3','',{'mpc'});
```

Substituir COM3 pela porta identificada. O script exige porta explícita e apenas um controlador por sessão física, evitando alternância silenciosa de modo. Cada sessão executa faixas, limite, perda e retorno. O laço físico é cadenciado em Ts=1 s; a espera deliberada não entra no tempo de processamento.

## 8. Critérios de parada e diagnóstico

- Sem resposta / timeout: conferir COM, baud 115200, modo HIL, firmware, cabeamento e nível elétrico.
- Resposta truncada, NaN ou comando fora dos limites: interromper; preservar `_FAILED.mat` e protocolo.
- Heurístico divergente: corrigir protocolo/planta/parametrização antes de avaliar MPC.
- Pico MPC divergente, fallback alto ou violações: conferir parâmetros, convergência ADMM e resíduos; não diminuir iterações para apenas aparentar tempo real.
- Ciclo >1 s: registrar overrun; não declarar cumprimento do prazo. Rever implementação/horizonte em uma campanha nova.
- Falha de link: examinar consumo real de memória e mapa do linker.

## 9. O que guardar e como fechar

Guardar fotos, relatórios de compilação, mapa de memória, configuração de clock, bitstream/ELF, hashes, metadata, CSVs por passo, resumos e protocolo. Executar `comparar_sessoes.py` para produzir uma tabela em pasta nova.

Separar quatro evidências: V5 no MATLAB, horizonte reduzido no MATLAB, C/ADMM no PC e controlador na DE2-115. A planta permanece no PC. Não afirmar validação de uma UPS física nem de data center de MW. O competidor estocástico continua sendo computacional.

Ao terminar, atualizar o handoff do artigo com os resultados físicos realmente observados, limitações e referências exatas aos arquivos.
