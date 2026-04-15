# PROMPT-15 — Exibir Dados de Satélite no Painel

## Contexto

A pipeline do PROMPT-14 salva leituras NDVI/EVI/NDWI na tabela `satellite_readings` e alertas em `alerts`. O `painel.html` ainda não mostra esses dados — os cards de propriedades são estáticos, o mapa não reflete saúde da vegetação e não há gráficos temporais.

Este prompt transforma o painel de "cadastro de propriedades" em "central de monitoramento".

## O que mudar no painel.html

### 1. RPC nova: `get_dashboard_data` (melhorada)

Criar no SQL Editor do Supabase:

```sql
-- Retorna propriedades com última leitura de satélite e alertas pendentes
CREATE OR REPLACE FUNCTION get_dashboard_overview(p_user_id UUID)
RETURNS TABLE (
  property_id UUID,
  nome VARCHAR,
  municipio VARCHAR,
  estado VARCHAR,
  car_code VARCHAR,
  area_ha NUMERIC,
  geojson JSONB,
  -- Última leitura
  last_ndvi NUMERIC,
  last_evi NUMERIC,
  last_ndwi NUMERIC,
  last_reading_date DATE,
  last_classification VARCHAR,
  last_cloud_coverage NUMERIC,
  -- Leitura anterior (para delta)
  prev_ndvi NUMERIC,
  prev_reading_date DATE,
  -- Alertas
  pending_alerts BIGINT
) AS $$
  SELECT
    p.id AS property_id,
    p.nome,
    p.municipio,
    p.estado,
    p.car_code,
    p.area_ha,
    ST_AsGeoJSON(p.geometry)::jsonb AS geojson,
    sr_last.ndvi AS last_ndvi,
    sr_last.evi AS last_evi,
    sr_last.ndwi AS last_ndwi,
    sr_last.reading_date AS last_reading_date,
    sr_last.classification AS last_classification,
    sr_last.cloud_coverage AS last_cloud_coverage,
    sr_prev.ndvi AS prev_ndvi,
    sr_prev.reading_date AS prev_reading_date,
    (SELECT COUNT(*) FROM alerts a WHERE a.property_id = p.id AND a.resolved = false) AS pending_alerts
  FROM properties p
  LEFT JOIN LATERAL (
    SELECT ndvi, evi, ndwi, reading_date, classification, cloud_coverage
    FROM satellite_readings
    WHERE property_id = p.id
    ORDER BY reading_date DESC
    LIMIT 1
  ) sr_last ON true
  LEFT JOIN LATERAL (
    SELECT ndvi, reading_date
    FROM satellite_readings
    WHERE property_id = p.id
    ORDER BY reading_date DESC
    OFFSET 1 LIMIT 1
  ) sr_prev ON true
  WHERE p.owner_id = p_user_id
    AND p.active = true
  ORDER BY p.nome;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

### 2. RPC para histórico de leituras (gráfico)

```sql
CREATE OR REPLACE FUNCTION get_satellite_history(p_property_id UUID, p_limit INT DEFAULT 20)
RETURNS TABLE (
  reading_date DATE,
  ndvi NUMERIC,
  evi NUMERIC,
  ndwi NUMERIC,
  classification VARCHAR,
  cloud_coverage NUMERIC
) AS $$
  SELECT reading_date, ndvi, evi, ndwi, classification, cloud_coverage
  FROM satellite_readings
  WHERE property_id = p_property_id
  ORDER BY reading_date DESC
  LIMIT p_limit;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

### 3. RPC para alertas da propriedade

```sql
CREATE OR REPLACE FUNCTION get_property_alerts(p_property_id UUID)
RETURNS TABLE (
  id UUID,
  type VARCHAR,
  severity VARCHAR,
  message TEXT,
  data JSONB,
  created_at TIMESTAMPTZ,
  resolved BOOLEAN
) AS $$
  SELECT id, type, severity, message, data, created_at, resolved
  FROM alerts
  WHERE property_id = p_property_id
  ORDER BY created_at DESC
  LIMIT 20;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

### 4. Garantir coluna `resolved` na tabela alerts

```sql
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS resolved BOOLEAN DEFAULT false;
```

---

## Mudanças no JavaScript do painel.html

### 4a. Atualizar `carregarPropriedades()` para usar a nova RPC

Substituir a função `carregarPropriedades` para chamar `get_dashboard_overview` em vez de `get_properties_geojson`. Isso traz junto as leituras de satélite:

```js
async function carregarPropriedades() {
  try {
    var r = await sb.rpc('get_dashboard_overview', { p_user_id: State.user.id });
    if (r.error) throw r.error;
    State.propriedades = r.data || [];
    return State.propriedades;
  } catch (err) {
    // Fallback: carregar sem dados de satélite
    try {
      var r2 = await sb.rpc('get_properties_geojson', { p_user_id: State.user.id });
      if (r2.error) throw r2.error;
      State.propriedades = r2.data || [];
      return State.propriedades;
    } catch (err2) {
      toast('Erro ao carregar propriedades', 'erro');
      return [];
    }
  }
}
```

### 4b. Atualizar `renderPropriedades()` — cards com NDVI

Cada card de propriedade agora mostra:
- **Badge NDVI colorido**: verde (healthy), amarelo (moderate), laranja (stressed), vermelho (critical), cinza (sem dados)
- **Valor NDVI**: ex: "0.72"
- **Delta vs leitura anterior**: ex: "+0.04" (verde) ou "-0.12" (vermelho)
- **Data da última leitura**: "há 3 dias"
- **Indicador de alertas pendentes**: badge vermelho se > 0

```js
function getNDVIColor(classification) {
  switch (classification) {
    case 'healthy': return 'var(--green)';
    case 'moderate': return 'var(--amber)';
    case 'stressed': return '#E07030';
    case 'critical': return 'var(--red)';
    default: return 'var(--muted)';
  }
}

