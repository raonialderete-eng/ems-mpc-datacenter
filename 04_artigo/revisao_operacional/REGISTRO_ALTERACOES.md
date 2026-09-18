# Registro de alterações e decisões

## Preservação

Nenhum arquivo anterior do MATLAB, dataset, resultados, artigo, carta ou FPGA foi alterado. A implementação nova foi colocada em subpastas próprias. `inventario_original.json` permite conferir esse compromisso.

## Erros e correções da nova linha experimental

1. **Origem das cargas:** reconstrução antiga e dataset oficial separados. O nome histórico Alibaba não foi alterado; novos cenários usam `nvml_llama2`. A potência normalizada não é rotulada como utilização GPU medida.
2. **Gerador:** novo script offline lê DIPLOEE e 16 logs NVML diretamente. Não possui fallback sintético. Cria 42 perfis em diretório novo; registra hashes, janelas e transformação. Os logs possuem somente aproximadamente 2.075 s de sobreposição, portanto janelas aleatórias de 1.200 s não são independentes e podem se sobrepor.
3. **Informação:** todos os controladores recebem a medição atual; apenas os antecipativos recebem o horizonte previsto. O cenário de detecção atrasada é separado e atrasa L/M/G, mantendo SOC e potência anterior como telemetria disponível.
4. **Normalização:** fixada em Pbase=950 kW, Rbase=100 kW/s para os QPs da campanha auditada. Isso remove a dependência da V5 do máximo da trajetória completa e a variação instantânea da base do míope. É uma alteração de protocolo, não simples reprodução dos números anteriores.
5. **Integração:** o endpoint de 1.201 amostras não acrescenta um segundo fictício à energia de 1.200 intervalos. Publicam-se energia/pico brutos e filtrados.
6. **Recuperação:** por início de déficit estrutural ou perda de rede, com 10 s sustentados abaixo de 1 kW. Uma recuperação após o pico global isolado não representa necessariamente recuperação do evento seguinte.
7. **Estocástico:** sequência de comandos compartilhada, variáveis auxiliares por cenário, probabilidades 1/3. Limites comuns são a interseção das restrições dos cenários; cenário duplicado tem probabilidades agregadas, sem mudar o custo esperado. Mantém política nominal de fallback; não oculta fallback como sucesso do solver.
8. **Fairness:** campanha própria com limites iguais 120/200/400 e limitador supervisório comum fora de emergência. A campanha principal preserva as políticas originais dos controladores; não deve ser confundida com a campanha de limites iguais.
9. **Diagnóstico:** condest(H) e condicionamento regularizado de C' C no primeiro passo. Este último é um diagnóstico da matriz Gram, não cond(C), e a regularização/rank deficiency devem ser explicitadas. Resíduos e erros SOC são registrados por passo.
10. **Warm-start:** o R2025b local passa X0 às funções internas IPM; não foi assumido que ele é ignorado. A implementação auditada inicia com X0 vazio e não alega aceleração por warm-start. Teste específico registra efeito sobre solução/iterações/tempo.
11. **Laboratório:** rotinas novas não escrevem em `hil_de2115/`. Medem ciclo completo e separam solver de comunicação/planta. Placa não disponível; qualquer tabela física permanece pendente.

## Interpretações que não devem ser mantidas automaticamente

- O gate arm8 solucionou timing: contradito pela campanha anterior.
- Míope não pode zerar sem horizonte: contradito no caso retunado, segundo métrica filtrada.
- Todo perfil do dataset oficial é medição de instalação: incorreto; DIPLOEE é simulado.
- Zero filtrado é zero matemático: incorreto.
- N=20 no Monte Carlo anterior: o código/CSV possuem 12 atrasos.
- SIL confirma execução na DE2-115: incorreto.
- A política preditiva domina em falta prolongada: energia não atendida anterior do MPC foi maior.

Todos esses pontos alimentam o handoff, sem modificar texto ou conclusões do artigo nesta etapa.
