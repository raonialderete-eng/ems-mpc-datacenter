# Handoff — futura revisão do artigo e resposta aos cinco revisores

## Como retomar em outra conversa

Pedido sugerido: “Leia este handoff, o registro de alterações, a matriz dos revisores e os resultados consolidados mais recentes. Revise o artigo e a carta sem transformar testes pendentes em resultados. Confirme primeiro o status da bancada DE2-115.”

R2.17 (código/dados permanentes): **depois** do HIL congelado. Lista de empacotamento em `R2.17_PACOTE.md`. Não abrir GitHub/Zenodo só com SIL.

O artigo, PDFs, conclusões e carta existentes **não foram alterados nesta etapa operacional**. O documento principal anterior é `04_artigo/ieee_access/artigo_ems_mpc_datacenter_access.tex`. A fonte autoritativa dos comentários continua sendo `04_artigo/IEEE_ACESS_PARECER.pdf`, com cinco revisores. A matriz operacional usa resumos, não citações literais; transcrever os comentários do PDF na carta final.

## 1. Histórico das cargas

Inicialmente foram usados perfis sintéticos inspirados em Vercellino, com plateau de treino e bursts de inferência, reescalados para 600–950 kW. O autor posteriormente baixou o dataset oficial de aproximadamente 1 GB, já presente em `dataset/`, e solicitou a reexecução. Essa transição explica nomes e textos antigos persistentes.

A campanha anterior de 07/09 possui 68 jobs. O bloco de perfis foi reexecutado em 09/09. Não confundir o marcador de conclusão da primeira campanha com a atualização posterior.

Os perfis novos nesta revisão são preparados por `preparar_dataset.py`, sem download:

- `diploee_facility_*`: simulação de instalação do próprio dataset, amostrada originalmente por minuto.
- `nvml_llama2_*`: potência GPU medida dos 16 nós, com agregação/interpolação e transformação afim.
- `*_stress`: seleção por maior amplitude, caracterizada como estresse.
- `*_window01` a `*_window20`: seleção aleatória pré-registrada. Há sobreposição; não alegar 20 instalações ou 20 experimentos independentes.

O nome Alibaba no histórico não identifica uma fonte independente nos CSVs de 09/09. A coluna nova é `power_normalized`, evitando confusão com utilização GPU medida. O manifest do dataset novo registra fonte, hash, janela e transformação.

## 2. Formulação e protocolo auditados

O QP determinístico é derivado da V5 histórica, com builder separado e solver comum ao novo competidor. A normalização dos QPs auditados é fixa: Pbase=950 kW; Rbase=100 kW/s. A V5 histórica calculava sua base usando a trajetória completa, e o míope usava valores instantâneos. Essa mudança deve constar do método e da comparação entre campanhas.

O instante corrente é medido; o futuro é previsto. Para eventos sem aviso, nenhum controlador recebe a interrupção futura. Atraso de detecção é ensaio separado, com atraso de L/M/G e SOC/potência anterior disponíveis. A ordem física é: medição em k, comando em k, potência do BESS em k+1, balanço e atualização do SOC. A planta permanece agregada de primeira ordem; zero a Ts=1 s não comprova continuidade elétrica subsegundo.

As métricas integram 1.200 intervalos para 1.201 estados. Pico e energia brutos acompanham valores filtrados. O limiar filtrado é max(1 kW, 0,1% da carga máxima). Recuperação é definida por evento, com 10 s sustentados abaixo de 1 kW. Não confundir zero filtrado com zero matemático.

O preditor SOC mantém a linearização da V5; erros contra a integração por trechos, trocas de sinal e violações são diagnósticos, não uma alegação de que o problema foi eliminado. Fallback integra a política de controle e deve ser reportado com suas causas.

## 3. Quinto competidor

MPC estocástico por três cenários: nominal, carga futura +20%, interrupção anunciada 10 s adiantada; probabilidades iguais. Sequência inteira de comandos compartilhada; estados previstos e variáveis auxiliares próprios dos cenários. Apenas a primeira ação é aplicada.

O horizonte principal é 60/15, Ts=1 s, mesma planta e pesos auditados. Sem evento anunciado, o cenário adiantado coincide com o nominal. Cenários idênticos são fundidos somando probabilidades, sem alterar o problema matemático. A carga alta não é truncada em 950 kW. O método é uma formulação de MPC por cenários construída neste projeto; citar fontes primárias sobre esse método depois de verificar referências, sem apresentá-lo como reprodução fiel de uma política estocástica específica da literatura.

Não confundir “três cenários internos de otimização” com “três casos externos de teste”. Todos os competidores atuam na mesma realização externa. Sensibilidade secundária usa probabilidades 0,50/0,25/0,25.