function getNDVILabel(classification) {
  switch (classification) {
    case 'healthy': return 'Saudável';
    case 'moderate': return 'Moderado';
    case 'stressed': return 'Estressado';
    case 'critical': return 'Crítico';
    default: return 'Sem dados';
  }
}

function diasAtras(dateStr) {
  if (!dateStr) return '';
  var diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 86400000);
  if (diff === 0) return 'hoje';
  if (diff === 1) return 'ontem';
  return 'há ' + diff + ' dias';
}
```

**Novo HTML dos cards:**

```
┌──────────────────────────────────┐
│  Fazenda Santa Maria    1.240 ha │
│  Ribeirão Preto/SP · CAR: XX... │
│                                  │
│  ┌──────┐  NDVI 0.72  Saudável  │
│  │ ████ │  +0.04 vs anterior    │
│  │ ████ │  Atualizado há 2 dias │
│  └──────┘                       │
│                                  │
│  🛰️ Monitorando   ⚠️ 1 alerta  │
└──────────────────────────────────┘
```

O mini-bloco visual é uma barra vertical cuja cor e altura representam o NDVI (0-1 → 0-100%).

### 4c. Novo: Tela de Detalhe da Propriedade

Quando o usuário clica em um card, em vez de ir direto para o mapa geral, vai para uma tela de **detalhe** que mostra:

1. **Header** com nome, localização e botão voltar
2. **Mapa** da propriedade individual com polígono colorido pelo NDVI
3. **Cards de métricas**: NDVI, EVI, NDWI, Nuvens (4 cards em grid 2x2)
4. **Gráfico temporal**: linha do NDVI das últimas 20 leituras (Canvas API simples ou SVG)
5. **Lista de alertas** pendentes (colapsável)

**Nova tela HTML a adicionar:**

```html
<div class="screen" id="tela-detalhe">
  <div class="header"><div class="header-left" id="detalheHeader"></div></div>
  <div class="content" id="detalheContent"></div>
  <nav class="bottom-nav">...</nav>
</div>
```

**Função `renderDetalhe(propertyId)`:**
- Busca a propriedade em `State.propriedades` pelo ID
- Chama `get_satellite_history(propertyId)` para o gráfico
- Chama `get_property_alerts(propertyId)` para os alertas
- Renderiza tudo

### 4d. Gráfico NDVI temporal — SVG inline (sem dependências)

Criar com SVG puro, sem bibliotecas. Dados das últimas 20 leituras.

```
  0.8 ─┤        ●───●
       │       /     \     ●───●
  0.6 ─┤  ●──●       \   /
       │ /             ● ●
  0.4 ─┤●
       │
  0.2 ─┤                        ← threshold alerta
       └─────────────────────────
        Jan  Fev  Mar  Abr  Mai
```

Implementação:
- Container: `<svg>` com viewBox responsivo
- Eixo Y: 0 a 1 (NDVI)
- Eixo X: datas
- Linha NDVI: `<polyline>` com stroke color baseado na classificação
- Pontos: `<circle>` em cada leitura
- Linha de threshold: `<line>` tracejada em NDVI 0.3
- Cores: usar as vars do design system
- Tooltip ao hover (via JS): mostrar valor e data

### 4e. Colorir polígonos no mapa por NDVI

Na função `renderMapaGeral()`, o mapa já mostra polígonos em dourado estático. Mudar para:

- Colorir `fill-color` baseado no NDVI:
  - NDVI >= 0.6: `#4A8C5C` (verde)
  - NDVI 0.4-0.6: `#D4A040` (amarelo)
  - NDVI 0.2-0.4: `#E07030` (laranja)
  - NDVI < 0.2: `#C45A4A` (vermelho)
  - Sem dados: `#A89E90` (cinza)

- Usar data-driven styling do Mapbox:

```js
'fill-color': [
  'case',
  ['==', ['get', 'ndvi'], null], '#A89E90',
  ['>=', ['get', 'ndvi'], 0.6], '#4A8C5C',
  ['>=', ['get', 'ndvi'], 0.4], '#D4A040',
  ['>=', ['get', 'ndvi'], 0.2], '#E07030',
  '#C45A4A'
]
```

