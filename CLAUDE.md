# AgrUAI — Inteligência Rural por Satélite

## O que é

PWA de monitoramento rural via satélite para multi-proprietários de fazendas no Brasil. Produto B2B SaaS focado em NDVI, alertas e gestão de propriedades com geolocalização.

## Stack

- **Frontend:** HTML/CSS/JS puro, arquivos únicos (SPA), mobile-first
- **Backend:** Supabase Pro (PostgreSQL + PostGIS + Auth + RLS)
- **Mapas:** Mapbox GL JS + GL Draw (desenho de polígonos)
- **Geoespacial:** PostGIS (geometrias MultiPolygon SRID 4326), Turf.js (cálculos client-side)
- **Deploy:** Vercel (auto-deploy via GitHub push)
- **Domínio:** agruai.com

## Supabase (projeto: agruai-prod)

- **URL:** https://kyvbnntoxslrtrsiejzc.supabase.co
- **Região:** sa-east-1 (São Paulo)
- **Organização:** humanai
- **Plano:** Pro ($25/mês + $10 compute)
- **Anon key:** presente nos arquivos HTML — NÃO hardcodar em outros lugares

### Schema principal

- `participantes` — leads da landing page (nome, email, telefone, desafio, origem)
- `profiles` — extensão de auth.users (trigger auto-cria no signup)
- `properties` — propriedades rurais com geometria PostGIS (MultiPolygon), CAR code, centroide, área, crop_type (ADR-004)
- `satellite_readings` — leituras de satélite (NDVI, EVI, NDWI) por propriedade
- `alerts` — alertas automáticos baseados em leituras
- `field_logs` — diário de campo (ADR-002): registros textuais por propriedade com author_id, photo_url, sector (ADR-005)
- `property_managers` — relação proprietário→profissional (ADR-003/005): manager_email, manager_user_id, role, sector (agronomia/zootecnia/veterinaria/mecanica/operacional/financeiro)

### Colunas adicionadas (PROMPT-16)

- `satellite_readings`: +`evi` (numeric), +`ndwi` (numeric), +`classification` (varchar), +`raw_data` (jsonb)
- `alerts`: +`type` (varchar), +`severity` (varchar, default 'warning'), +`message` (text), +`data` (jsonb), +`resolved` (boolean, default false)

### RPCs

- `insert_property(p_owner_id, p_nome, p_car_code, p_geojson, p_municipio, p_estado, p_source)` — converte GeoJSON para PostGIS
- `get_properties_geojson(p_user_id)` — retorna propriedades com geometria como GeoJSON
- `count_leads_agruai()` — conta participantes (badge da landing)
- `get_dashboard_data(p_user_id)` — dados do dashboard
- `get_all_active_properties_for_satellite()` — retorna propriedades ativas com geometria GeoJSON (SECURITY DEFINER, usada pela Edge Function)
- `get_dashboard_overview(p_user_id)` — overview com último NDVI/EVI/NDWI, leitura anterior, alertas pendentes (SECURITY DEFINER)
- `get_satellite_history(p_property_id, p_limit)` — histórico de leituras para gráficos (SECURITY DEFINER)
- `get_property_alerts(p_property_id)` — alertas da propriedade (SECURITY DEFINER)
- `handle_new_user()` — trigger que cria profile no signup (SECURITY DEFINER, SET search_path = public)
- `calculate_centroid()` — trigger que calcula centroide e área da geometria
- `get_field_logs(p_property_id, p_limit)` — logs do diário de campo com nome do autor (SECURITY DEFINER)
- `get_property_timeline(p_property_id, p_limit)` — timeline mista: logs + alertas ordenados por data (SECURITY DEFINER)
- `get_property_managers(p_property_id)` — lista gestores convidados de uma propriedade (SECURITY DEFINER)
- `get_managed_properties(p_user_email)` — propriedades onde o email é gestor (SECURITY DEFINER)
- `link_manager_on_login()` — trigger: vincula manager_user_id quando gestor cria conta (SECURITY DEFINER)

### Extensões PostgreSQL

- `postgis` — geometrias e funções geoespaciais
- `pg_cron` — agendamento de jobs (habilitado em 2025-04-11)
- `pg_net` — chamadas HTTP assíncronas de dentro do PostgreSQL (habilitado em 2025-04-11)

