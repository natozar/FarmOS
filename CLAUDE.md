# AgrUAI — Inteligência Rural por Satélite

## Modo de operação (GODMODE)

- **Execute, não pergunte.** Quando o CEO pede algo, entrega — não para no meio pra confirmar default razoável, escolha de cultura piloto, modelo de cobrança, ou qualquer decisão técnica que dê pra reverter depois. Documente o default escolhido no commit/resposta final.
- **Não invente bloqueio legal/regulatório** que o cliente não pediu. Pedido "entrega dados" não vira plano de ART/laudo/SLA. Disclaimer entra no contrato, não no plano técnico.
- **Fluxo padrão de entrega:** código → migration → commit → push → instrução de aplicar SQL no editor. Sem checkpoint intermediário.
- **Só pergunta** se a decisão é irreversível (apaga dado, manda email pra usuário real, gasta crédito de API que cobra) ou se faltar informação que muda o produto inteiro (ex: a credora pediu API ou whitelabel? — quando nem o usuário sabe).
- O *único* feedback explícito que invalida esse modo é o usuário dizer "para" ou "espera".

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

- `participantes` — leads da landing page (nome, email, telefone, desafio, origem). `aprovado_at` / `aprovado_por` marcam leads já convidados via godmode (migration 0029).
- `profiles` — extensão de auth.users (trigger auto-cria no signup)
- `properties` — propriedades rurais com geometria PostGIS (MultiPolygon), CAR code, centroide, área, crop_type (ADR-004)
- `satellite_readings` — leituras de satélite (NDVI, EVI, NDWI) por propriedade
- `alerts` — alertas automáticos baseados em leituras
- `field_logs` — diário de campo (ADR-002): registros textuais por propriedade com author_id, photo_url, audio_url (migration 0025), sector (ADR-005)
- `property_managers` — relação proprietário→profissional (ADR-003/005): manager_email, manager_user_id, role, sector (agronomia/zootecnia/veterinaria/mecanica/operacional/financeiro)
- `admin_users` (migration 0030) — fonte da verdade de quem é admin/CEO. Substitui o email hard-coded nas edge functions e RLS policies. Seed inicial: chatsagrado@gmail.com.
- `ai_usage` (migration 0030) — rate-limit agregado por (user, kind, day) nas edge functions de custo (ai-suggest, transcribe-audio).
- `ai_request_log` (migration 0031) — uma linha por chamada IA aprovada. Base do burst-check (60s) e auditoria. Limpeza via `cleanup_ai_request_log()` (>7d).
- `feature_flags` (migration 0031) — kill switch admin-toggleable por feature (ai_suggest, transcribe). `enabled=false` faz bump_ai_usage retornar `feature_disabled` sem redeploy.
- `crop_yield_curves` (migration 0033) — coeficientes NDVI→sacas/ha por cultura/região. Seed: soja BR linear v1.
- `property_native_coverage` (migration 0033) — hectares de nativa, % da área, bioma, tCO₂ estocado e classes por propriedade. Preenchido por `compute_native_coverage()` (migration 0035).
- `lender_clients` (migration 0034) — credoras cadastradas. Guarda `api_key_hash` (sha256) e `api_key_prefix` (visibilidade nos logs).
- `lender_property_access` (migration 0034) — concessão dono→credora por propriedade. RLS: dono vê quem está vendo a fazenda dele.
- `lender_audit_log` (migration 0034) — toda chamada do `lender-api` (sucesso/erro), base do billing e compliance.
- `biome_by_uf` (migration 0035) — lookup UF→bioma dominante. Aproximação v1; v2 cruzará com shapefile IBGE.
- `carbon_factors` (migration 0035) — tCO₂/ha por bioma e classe (forest/shrubland/grassland), valores IPCC AR6.

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
- `is_admin()` — retorna true se auth.uid() está em admin_users (SECURITY DEFINER). Usada em RLS policies no lugar de comparar email literal.
- `bump_ai_usage(p_user_id, p_kind, p_max_per_day, p_max_global_per_day=500, p_max_per_minute=5)` — enforcement em 4 camadas em uma transação: feature_flag → burst(60s) → daily-user → daily-global. Retorna `{allowed, reason?, count_user, remaining_user, count_global, remaining_global}`. Razões: `feature_disabled | burst | daily_user | global_ceiling`. Só `service_role` executa.
- `cleanup_ai_request_log()` — remove entradas de `ai_request_log` com mais de 7 dias. Executável por admin (ou via pg_cron).
- `ai_usage_overview()` — dashboard admin (JSON com counts de hoje + top users + flags). Checa `is_admin()`.
- `get_lender_report(p_property_id)` (migration 0033) — JSON consolidado pra entrega à credora: identificação + série NDVI/EVI/NDWI 24m + produção estimada (sacas/ha via curva da cultura) + cobertura nativa + tCO₂. Owner-only / admin / service_role.
- `compute_native_coverage(p_property_id)` (migration 0035) — classifica % nativa por estabilidade temporal NDVI (amplitude 12 meses), grava em `property_native_coverage`. v1; v2 = overlay MapBiomas exato.
- `compute_native_coverage_batch()` (migration 0035) — roda para todas as propriedades ativas. Agendada em pg_cron diário 10:30 UTC (após `fetch-satellite-data` às 10:00).
- `lender_auth(p_api_key_hash)` / `lender_has_access(p_lender_id, p_property_id)` (migration 0034) — usadas pela Edge Function `lender-api`. Só `service_role`.
- `create_lender_client(p_name, p_contact_email, p_monthly_quota, p_notes)` (migration 0034) — admin-only. Retorna `api_key` em claro UMA vez (sha256 gravado, segredo não recuperável).
- `grant_lender_access(p_lender_id, p_property_id)` (migration 0034) — dono ou admin libera propriedade pra credora ler via API.

