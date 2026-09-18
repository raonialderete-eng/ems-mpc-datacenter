from pathlib import Path
import csv
OUT=Path(__file__).resolve().parent/'MATRIZ_REVISORES.csv'
ITEMS={
1:[
('Validação experimental/HIL','laboratorio','Executar sessão física após preparação; preservar evidência SIL separada.'),
('Traces reais AI/HPC','principal,windows','Usar NVML medido e DIPLOEE identificado como simulação; documentar transformação e janelas.'),
('Dependência do timing de foresight','timing,gate','Reexecutar com medição presente correta e avaliar falha do arm8.'),
('Incerteza probabilística de previsão','montecarlo','200 realizações pareadas; intervalos e frequência de piora.'),
('Fairness dos baselines','fairness','Limites comuns e retuning documentado dos cinco controladores.'),
('Sensibilidade dos pesos MPC','pesos','Fatores 0.1/1/10 e diagnóstico numérico.'),
('Fidelidade BESS/UPS','plant_sensitivity','Sensibilidade tau e discussão explícita de eficiência, temperatura, envelhecimento e SOC.'),
('Arquitetura elétrica multiunidade','handoff','Discussão futura de múltiplas UPS, conversores, redundância e gerador; não implementado.'),
('Definição de carga crítica','handoff','Declarar criticidade integral e discutir classes/prioridades/corte de cargas.'),
('Alegação computacional de tempo real','laboratorio','Medir ciclo completo e headroom; não inferir implantação a partir do solver.'),
('Interpretação da falta longa','long_outage','Explicar potência/energia, recarga posterior e papel do gerador/redundância.'),
('Posicionamento na literatura','handoff','Tabela comparativa por informação, continuidade, dinâmica e ablações.'),
('Reprodutibilidade','auditoria','Congelar entradas, parâmetros, sementes, código e resultados.'),
('Generalização das conclusões','handoff','Limitar eventos/modelo/dados; nenhuma garantia contra falhas aleatórias.')],
2:[
('Formulação QP completa','auditoria','Exportar mapas, objetivo, restrições, folgas e normalizações para o apêndice futuro.'),
('Caracterização AI/HPC insuficiente','principal,windows','Traces medidos e simulado identificados; estatísticas de janelas e rampas.'),
('Eventos agendados versus imprevisíveis','alarm,detection','Separar informação anunciada, corrente e detecção atrasada.'),
('Ablações para isolar foresight e otimização','ablacao','Previsão só carga, sem antecipação, horizonte1 e sem restrição evento; estocástico adicional.'),
('Timing, eventos perdidos e falsos positivos','timing,alarm,montecarlo','Sweep denso, alarmes e erros combinados; não prometer mitigação pelo gate.'),
('Explicar fallback do solver','pesos,principal','Instantes, exitflags, resíduos e ações alternativas por passo.'),
('Validar predição SOC e seleção de sinal','principal,plant_sensitivity','Comparar com integração por trechos, contar trocas de sinal e erro SOC.'),
('Retuning e restrições dos baselines','fairness','Demonstrar influência de dU/pesos e usar restrições físicas comuns.'),
('Pesos, normalização e condicionamento','pesos','Hessiana, Gram de restrições regularizada, resíduos e compromisso entre métricas.'),
('Expressão physical floor','handoff','Usar limite instantâneo específico do cenário e suas hipóteses.'),
('Alegações UPS além do modelo','handoff','Limitar a continuidade de carga apoiada por BESS; sem transferência/DC-link/bypass/qualidade elétrica.'),
('Avaliação determinística única','montecarlo,windows,plant_sensitivity','Repetições pareadas e variação SOC/tau; probabilidades condicionadas ao modelo ensaiado.'),
('Tempo completo, percentis e warm-start','auditoria,laboratorio','Montagem, solver, ciclo, iterações, percentis e teste específico de X0.'),
('SOC final na falta longa','long_outage','Documentar início, fim, duração, recarga e SOC mínimo/final.'),
('Métricas operacionais adicionais','principal,timing,long_outage','Limiares, SOC nos eventos, energia, throughput, EFC, esforço e recuperação sustentada.'),
('Referência retratada e metadados','handoff','Conferir remoção local e revalidar bibliografia na redação; não publicar sem auditoria.'),
('Repositório permanente','auditoria,handoff','Preparar pacote reproduzível; publicação externa não autorizada nesta etapa.')],
3:[
('Tabela de comparação com literatura','handoff','Tabela futura de contribuição e diferenças, com referências verificadas.'),
('Estatística dos erros de previsão','montecarlo','Intervalos e resultados pareados em 200 realizações.'),
('Justificação e sensibilidade dos pesos','pesos','Variação de pesos, escala e justificativa por objetivos/métricas.'),
('Dinâmica simplificada e ranking','plant_sensitivity','Comparar os cinco controladores sob tau=1/2/4 s.'),
('Picos iguais em faixas e limite','principal,handoff','Mostrar degrau ativo/condições que produzem pico igual; não tratar como erro de cópia.')],
4:[
('Novidade científica aplicada','handoff','Delimitar contribuição comparativa e região de validade.'),
('Validação insuficiente','laboratorio','Preparar e depois executar evidência física, separada de SIL.'),
('Cargas reais ou datasets estabelecidos','principal,windows','Dataset local oficial; NVML medido versus DIPLOEE simulado.'),
('Suposição de previsão e timing','timing,montecarlo','Erros, alarmes e análise probabilística.'),
('Comparar outro EMS estabelecido','principal,probabilities','MPC estocástico de três cenários; fundamentação metodológica no handoff.'),
('Justificar pesos de muitas ordens','pesos','Normalização, sensibilidade e diagnóstico.'),
('Evidência de tempo real em hardware','laboratorio','Prazos ponta a ponta na DE2-115; ainda pendente de placa.'),
('Degradação e custo da bateria','principal,long_outage,handoff','Throughput/EFC como proxies; sem alegar vida útil ou custo de reposição não modelado.'),
('Modelo conversor/UPS simplificado','plant_sensitivity,handoff','Sensibilidade de ranking e limites do modelo agregado.'),
('Robustez estatística','montecarlo,windows','Resultados pareados e representatividade limitada das janelas.'),
('Especificidade de data center','handoff','Clarificar cargas, restrições, continuidade e diferença frente a microrrede genérica.'),
('Conclusões qualificadas','handoff','Não afirmar superioridade fora das condições testadas.')],
5:[
('Precisão temporal mínima necessária','timing,montecarlo','Mapear região empírica de benefício e degradação; não prometer garantia universal.'),
('Míope pior que heurístico e tuning','fairness','Reexecutar limites equivalentes e explicar resultados do retuning.'),
('Título e escopo mais amplos que evidência','handoff','Alinhar título/resumo/discussão/conclusões na revisão textual futura.'),
('Autonomia, SOC, recuperação e geradores','long_outage,handoff','Quantificar métricas disponíveis; coordenação com gerador apenas discussão.'),
('Limitações de modelo, ruído e execução','plant_sensitivity,laboratorio,handoff','Não alegar deployment; explicitar parâmetros não identificados e ruído não modelado.')]
}
def main():
    assert not OUT.exists()
    with OUT.open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f); w.writerow(['id','comentario_resumido_nao_literal','grupos_dependencias','acao','situacao','evidencia','pendencia'])
        for reviewer,items in ITEMS.items():
            for i,(comment,groups,action) in enumerate(items,1):
                ident=f'R{reviewer}.{i}' if reviewer!=4 else f'R4.C{i}'
                status='pendente_redacao' if groups=='handoff' else ('preparacao_sem_placa' if groups=='laboratorio' else 'ver_andamento_por_job')
                w.writerow([ident,comment,groups,action,status,'IEEE_ACESS_PARECER.pdf; jobs.json; resultados por execução','Validar evidência antes de fechar comentário'])
    print('53 comments mapped; R4.C IDs assigned in paragraph order (original unnumbered).')
if __name__=='__main__':main()
