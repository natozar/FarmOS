-- RODAR TERCEIRO
CREATE FUNCTION insert_property(
  p_owner_id UUID,
  p_nome VARCHAR,
  p_car_code VARCHAR,
  p_geojson JSONB,
  p_municipio VARCHAR,
  p_estado VARCHAR,
  p_source VARCHAR,
  p_crop_type VARCHAR DEFAULT NULL
) RETURNS VOID AS $$
  INSERT INTO properties (owner_id, nome, car_code, geometry, municipio, estado, source, crop_type)
  VALUES (
    p_owner_id,
    p_nome,
    p_car_code,
    ST_SetSRID(ST_GeomFromGeoJSON(p_geojson::text), 4326),
    p_municipio,
    p_estado,
    p_source,
    p_crop_type
  );
$$ LANGUAGE sql SECURITY DEFINER;