### Edge Functions

- `fetch-satellite-data` — busca dados Copernicus para propriedades ativas, grava em satellite_readings, gera alertas. Agendada via pg_cron diariamente às 10:00 UTC (07:00 BRT).

### RLS

Todas as tabelas têm Row Level Security. Propriedades e leituras filtradas por `auth.uid() = owner_id`.

## Arquivos do projeto

| Arquivo | Função | Status |
|---------|--------|--------|
| `landing.html` | Landing page com captura de leads | Produção |
| `painel.html` | App com auth, dashboard, cadastro de propriedades, mapa | Produção (URL secreta) |
| `app.html` | Protótipo visual (103KB) com dados mockados | Referência de design apenas |
| `index.html` | Redirect para landing | Produção |
| `manifest.json` | PWA manifest | Produção |
| `preview-obrigado.html` | Preview da tela de confirmação pós-lead | Referência |
| `landing-en.html` | Landing page em inglês (US) | Produção |
| `landing-es.html` | Landing page em espanhol (LATAM) | Produção |
| `godmode.html` | Painel admin CEO (chatsagrado@gmail.com only) | Produção |
| `vercel.json` | Config de deploy Vercel (rewrites, headers, security) | Produção |

## SQL

- `supabase/migrations/` — histórico de SQLs já executados no banco (21 migrations numeradas, NÃO re-executar). Ver README da pasta.
- `supabase/seeds/demo_fazenda.sql` — seed de dados de demonstração.
- Novos SQLs devem entrar como próxima migration numerada e ser aplicados manualmente no SQL Editor.

## Design tokens

```css
--dark: #0F1F0F;
--surface: #1A2E1A;
--border: #2E4A2E;
--green: #4A8C5C;
--amber: #D4A040;
--red: #C45A4A;
--gold: #C5A572;
--text: #F5F0E8;
--muted: #A89E90;
--white: #FAFAF7;
```
Fontes: Space Grotesk (headings), Inter (body). Tema escuro.

## Convenções

- Arquivos HTML são SPAs com CSS e JS inline
- Variáveis Supabase: `SUPA_URL` e `SUPA_KEY` no topo do script
- Commits seguem conventional commits (feat, fix, chore)
- `painel.html` é secreto: sem links de nenhuma página, com `noindex, nofollow`
- PROMPTs são instruções para Claude Code executar (não são código ativo)
- Landing page NÃO deve conter screenshots do produto real — apenas ilustrações conceituais (SVG/CSS)

## Mapbox

- Conta: natozar
- Token público: começa com `pk.eyJ1Ijoib...` (presente no painel.html)
- Free tier: 50k carregamentos/mês

## Projeto antigo (desativado)

- `clube-prime` (ref: mrourzdxrahpysscckxm) — Supabase free tier esgotado, sem dados. Pendente: pausar no dashboard.

## PROMPTs históricos

Os arquivos de prompts que sobreviveram estão arquivados em
`docs/prompts-history/` (14, 15, 16, 17). São registro de intenção, não
código ativo — o trabalho deles está refletido nos 15 épicos entregues.

## Histórico de incidentes

- **API key com typo:** A anon key do Supabase tinha 1 caractere errado (posição 80 do JWT: `2` em vez de `v`), herdado de extração via Chrome que bloqueava JWTs. Corrigido no PROMPT-11. A versão deployada do painel.html nunca teve o erro — o Code gerou a key correta independentemente.
- **Signup 500 (trigger sem SECURITY DEFINER):** O trigger `handle_new_user` falhava ao inserir em `profiles` porque o RLS bloqueava o INSERT feito pelo contexto de auth. Corrigido no PROMPT-18 adicionando `SECURITY DEFINER` e `SET search_path = public`. Policies de profiles: `users_own_profile` (ALL) + `allow_trigger_insert` (INSERT).

## Estado atual

Ver `000-ESTADO-ATUAL.md` para o snapshot vivo — stack, 15 épicos concluídos,
tabelas, RPCs, custo e pontos de atenção. Esse arquivo é atualizado a cada
entrega significativa e deve ser consultado antes de começar trabalho novo.