### Extensões PostgreSQL

- `postgis` — geometrias e funções geoespaciais
- `pg_cron` — agendamento de jobs (habilitado em 2025-04-11)
- `pg_net` — chamadas HTTP assíncronas de dentro do PostgreSQL (habilitado em 2025-04-11)

### Edge Functions

- `fetch-satellite-data` — busca dados Copernicus para propriedades ativas, grava em satellite_readings, gera alertas. Agendada via pg_cron diariamente às 10:00 UTC (07:00 BRT).
- `generate-daily-article` — gera artigo do blog diariamente via Gemini.
- `ai-suggest` — 3 ações práticas no diário de campo via Gemini 2.5 Flash (free tier, `thinkingBudget=0`). JWT ES256 validado manualmente (`verify_jwt: false` no deploy + `getUser()` no código). Rate-limit 30/user/dia. Owner-only na UI (stripped em views de gestor).
- `transcribe-audio` — transcreve áudio do bucket `field-media` via Groq Whisper Large v3 Turbo (free tier). Valida prefixo `{user_id}/` no storage_path. Rate-limit 30/user/dia.
- `invite-lead` — admin-only (checa `admin_users`). Chama `auth.admin.inviteUserByEmail`, redireciona pro painel, marca `aprovado_at` em participantes.
- `lender-api` (migration 0034) — endpoint público pra credoras. `GET /property/{uuid}` com header `X-Lender-Key`. Hash sha256 → `lender_auth` → `lender_has_access` → `get_lender_report`. Quota mensal opcional (200 = sucesso conta). Toda chamada audita em `lender_audit_log`. Deploy com `--no-verify-jwt`.

### Storage

- `field-media` (public) — mídia do diário de campo e sandbox de testes. Limite 10 MB, MIME whitelist (jpeg/png/webp + webm/mp4/mpeg/ogg). Policies: INSERT e DELETE só na pasta `{auth.uid()}/*`; SELECT público. Caminhos usados: `{user_id}/sandbox/...` (Área do Gestor), previsto `{user_id}/field-logs/...` quando o diário for migrado para upload real.

### RLS

Todas as tabelas têm Row Level Security. Propriedades e leituras filtradas por `auth.uid() = owner_id`.

## Arquivos do projeto

| Arquivo | Função | Status |
|---------|--------|--------|
| `landing.html` | Landing page com captura de leads | Produção |
| `painel.html` | App com auth, dashboard, cadastro de propriedades, mapa, Área do Gestor (sandbox de foto/áudio/IA) | Produção (URL secreta) |
| `app.html` | Protótipo visual (103KB) com dados mockados | Referência de design apenas |
| `manifest.json` | PWA manifest | Produção |
| `preview-obrigado.html` | Preview da tela de confirmação pós-lead | Referência |
| `landing-en.html` | Landing page em inglês (US) | Produção |
| `landing-es.html` | Landing page em espanhol (LATAM) | Produção |
| `godmode.html` | Painel admin CEO (chatsagrado@gmail.com only) | Produção |
| `vercel.json` | Config de deploy Vercel (rewrites, headers, security) | Produção |

## SQL

- `supabase/migrations/` — histórico de SQLs já executados no banco (32 migrations numeradas, NÃO re-executar). Ver README da pasta.
- `supabase/seeds/demo_fazenda.sql` — seed de dados de demonstração.
- Novos SQLs devem entrar como próxima migration numerada e ser aplicados manualmente no SQL Editor (ou via MCP `apply_migration`).

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
- **Service worker:** bumpar `CACHE_NAME` em `sw.js` sempre que `painel.html` mudar. Clientes PWA antigos caem em versões velhas se o cache não invalidar, o que já causou dois 404s em produção.
- **Autorização:** nunca hard-codar email admin em RLS/edge function. Fonte única da verdade é `admin_users` + `public.is_admin()`.

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
- **RLS 403 no SELECT de properties/field_logs:** Múltiplas policies liam `(SELECT email FROM auth.users WHERE id = auth.uid())`, mas o role `authenticated` não tem SELECT em `auth.users`. Qualquer gestor logava mas não via nada. Corrigido nas migrations 0026–0028 substituindo por `auth.jwt() ->> 'email'`.
- **Gemini 2.5 Flash truncando:** `thinkingBudget` consumia todo `maxOutputTokens` antes de gerar saída. Resolvido com `thinkingConfig: { thinkingBudget: 0 }` no generationConfig.
- **JWT ES256 rejeitado pelo verify_jwt builtin:** Nova Supabase assina com ES256; o verify automático das Edge Functions espera HS256. Solução: `verify_jwt: false` no deploy + validação manual via `authClient.auth.getUser(jwt)` no código.

## Estado atual

Ver `000-ESTADO-ATUAL.md` para o snapshot vivo — stack, 15 épicos concluídos,
tabelas, RPCs, custo e pontos de atenção. Esse arquivo é atualizado a cada
entrega significativa e deve ser consultado antes de começar trabalho novo.
