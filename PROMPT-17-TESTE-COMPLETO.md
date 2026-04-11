# PROMPT-17 — Teste Completo de Produção

## Instrução

Após o PROMPT-16 ter executado os SQLs, rodar uma bateria completa de testes em produção.

## Etapa 1 — Testar Edge Function

```bash
npx supabase functions invoke fetch-satellite-data
```

Verificar se retorna JSON com `processed`, `alerts_created`, `total_properties`.
Se retornar `No properties to process`, é porque não há propriedades cadastradas com geometria — ok.
Se retornar erro de auth Copernicus, verificar secrets.

## Etapa 2 — Testar RPCs

Via curl ou Supabase client, chamar cada RPC e confirmar que não dá erro:

```bash
# Testar get_all_active_properties_for_satellite
npx supabase db execute --project-ref kyvbnntoxslrtrsiejzc <<< "SELECT * FROM get_all_active_properties_for_satellite() LIMIT 3;"

# Testar get_dashboard_overview (substituir UUID por um user real do auth.users)
npx supabase db execute --project-ref kyvbnntoxslrtrsiejzc <<< "SELECT * FROM get_dashboard_overview('00000000-0000-0000-0000-000000000000') LIMIT 3;"
```

## Etapa 3 — Lighthouse nas 3 páginas

Rodar Lighthouse em mobile e desktop para:
- https://agruai.com/landing.html
- https://agruai.com/app.html
- https://agruai.com/painel.html

Targets: Performance > 80, Accessibility > 90, Best Practices > 90, SEO > 90.

## Etapa 4 — Playwright no painel

1. Navegar para https://agruai.com/painel.html
2. Verificar que login carrega centralizado
3. Verificar que todos os botões (Entrar, Criar conta, Google) existem
4. Verificar que não há erros no console
5. Screenshot mobile (375x812) e desktop (1440x900)

## Etapa 5 — Playwright na landing

1. Navegar para https://agruai.com/landing.html
2. Verificar todas as seções: Hero, Problema, O que é, Como funciona, Para quem é, Preview, Prova social, Formulário, FAQ, Footer
3. Verificar que FAQ accordion funciona (details/summary)
4. Verificar que formulário tem todos os campos
5. Verificar OG image carrega: curl -sI https://agruai.com/og-image.png
6. Screenshot full page

## Etapa 6 — Verificar integridade do repositório

```bash
# Nenhum arquivo sensível exposto
grep -rn "hwGCScqqneqmBF7" --include="*.html" --include="*.js" --include="*.ts" . | grep -v node_modules
grep -rn "COPERNICUS_CLIENT_SECRET" --include="*.html" --include="*.js" . | grep -v node_modules

# Nenhum link para painel.html em páginas públicas
grep -rn "painel.html" landing.html app.html index.html

# Service Worker atualizado
head -1 sw.js
```

## Etapa 7 — Relatório final

Gerar tabela com status de cada check:

| Check | Status |
|-------|--------|
| Edge Function deploy | ? |
| Copernicus auth | ? |
| RPCs criadas | ? |
| Landing Lighthouse | ? |
| App Lighthouse | ? |
| Painel login | ? |
| OG image | ? |
| FAQ funciona | ? |
| Sem secrets expostos | ? |
| Sem link para painel | ? |
| SW versão | ? |

Corrigir qualquer falha encontrada. Commit e push se houve correção.
