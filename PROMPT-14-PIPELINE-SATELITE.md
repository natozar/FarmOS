# PROMPT-14 — Pipeline de Satélite: NDVI Real via Sentinel-2

## Contexto

As propriedades já estão sendo cadastradas no `painel.html` com geometria PostGIS. A tabela `satellite_readings` já existe no Supabase. O que falta é o coração do produto: **buscar dados de satélite reais e salvar no banco.**

## Arquitetura da pipeline

```
Supabase (properties)
       │
       ▼ [Cron: 1x por dia]
  Edge Function
       │
       ▼ Para cada propriedade ativa:
  Copernicus Statistical API
  (Sentinel-2 L2A, NDVI/EVI/NDWI)
       │
       ▼ Resposta JSON com estatísticas
  Salvar em satellite_readings
       │
       ▼ Se NDVI < threshold:
  Criar registro em alerts
```

## API: Copernicus Data Space Ecosystem

**Gratuito.** A Statistical API do Sentinel Hub (via Copernicus) calcula índices espectrais server-side e retorna JSON. Não precisa baixar imagens.

- **Endpoint:** `https://sh.dataspace.copernicus.eu/api/v1/statistics`
- **Auth:** OAuth2 (client_id + client_secret)
- **Free tier:** suficiente para ~10 propriedades com leituras semanais
- **Documentação:** https://documentation.dataspace.copernicus.eu/APIs/SentinelHub/Statistical.html

### Passo 0 — Criar conta no Copernicus (MANUAL)

Renato precisa criar conta em https://dataspace.copernicus.eu e depois gerar credenciais OAuth:
1. Logar em https://shapps.dataspace.copernicus.eu/dashboard
2. Ir em "User settings" → "OAuth clients"
3. Criar um novo client (tipo "Confidential")
4. Salvar `client_id` e `client_secret`

> ⚠️ Essas credenciais são SECRETAS — salvar como secrets no Supabase (Vault ou env vars da Edge Function).

### Passo 1 — Supabase Edge Function: `fetch-satellite-data`

Criar em `supabase/functions/fetch-satellite-data/index.ts`:

```typescript
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const COPERNICUS_CLIENT_ID = Deno.env.get('COPERNICUS_CLIENT_ID')!
const COPERNICUS_CLIENT_SECRET = Deno.env.get('COPERNICUS_CLIENT_SECRET')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

// 1. Obter token OAuth do Copernicus
async function getToken(): Promise<string> {
  const res = await fetch('https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: COPERNICUS_CLIENT_ID,
      client_secret: COPERNICUS_CLIENT_SECRET
    })
  })
  const data = await res.json()
  return data.access_token
}

// 2. Buscar NDVI/EVI/NDWI para um polígono
async function fetchNDVI(token: string, geojson: any, dateFrom: string, dateTo: string) {
  const evalscript = `
    //VERSION=3
    function setup() {
      return {
        input: [{ bands: ["B04", "B08", "B03", "B11", "SCL"], units: "DN" }],
        output: [
          { id: "ndvi", bands: 1 },
          { id: "evi", bands: 1 },
          { id: "ndwi", bands: 1 }
        ],
        mosaicking: "ORBIT"
      }
    }
    function evaluatePixel(samples) {
      // Filtrar nuvens (SCL: 3=sombra, 8=med cloud, 9=high cloud, 10=cirrus)
      let dominated_by_clouds = [3, 8, 9, 10]
      let dominated = dominated_by_clouds.includes(samples[0].SCL)
      if (dominated) return { ndvi: [-9999], evi: [-9999], ndwi: [-9999] }

      let nir = samples[0].B08
      let red = samples[0].B04
      let green = samples[0].B03
      let swir = samples[0].B11

      let ndvi = (nir - red) / (nir + red + 0.0001)
      let evi = 2.5 * (nir - red) / (nir + 6 * red - 7.5 * 0.5 * green + 1)
      let ndwi = (green - nir) / (green + nir + 0.0001)

      return { ndvi: [ndvi], evi: [evi], ndwi: [ndwi] }
    }
  `

  const body = {
    input: {
      bounds: { geometry: geojson, properties: { crs: "http://www.opengis.net/def/crs/EPSG/0/4326" } },
      data: [{
        type: "sentinel-2-l2a",
        dataFilter: { timeRange: { from: dateFrom, to: dateTo }, maxCloudCoverage: 30 }
      }]
    },
    aggregation: {
      timeRange: { from: dateFrom, to: dateTo },
      aggregationInterval: { of: "P5D" },
      evalscript,
      resx: 20,
      resy: 20
    },
    calculations: { default: { statistics: { default: { percentiles: { k: [25, 50, 75] } } } } }
  }

  const res = await fetch('https://sh.dataspace.copernicus.eu/api/v1/statistics', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  })

  if (!res.ok) {
    console.error('Sentinel API error:', res.status, await res.text())
    return null
  }

  return await res.json()
}

// 3. Handler principal
Deno.serve(async (req) => {
  try {
    // Buscar propriedades ativas com geometria
    const { data: properties, error } = await supabase
      .rpc('get_all_active_properties_for_satellite')

    if (error) throw error
    if (!properties || properties.length === 0) {
      return new Response(JSON.stringify({ message: 'No properties to process' }), { status: 200 })
    }

    const token = await getToken()
    const now = new Date()
    const dateTo = now.toISOString().split('T')[0] + 'T23:59:59Z'
    const from = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000) // últimos 10 dias
    const dateFrom = from.toISOString().split('T')[0] + 'T00:00:00Z'

    let processed = 0
    let alerts_created = 0

    for (const prop of properties) {
      const geojson = prop.geojson
      if (!geojson) continue

      const stats = await fetchNDVI(token, geojson, dateFrom, dateTo)
      if (!stats || !stats.data || stats.data.length === 0) continue

      // Pegar a leitura mais recente
      const latest = stats.data[stats.data.length - 1]
      const ndviStats = latest.outputs?.ndvi?.bands?.B0?.stats
      const eviStats = latest.outputs?.evi?.bands?.B0?.stats
      const ndwiStats = latest.outputs?.ndwi?.bands?.B0?.stats

      if (!ndviStats) continue

      const ndvi_mean = ndviStats.mean
      const evi_mean = eviStats?.mean || null
      const ndwi_mean = ndwiStats?.mean || null

      // Classificar
      let classification = 'healthy'
      if (ndvi_mean < 0.2) classification = 'critical'
      else if (ndvi_mean < 0.4) classification = 'stressed'
      else if (ndvi_mean < 0.6) classification = 'moderate'

      // Salvar leitura
      const { error: insertError } = await supabase
        .from('satellite_readings')
        .insert({
          property_id: prop.id,
          reading_date: latest.interval.from.split('T')[0],
          ndvi: ndvi_mean,
          evi: evi_mean,
          ndwi: ndwi_mean,
          cloud_coverage: ndviStats.sampleCount > 0
            ? (1 - ndviStats.sampleCount / (ndviStats.sampleCount + ndviStats.noDataCount || 1)) * 100
            : null,
          source: 'sentinel-2-l2a',
          classification,
          raw_data: latest
        })

      if (!insertError) processed++

      // Gerar alerta se NDVI caiu muito
      if (ndvi_mean < 0.3) {
        await supabase.from('alerts').insert({
          property_id: prop.id,
          type: 'ndvi_low',
          severity: ndvi_mean < 0.2 ? 'critical' : 'warning',
          message: `NDVI baixo (${ndvi_mean.toFixed(2)}) detectado em ${prop.nome}. Possível estresse na vegetação.`,
          data: { ndvi: ndvi_mean, evi: evi_mean, date: latest.interval.from }
        })
        alerts_created++
      }
    }

    return new Response(JSON.stringify({
      processed,
      alerts_created,
      total_properties: properties.length
    }), { status: 200 })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
```

### Passo 2 — RPC auxiliar no Supabase

