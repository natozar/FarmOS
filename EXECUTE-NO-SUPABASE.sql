-- ================================================================
-- EXECUTAR NO SQL EDITOR DO SUPABASE
-- https://supabase.com/dashboard/project/kyvbnntoxslrtrsiejzc/sql/new
-- ================================================================

-- 1. Adicionar colunas faltantes em satellite_readings
ALTER TABLE satellite_readings
  ADD COLUMN IF NOT EXISTS evi NUMERIC,
  ADD COLUMN IF NOT EXISTS ndwi NUMERIC,
  ADD COLUMN IF NOT EXISTS classification VARCHAR(20),
  ADD COLUMN IF NOT EXISTS raw_data JSONB;

-- 2. Adicionar colunas faltantes em alerts
ALTER TABLE alerts
  ADD COLUMN IF NOT EXISTS type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS severity VARCHAR(20) DEFAULT 'warning',
  ADD COLUMN IF NOT EXISTS message TEXT,
  ADD COLUMN IF NOT EXISTS data JSONB,
  ADD COLUMN IF NOT EXISTS resolved BOOLEAN DEFAULT false;

-- 3. RPC para Edge Function buscar propriedades
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

-- 4. RPC para dashboard do painel
CREATE OR REPLACE FUNCTION get_dashboard_overview(p_user_id UUID)
RETURNS TABLE (
  property_id UUID, nome VARCHAR, municipio VARCHAR, estado VARCHAR,
  car_code VARCHAR, area_ha NUMERIC, geojson JSONB,
  last_ndvi NUMERIC, last_evi NUMERIC, last_ndwi NUMERIC,
  last_reading_date DATE, last_classification VARCHAR, last_cloud_coverage NUMERIC,
  prev_ndvi NUMERIC, prev_reading_date DATE, pending_alerts BIGINT
) AS $$
  SELECT
    p.id, p.nome, p.municipio, p.estado, p.car_code, p.area_ha,
    ST_AsGeoJSON(p.geometry)::jsonb,
    sr_last.ndvi, sr_last.evi, sr_last.ndwi,
    sr_last.reading_date, sr_last.classification, sr_last.cloud_coverage,
    sr_prev.ndvi, sr_prev.reading_date,
    (SELECT COUNT(*) FROM alerts a WHERE a.property_id = p.id AND a.resolved = false)
  FROM properties p
  LEFT JOIN LATERAL (
    SELECT ndvi, evi, ndwi, reading_date, classification, cloud_coverage
    FROM satellite_readings WHERE property_id = p.id
    ORDER BY reading_date DESC LIMIT 1
  ) sr_last ON true
  LEFT JOIN LATERAL (
    SELECT ndvi, reading_date
    FROM satellite_readings WHERE property_id = p.id
    ORDER BY reading_date DESC OFFSET 1 LIMIT 1
  ) sr_prev ON true
  WHERE p.owner_id = p_user_id AND p.active = true
  ORDER BY p.nome;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 5. RPC para histórico de leituras (gráfico)
CREATE OR REPLACE FUNCTION get_satellite_history(p_property_id UUID, p_limit INT DEFAULT 20)
RETURNS TABLE (
  reading_date DATE, ndvi NUMERIC, evi NUMERIC, ndwi NUMERIC,
  classification VARCHAR, cloud_coverage NUMERIC
) AS $$
  SELECT reading_date, ndvi, evi, ndwi, classification, cloud_coverage
  FROM satellite_readings WHERE property_id = p_property_id
  ORDER BY reading_date DESC LIMIT p_limit;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 6. RPC para alertas
CREATE OR REPLACE FUNCTION get_property_alerts(p_property_id UUID)
RETURNS TABLE (
  id UUID, type VARCHAR, severity VARCHAR, message TEXT,
  data JSONB, created_at TIMESTAMPTZ, resolved BOOLEAN
) AS $$
  SELECT id, type, severity, message, data, created_at, resolved
  FROM alerts WHERE property_id = p_property_id
  ORDER BY created_at DESC LIMIT 20;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 7. pg_cron: execução diária às 10:00 UTC (07:00 BRT)
-- NOTA: requer pg_cron habilitado (Supabase Pro)
-- Se pg_cron não estiver disponível, executar manualmente ou via cron externo
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