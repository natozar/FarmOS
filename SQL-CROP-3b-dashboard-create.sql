-- RODAR QUINTO (ultimo)
CREATE FUNCTION get_dashboard_overview(p_user_id UUID)
RETURNS TABLE (
  property_id        UUID,
  nome               VARCHAR,
  municipio          VARCHAR,
  estado             VARCHAR,
  car_code           VARCHAR,
  area_ha            NUMERIC,
  crop_type          VARCHAR,
  geojson            JSONB,
  last_ndvi          NUMERIC,
  last_evi           NUMERIC,
  last_ndwi          NUMERIC,
  last_reading_date  DATE,
  last_classification VARCHAR,
  last_cloud_coverage NUMERIC,
  prev_ndvi          NUMERIC,
  prev_reading_date  DATE,
  pending_alerts     BIGINT
) AS $$
  SELECT
    p.id,
    p.nome,
    p.municipio,
    p.estado,
    p.car_code,
    p.area_ha,
    p.crop_type,
    ST_AsGeoJSON(p.geometry)::jsonb,
    COALESCE(sr_last.ndvi, sr_last.ndvi_mean),
    sr_last.evi,
    sr_last.ndwi,
    COALESCE(sr_last.reading_date, sr_last.captured_at),
    sr_last.classification,
    COALESCE(sr_last.cloud_coverage, sr_last.cloud_pct),
    COALESCE(sr_prev.ndvi, sr_prev.ndvi_mean),
    COALESCE(sr_prev.reading_date, sr_prev.captured_at),
    (SELECT COUNT(*) FROM alerts a WHERE a.property_id = p.id AND a.resolved = false)
  FROM properties p
  LEFT JOIN LATERAL (
    SELECT ndvi, ndvi_mean, evi, ndwi, reading_date, captured_at, classification, cloud_coverage, cloud_pct
    FROM satellite_readings
    WHERE property_id = p.id
    ORDER BY COALESCE(reading_date, captured_at) DESC
    LIMIT 1
  ) sr_last ON true
  LEFT JOIN LATERAL (
    SELECT ndvi, ndvi_mean, reading_date, captured_at
    FROM satellite_readings
    WHERE property_id = p.id
    ORDER BY COALESCE(reading_date, captured_at) DESC
    OFFSET 1 LIMIT 1
  ) sr_prev ON true
  WHERE p.owner_id = p_user_id
    AND p.active = true
  ORDER BY p.nome;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