## 4. Evidências e interpretação

Consultar `status.json` de cada pasta de análise para saber quantos jobs foram realmente concluídos. A existência de `jobs.json` ou de scripts **não comprova execução**. Os arquivos `jNNNNN.mat` contêm série, parâmetros, diagnósticos, job e impressão digital. A análise produz:

| Arquivo | Uso futuro |
|---|---|
| `tabela_P_unserved.csv` | Tabela principal com os cinco controladores; bruto e filtrado |
| `comparacao_cinco_controladores.csv` | Métricas complementares da comparação principal |
| `resultados_completos.csv` | Todas as campanhas e configurações |
| `fallback_eventos.csv` | Instantes, causas, comandos e déficits durante fallback |
| `montecarlo_pareado.csv` | Frequência de piora, IC binomial e diferenças pareadas |
| `comparacao_picos.png` | Figura preliminar; revisar legenda e unidades antes de publicar |

O Monte Carlo novo pré-registra 200 atrasos normais limitados a ±20 s, desvio 6 s e erro de carga uniforme entre −20% e +20%, com a mesma realização por controlador. Essas distribuições são hipóteses de ensaio, não estimativas de falhas reais. Os intervalos se referem a essa distribuição, não à população de data centers.

Não combinar linhas de execuções com diferentes impressões digitais sem comparar código, dados e parâmetros. Análises parciais devem permanecer marcadas como parciais. Ensaios de desempenho executados simultaneamente com outras cargas devem ser identificados e não usados como WCET.

## 5. Afirmações a revisar ao redigir

- **arm8:** campanha histórica não demonstrou a mitigação prometida; conferir a reexecução com medição corrente corrigida. Nunca conservar a conclusão anterior por inércia.
- **Míope:** o teste com dUmax=400 zerou a métrica filtrada no limite da fonte. O ganho não pode ser atribuído exclusivamente à ausência de horizonte; usar campanha fairness e ablações.
- **Perfis:** oficial não significa medição de instalação. Explicitar DIPLOEE versus NVML, seleção das janelas e escala.
- **Zero:** informar tolerância e mostrar valores brutos; discutir resolução temporal.
- **Falha prolongada:** na campanha antiga a energia não atendida do MPC foi maior. Distinguir ganho transitório de autonomia energética e explicar recarga após retorno.
- **Solver:** não tratar baixo pico com fallback como prova de sucesso contínuo do QP. Mostrar resíduos e causas.
- **Warm-start:** não afirmar redução de tempo sem o teste específico na versão utilizada.
- **Hardware:** SIL não é HIL físico. A preparação de scripts não valida a DE2-115.
- **Novidade:** contribuição aplicada/comparativa, região de benefício, custos e degradação sob erros. Não alegar nova teoria de MPC.

## 6. Organização da revisão textual futura

1. Introdução: tabela de literatura com informação disponível, objetivos, ablações, dados e validação; evidenciar especificidade e limites do caso AI/HPC.
2. Modelo: planta agregada, balanço, eficiência, criticidade integral assumida, potência/energia finitas e normalização.
3. Métodos: QP completo, preditor SOC, folgas, limites, tuning, informação causal e MPC por cenários.
4. Experimentos: origem dos perfis, seleção, sementes, condições comuns, ablações e grupos de incerteza.
5. Resultados: cinco competidores, benefício absoluto, SOC/throughput, falhas de previsão, fallback e computação.
6. Discussão: limites de potência específicos do caso, dinâmica simplificada, prioridade de cargas, geradores, redes redundantes, desgaste como proxy.
7. Conclusão: somente afirmações suportadas por campanhas validadas e pelo status real do laboratório.
8. Carta: comentário por comentário, cinco revisores, ação, evidência e página/linha finais. Não usar a numeração reorganizada da carta antiga.

Multibarramento, EMT/UPS detalhada e gerador em malha fechada não foram implementados neste escopo. Responder com discussão e limites explícitos. Throughput/EFC são proxies de utilização, não estimativa de vida útil.

## 7. Bancada (18/09/2026)

UART HIL heurístico nos quatro cenários curtos = SIL. ADMM no Nios cabe em 256 KB e corre; OpenCore Plus e tempo de QP impedem HIL MPC completo. FIL não foi o caminho. O manuscrito `artigo_ems_mpc_datacenter_access.tex` passou a incluir SIL/HIL e Data Availability; a carta ainda não foi reescrita. GitHub/Zenodo: lista em `R2.17_PACOTE.md` + `README_REPRODUCAO.md`; remoto ainda não aberto.