Criar no SQL Editor:

```sql
-- Retorna todas as propriedades ativas com geometria como GeoJSON
-- Usada pela Edge Function (SECURITY DEFINER para bypassar RLS)
CREATE OR REPLACE FUNCTION get_all_active_properties_for_satellite()
RETURNS TABLE (
  id UUID,
  owner_id UUID,
  nome VARCHAR,
  geojson JSONB
) AS $$
  SELECT
    p.id,
    p.owner_id,
    p.nome,
    ST_AsGeoJSON(p.geometry)::jsonb as geojson
  FROM properties p
  WHERE p.active = true
    AND p.geometry IS NOT NULL
  ORDER BY p.created_at;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

### Passo 3 — Verificar/ajustar tabela satellite_readings

A tabela já existe pelo schema original, mas confirmar que tem estas colunas:

```sql
-- Adicionar colunas que podem faltar
ALTER TABLE satellite_readings
  ADD COLUMN IF NOT EXISTS evi NUMERIC,
  ADD COLUMN IF NOT EXISTS ndwi NUMERIC,
  ADD COLUMN IF NOT EXISTS classification VARCHAR(20),
  ADD COLUMN IF NOT EXISTS raw_data JSONB;
```

### Passo 4 — Verificar/ajustar tabela alerts

```sql
ALTER TABLE alerts
  ADD COLUMN IF NOT EXISTS type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS severity VARCHAR(20) DEFAULT 'warning',
  ADD COLUMN IF NOT EXISTS message TEXT,
  ADD COLUMN IF NOT EXISTS data JSONB;
```

### Passo 5 — Deploy da Edge Function

```bash
# Instalar Supabase CLI (se não tiver)
npm install -g supabase

# Login
supabase login

# Linkar ao projeto
supabase link --project-ref kyvbnntoxslrtrsiejzc

# Setar secrets
supabase secrets set COPERNICUS_CLIENT_ID=<valor>
supabase secrets set COPERNICUS_CLIENT_SECRET=<valor>

# Deploy
supabase functions deploy fetch-satellite-data --no-verify-jwt
```

### Passo 6 — Cron (executar diariamente)

Usar o pg_cron do Supabase (disponível no plano Pro):

```sql
-- Executar todos os dias às 10:00 UTC (07:00 BRT)
SELECT cron.schedule(
  'fetch-satellite-data',
  '0 10 * * *',
  $$
  SELECT net.http_post(
    url := 'https://kyvbnntoxslrtrsiejzc.supabase.co/functions/v1/fetch-satellite-data',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
```

### Passo 7 — Mostrar no painel.html

Após a pipeline rodar, o `painel.html` precisa mostrar os dados:
- No card de cada propriedade: NDVI, classificação (badge colorido), data da última leitura
- No mapa: colorir os polígonos por NDVI (verde = saudável, amarelo = moderado, vermelho = crítico)
- Na tela de propriedade: gráfico de evolução temporal do NDVI (últimas 10 leituras)

> Isso pode ser um PROMPT separado (PROMPT-15) para não sobrecarregar este.

## O que NÃO fazer neste prompt

- NÃO criar conta no Copernicus (manual — Renato faz)
- NÃO hardcodar client_id/secret no código
- NÃO processar mais de 10 propriedades por execução (rate limit)
- NÃO baixar imagens — usar apenas a Statistical API

## Dependências

1. **Renato cria conta** em https://dataspace.copernicus.eu
2. **Renato gera OAuth credentials** no dashboard do Copernicus
3. **Supabase CLI** instalado na máquina do Renato
4. **Edge Functions** habilitadas no plano Pro (já está)

## Validação

- [ ] Edge Function deploya sem erro
- [ ] Chamada manual (`curl`) retorna dados de NDVI
- [ ] Leituras aparecem na tabela `satellite_readings`
- [ ] Alertas são criados quando NDVI < 0.3
- [ ] Cron está agendado e executa diariamente
- [ ] Não há credenciais hardcodadas no código
