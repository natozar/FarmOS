# Migrations — Histórico

Estas migrations refletem os SQLs que já foram executados manualmente no
Supabase SQL Editor ao longo dos 15 épicos do AgrUAI. A numeração segue a
ordem cronológica aproximada de execução.

**NÃO re-execute estes arquivos contra o banco de produção** — eles existem
apenas para rastreabilidade histórica. Qualquer SQL novo deve ser adicionado
como uma nova migration numerada e aplicado manualmente no SQL Editor (ou
via Claude Navegador).

## Verificação pendente

Os arquivos abaixo estavam marcados como "verificar execução" no snapshot
`000-ESTADO-ATUAL.md` de 13/04/2026:

- `0017_epic12_telemetry.sql`
- `0018_epic13_kanban.sql`

Confirmar no Supabase SQL Editor que as tabelas/RPCs correspondentes existem
antes de considerar o banco totalmente sincronizado com este histórico.

## Convenções

- Numeração: `NNNN_descricao_curta.sql` (4 dígitos, snake_case)
- Ordem = ordem de execução. Pares drop→create ficam em migrations adjacentes.
- Seeds e dados de demo ficam em `supabase/seeds/`, não aqui.
