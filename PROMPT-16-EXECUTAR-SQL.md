# PROMPT-16 — Executar SQLs no Supabase

## Instrução

Leia o arquivo `EXECUTE-NO-SUPABASE.sql` e execute cada bloco SQL separadamente no Supabase via REST API.

**Supabase project:** kyvbnntoxslrtrsiejzc
**Service Role Key:** (pegar de `supabase secrets list` ou do dashboard)

## Método

Usar `supabase db execute` ou `supabase sql` para cada bloco:

```bash
npx supabase db execute --project-ref kyvbnntoxslrtrsiejzc <<< "SQL AQUI"
```

## Ordem de execução

1. ALTER TABLE satellite_readings
2. ALTER TABLE alerts
3. CREATE FUNCTION get_all_active_properties_for_satellite
4. CREATE FUNCTION get_dashboard_overview
5. CREATE FUNCTION get_satellite_history
6. CREATE FUNCTION get_property_alerts
7. pg_cron schedule (pode falhar se pg_cron não estiver habilitado — ok)

## Após executar

Testar a Edge Function:
```bash
npx supabase functions invoke fetch-satellite-data
```

## Commit
Não há commit — é apenas execução de SQL no banco.
