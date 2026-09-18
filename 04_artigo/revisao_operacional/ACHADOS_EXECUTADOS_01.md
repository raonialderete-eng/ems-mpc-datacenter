# Evidências já executadas — comparação principal e preparação

## Status desta fotografia

- 35/35 jobs da comparação principal executados na `campanha_v1`.
- As demais campanhas não estão incluídas nesta fotografia; consultar log e arquivos por job.
- Testes iniciais de equivalência, causalidade e balanço aprovados.
- Teste MATLAB do parser: 1 mensagem válida e 7 inválidas, todos aprovados.
- Teste de X0: 20 execuções, solução idêntica e 12 iterações em todas.
- Sessão SIL nova: oito execuções, quatro cenários vezes heurístico/MPC reduzido.
- 3.508 arquivos anteriores verificados por SHA-256: nenhuma alteração.
- 42 perfis oficiais derivados verificados contra seus CSVs e dados locais.

## Comparação principal — pico bruto, kW

| Cenário | Heurístico | Heur+FS | Míope | MPC auditado | Estocástico |
|---|---:|---:|---:|---:|---:|
| Faixas | 90,9796 | 4,6748 | 102,7827 | 0,018079 | ~0 |
| Limite | 90,9796 | 4,6748 | 102,7826 | ~0 | ~0 |
| Perda | 592,6123 | 362,4662 | 592,6116 | 350,0674 | 350,0003 |
| Retorno | 592,6123 | 362,4662 | 592,6116 | 350,0897 | 350,0003 |
| Multi-burst | 90,9796 | 60,6531 | 108,8988 | 0,018157 | ~0 |
| DIPLOEE stress | 2,6737 | 2,6737 | 0,0000697 | 0,002215 | ~0 |
| NVML stress | 52,7336 | 48,5075 | 28,3749 | 0,006558 | ~0 |

`~0` significa arredondamento de resíduos da ordem de 1e-14 kW. Valores exatos estão no CSV. Os déficits abaixo de 1 kW viram zero na métrica filtrada.

Fonte: `05_resultados/revisao_operacional/analise_principal_01/`. As alterações de normalização, causalidade e tratamento do endpoint impedem atribuir diferenças entre campanhas somente ao controlador.

## Benefício versus reserva

O estocástico apresenta picos iguais ou menores nestes sete casos, mas usa mais reserva:

- Faixas: SOC final 53,36% versus 58,80% do MPC determinístico.
- Limite: 38,28% versus 50,83%.
- Perda: 49,55% versus 57,10%.
- NVML: 41,42% versus 51,91%.

Portanto, ainda não há sustentação para dizer que o estocástico domina. A avaliação de erros, autonomia, EFC e SOC inicial é necessária. Não ajustar o peso após observar esses resultados para esconder o custo de reserva.

Na perda, fallback foi 0,167% no estocástico e 1,583% no determinístico. Resíduos de tentativas malsucedidas permanecem nos diagnósticos; separar tentativas de solver das ações realmente aplicadas.

O preditor SOC apresentou erro máximo de aproximadamente 0,1223 ponto percentual no estocástico da perda, contra 0,0146 no determinístico. Esse é um diagnóstico da linearização, não uma violação física demonstrada. A análise de sensibilidade deve verificar a importância desse erro perto dos limites de SOC.

## Sessão SIL nova

Saídas em `05_resultados/revisao_operacional/laboratorio/sil_preparacao_01/`.
Picos do MPC reduzido: 0,0063 kW bruto em faixas; aproximadamente zero em limite; 351,1695 kW em perda e retorno. Os quatro casos ficaram abaixo de 1 s de ciclo no ensaio observado, mas não constituem teste físico nem prova de WCET.

Compilação C/ADMM e execução física seguem pendentes por ausência de compilador configurado e de placa. O pacote, parser endurecido e comandos de compilação foram preparados, não declarados compilados.
