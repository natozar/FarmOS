# ESTADO ATUAL — AgrUAI (FarmOS)

**Snapshot:** 13 de Abril de 2026 — ÉPICO 15 Concluído
**Status:** Produção ativa, 15 épicos implementados, GTM em execução
**URL:** https://agruai.com (Vercel) | Supabase: kyvbnntoxslrtrsiejzc

---

## Stack

- **Frontend:** HTML/CSS/JS vanilla PWA (painel.html, godmode.html, report.html)
- **Landing:** 3 idiomas (PT/EN/ES) com SEO, hreflang, JSON-LD
- **Backend:** Supabase Pro (PostgreSQL + PostGIS + pg_cron + Edge Functions)
- **Hosting:** Vercel (auto-deploy via GitHub push)
- **Mapas:** Mapbox GL JS v3.4 + 3D Terrain DEM (exaggeration 1.6) + sky atmosphere
- **Satélite:** Sentinel-2 L2A (Copernicus/ESA) via Edge Function diária
- **SW:** v7 — cache-first CDN, network-first HTML, push listener

## Banco (10 tabelas, todas RLS FORCE)

`properties` (PostGIS + crop_type) | `satellite_readings` (NDVI/EVI/NDWI) | `alerts` (+ estimated_risk) | `field_logs` (+ sector + kanban_status + inventory FK) | `property_managers` (+ sector) | `inventory_items` | `admin_alerts` | `weekly_reports` | `behavioral_telemetry` | `profiles` (+ farm_profile JSONB)

**18 RPCs** | **5 Triggers** | **2 Cron Jobs** (satélite diário + relatório semanal)

## 15 Épicos

| # | Nome | Core |
|---|---|---|
| 1 | Offline-First | IndexedDB + auto-sync + offline bar |
| 2 | Inventário | CRUD estoque + QR scanner + abatimento |
| 3 | Risco Financeiro | Ranking R$ decrescente + calcFinancialRisk |
| 4 | Laudo ESG | jsPDF A4 com gráfico NDVI + atestado |
| 5 | Setores | 6 áreas profissionais + badges coloridos |
| 6 | Pseudo-IA | 6 regras NLP keywords + 3 ações prescritivas |
| 7 | Bloomberg/Carbono/Camera | Ticker USD, CO2 card, foto GPS comprimida |
| 8 | Scanner/WarRoom/Heatmap | QR, TV 4K fullscreen, tracking 10min |
| 9 | Auto-Report | report.html A4 print + pg_cron sexta 18h |
| 10 | Push/Timelapse/Dossiê | Notificações, slider NDVI 12m, bank report |
| 11 | Guided Tour | 4-step onboarding CSS puro, localStorage guard |
| 12 | Telemetria | behavioral_telemetry anônima + profile meter |
| 13 | Holding/CFO/Kanban | Portfolio ranking, margem bruta, 3 colunas |
| 14 | Lotação Satélite | NDVI → biomassa → UA/ha → arroba × preço |
| 15 | 3D/Meteo/Diesel | Terrain DEM, Open-Meteo 7d, EMA diesel alert |

## Segurança

- RLS FORCE em 10 tabelas
- God Mode: email lock (chatsagrado@gmail.com) + storageKey isolado
- EULA checkbox GPS trabalhista
- 5 disclaimers (CREA, CVM, LGPD, CRBio, ANPD)
- Vercel: X-Frame-Options DENY, nosniff, hreflang

## Credenciais

- CEO: `chatsagrado@gmail.com` / `Agr2026ceo`
- Teste: `fazendeiro.teste@agruai.com` / `AgrUAI2026!`

## Testes

- Playwright 265 testes × 5 browsers
- Stress audit: 0 crashes, 0 CORS, 0 RLS 403, 0 unhandled promises

## Migrations

Histórico completo em `supabase/migrations/` (21 migrations numeradas).
Seed de demo em `supabase/seeds/demo_fazenda.sql`.

Pendente de verificação no Supabase SQL Editor:
- `0017_epic12_telemetry.sql`
- `0018_epic13_kanban.sql`

## Custo: R$ 175/mês (Supabase Pro). Todo o resto: R$ 0.
