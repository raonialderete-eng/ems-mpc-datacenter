# Revisão operacional — entrada principal

Esta área implementa a revisão experimental. **Artigo, carta, PDFs, dados brutos e resultados históricos não são editados.**

## Documentos

- `HANDOFF_DE2115.md`: guião da bancada DE2-115.
- `MATRIZ_REVISORES.csv`: um registro por comentário, com identificador e ação.
- `REGISTRO_ALTERACOES.md`: decisões, erros encontrados e limitações.
- `inventario_original.json`: hashes SHA-256 e tamanhos de todos os arquivos anteriores nas pastas inventariadas.
- `jobs.json`: especificação pré-registrada dos 1.755 jobs; não editar para retomar uma campanha existente.

## Entradas e código

Dataset oficial local em `dataset/`; a preparação não tem acesso de rede e não contém downloader.
Perfis novos: `05_resultados/revisao_operacional/dataset_v1/`.
Implementação MATLAB: `01_matlab_base/revisao_operacional/`.
Scripts da bancada: `07_fpga/revisao_operacional/`.

O builder foi derivado das seções 0–15 da V5, com origem registrada. O simulador novo usa intervalos físicos (1.200 passos, 1.201 estados), informação presente corrigida e Pbase fixo de 950 kW para os QPs. As campanhas históricas continuam utilizando seus próprios arquivos intactos.

## Executar ou retomar

No PowerShell, na raiz do projeto:

```powershell
& ./04_artigo/revisao_operacional/continuar_campanha.ps1 -RunId campanha_final -Groups 'principal,fairness,ablacao,pesos,timing,gate,magnitude,alarm,detection,plant_sensitivity,windows,montecarlo,probabilities,long_outage'
```

A primeira execução cria a pasta. A retomada ignora somente jobs completos da mesma impressão digital. Arquivos `.partial` não contam como conclusão. Não iniciar dois processos com o mesmo RunId. Se houver `RUNNING.lock` após interrupção forçada, confirmar que nenhum processo ainda está usando a pasta antes de remover apenas esse lock.

Se o código/configuração mudar, criar outro RunId. Nunca apagar resultados antigos para forçar retomada.

Para consolidar evidências, chamar `analisar_resultados.py --run <pasta-da-campanha> --output <nova-pasta-de-análise>` com Python contendo NumPy, SciPy e Matplotlib. A pasta de saída deve ser nova. A análise parcial não significa campanha completa.

## Critérios de status

- **Implementado:** código e protocolo existem.
- **Executado:** há arquivo de resultado e log.
- **Validado:** verificações técnicas e interpretação examinadas.
- **Pronto para incorporação:** evidência revisada e referência para o handoff.
- **Pendente de laboratório:** depende da DE2-115, Quartus ou compilador C indisponível.

O tempo total depende de 1.755 simulações, inclusive 200 realizações pareadas dos cinco controladores. O progresso é o número de arquivos `j*.mat` completos. Não tratar a criação dos scripts como execução dos experimentos.