- Popup no click agora mostra NDVI, classificação e data.

### 4f. Bottom nav — novo item "Alertas"

Adicionar um 4º item na navegação inferior:

```
🏠 Propriedades  |  🗺️ Mapa  |  ⚠️ Alertas  |  + Cadastrar
```

A tela de Alertas (`tela-alertas`) lista todos os alertas do usuário, agrupados por propriedade, com opção de marcar como resolvido.

---

## CSS novo a adicionar

```css
/* NDVI Badge */
.ndvi-badge{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:12px;font-size:.72rem;font-weight:600;font-family:'Space Grotesk',sans-serif}
.ndvi-bar{width:4px;height:24px;border-radius:2px;margin-right:6px}
.ndvi-value{font-size:1rem;font-weight:700;font-family:'Space Grotesk',sans-serif}
.ndvi-delta{font-size:.72rem;font-weight:500}
.ndvi-delta.up{color:var(--green)}
.ndvi-delta.down{color:var(--red)}
.ndvi-date{font-size:.68rem;color:var(--muted)}

/* Métricas grid */
.metrics-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:16px 0}
.metric-card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:14px 12px;text-align:center}
.metric-label{font-size:.65rem;color:var(--muted);text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px}
.metric-value{font-size:1.15rem;font-weight:700;font-family:'Space Grotesk',sans-serif}

/* Gráfico NDVI */
.ndvi-chart{width:100%;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:16px 12px;margin:16px 0}
.ndvi-chart svg{width:100%;height:160px}
.ndvi-chart-title{font-size:.78rem;font-weight:600;color:var(--text);margin-bottom:12px;font-family:'Space Grotesk',sans-serif}

/* Alertas */
.alert-item{padding:14px;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);margin-bottom:8px;display:flex;gap:12px;align-items:flex-start}
.alert-icon{width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:.8rem}
.alert-icon.warning{background:rgba(212,160,64,.1);color:var(--amber)}
.alert-icon.critical{background:rgba(196,90,74,.1);color:var(--red)}
.alert-text{flex:1}
.alert-msg{font-size:.85rem;color:var(--text);line-height:1.5}
.alert-meta{font-size:.68rem;color:var(--muted);margin-top:4px}
.alert-resolve{font-size:.7rem;color:var(--gold);cursor:pointer;background:none;border:none;padding:4px 8px;border-radius:4px}
.alert-resolve:hover{background:rgba(197,165,114,.08)}
```

---

## Navegação atualizada

Adicionar ao State:
```js
State.selectedProperty = null; // UUID da propriedade selecionada
```

Atualizar `navegarPara()`:
```js
case 'detalhe': renderDetalhe(State.selectedProperty); break;
case 'alertas': renderAlertas(); break;
```

No card de propriedade, o click agora faz:
```js
onclick="State.selectedProperty='${p.property_id}';navegarPara('detalhe')"
```

---

## O que NÃO fazer

- NÃO adicionar bibliotecas de gráfico (Chart.js, D3, etc.) — usar SVG puro inline
- NÃO criar arquivos separados — tudo continua no `painel.html`
- NÃO mudar a lógica de auth ou cadastro
- NÃO hardcodar dados de satélite — se não houver leituras, mostrar "Aguardando primeira leitura do satélite"
- NÃO quebrar o fluxo existente de cadastro de propriedades

## Deploy

```bash
git add painel.html
git commit -m "feat(painel): show satellite NDVI data, charts and alerts

- Property cards now display NDVI value, classification badge, delta
- Map polygons colored by vegetation health (green→red)
- New property detail screen with metrics and temporal NDVI chart
- SVG-based NDVI chart (last 20 readings, no dependencies)
- Alerts screen with pending alerts per property
- New RPCs: get_dashboard_overview, get_satellite_history, get_property_alerts
- Graceful fallback when no satellite data exists yet

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

git push origin main
```

## Dependências

1. **PROMPT-14 executado** — Edge Function deployada e satellite_readings populada
2. **RPCs criadas** no Supabase (SQL deste prompt)
3. **Coluna `resolved`** adicionada em `alerts`

> Se a pipeline ainda não rodou, o painel funciona normalmente mostrando "Aguardando satélite" — zero breaking changes.

## Validação

- [ ] Cards de propriedades mostram NDVI quando há leituras
- [ ] Cards mostram "Aguardando satélite" quando não há leituras
- [ ] Polígonos no mapa coloridos por NDVI
- [ ] Tela de detalhe abre ao clicar em uma propriedade
- [ ] Gráfico SVG renderiza corretamente com dados históricos
- [ ] Alertas listados e agrupados por propriedade
- [ ] Bottom nav com 4 itens funciona
- [ ] Responsivo em mobile e desktop
- [ ] Sem erros no console
- [ ] Auth e cadastro continuam funcionando
