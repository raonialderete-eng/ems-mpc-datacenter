# Plano operacional aprovado — implementação

## Sequência

1. Fase 0: inventário imutável, dataset local, protocolo causal, métricas brutas/filtradas e registros de achados.
2. Fase 1a: fairness, ablações, pesos, SOC/fallback, timing, alarmes, sensibilidade, janelas e 200 realizações pareadas.
3. Fase 1b: MPC estocástico nominal/carga+20%/evento−10s, probabilidades iguais, comparação de cinco controladores e sensibilidade 50/25/25.
4. Fase 2: scripts e pacote para DE2-115; testar localmente o disponível; placa e compilação FPGA pendentes.
5. Handoffs: artigo e laboratório retomáveis em outras conversas.

## Condições fixadas

- Não baixar dataset nem editar artigo/carta/PDF.
- Não sobrescrever histórico nem reutilizar checkpoint incompatível.
- Novos resultados em diretórios separados com impressão digital.
- Não declarar experimentos concluídos só porque scripts existem.
- Erros de protocolo/métricas geram nova campanha, preservando a anterior.
- Não ajustar métodos para forçar o resultado esperado.

## Critérios de aceite

- Integridade dos arquivos anteriores verificada por hash.
- Testes de equivalência V5/cenários idênticos, causalidade, balanço e parser aprovados.
- Jobs concluídos possuem série, parâmetros, diagnóstico e configuração.
- Análises indicam quantidade efetiva de jobs e estado parcial/completo.
- Todos os 53 comentários têm ação ou delimitação de escopo e orientação de redação.
- Scripts de bancada salvam por sessão e não alegam HIL sem coleta física.

## Acompanhamento

`jobs.json` contém 1.755 jobs pré-registrados. Para cada execução, `fingerprint.txt` identifica a configuração e `jNNNNN.mat` comprova conclusão de um job. O log informa START/DONE, pico bruto/filtrado, energia, fallback e duração. As análises versionadas produzem `status.json` e tabelas.

Os estados da matriz devem ser interpretados junto do status efetivo: implementado, executado, validado e pronto para incorporação são etapas distintas. Comentários textuais permanecem pendentes até a redação do manuscrito; hardware permanece pendente até a bancada.
