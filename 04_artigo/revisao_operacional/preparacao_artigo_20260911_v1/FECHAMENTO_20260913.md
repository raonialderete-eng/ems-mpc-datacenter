# Fechamento da preparação técnica — 13/09/2026

## Entrega e situação

Preparação documental concluída: formulação correspondente ao código, diagnóstico numérico, argumentos sustentados pelos resultados, cinco tabelas LaTeX e 13 blocos de equações. Os resultados principais são os da consolidação corrigida: 1.755 casos selecionados, incluindo as 266 reexecuções, e 21 casos de ablação isolada em conjunto separado. Monte Carlo: 200 realizações pareadas, não 1.000 realizações independentes.

O pacote não altera manuscrito, carta de resposta, PDFs, controlador de produção ou resultados experimentais. A reescala do solver continua candidata; sua ampliação e eventual adoção exigem seguir `VALIDACAO_NUMERICA_PASSOS.md`. A disponibilidade da DE2-115 foi informada pelo autor; não houve execução física nesta preparação.

## Verificação realizada

Comando a partir da raiz:

```powershell
.\.venv_revisao\Scripts\python.exe 04_artigo/revisao_operacional/preparacao_artigo_20260911_v1/verificar_pacote.py
```

Resultado: aprovado; 33 hashes de fontes e arquivos exportados coincidem com o manifesto; cinco tabelas e 13 blocos de equações presentes; sintaxe do gerador aprovada, sem aviso de escape inválido. Verificou-se balanceamento de chaves nos fragmentos. Não houve compilação ou validação de diagramação LaTeX; isso permanece necessário ao integrar os fragmentos ao artigo. A conferência de hashes verifica integridade, não substitui validação científica ou nova execução experimental.

## Registro de alterações finais

| Arquivo | Motivo | Alteração e impacto |
|---|---|---|
| `gerar_tabelas.py` | Aviso Python por escape `\%` em strings | Strings convertidas para literais raw. Mesma saída LaTeX; tabelas existentes não foram sobrescritas. |
| `../HANDOFF_DE2115.md` | Situação da placa desatualizada | Registrada a disponibilidade informada pelo autor e a pendência de comunicação, firmware e ensaios físicos. |
| `../ANDAMENTO.md` | Registrar a entrega | Inserido fechamento documental e distinção das etapas ainda pendentes. |
| `verificar_pacote.py` | Permitir conferência repetível | Verificação somente de leitura dos hashes, sintaxe e estrutura dos fragmentos. |

As versões anteriores dos três arquivos alterados estão em `backups_fechamento_20260913/`. Este registro e o verificador são novos. O manifesto de evidências foi preservado, e todas as suas entradas passaram na conferência final.

## Pendências antes da versão final do artigo

1. Decidir a versão numérica definitiva; ampliar validação e reexecutar casos afetados se houver mudança de solver/escala.
2. Executar os ensaios físicos da DE2-115 com a referência reduzida prevista, preservando logs, versões, tempos e evidências de execução.
3. Confrontar individualmente os comentários dos cinco revisores; a existência deste pacote não equivale a comentários atendidos.
4. Integrar equações, tabelas, limitações e evidências de hardware ao manuscrito e revisar a diagramação em etapa própria.

Leitura inicial: `README.md`. Parecer científico e interpretação dos ganhos, perdas e limites: `RESULTADOS_E_ARGUMENTOS.md`.
