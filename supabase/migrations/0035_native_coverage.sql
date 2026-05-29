-- 0035: Sprint 2 — Calcular cobertura nativa + carbono por propriedade
-- =====================================================================
-- Estrategia v1: usa NDVI historico que ja temos (satellite_readings)
-- pra classificar cada propriedade por estabilidade temporal.
--   - Vegetacao nativa = NDVI estavel ao longo do ano (baixa amplitude)
--   - Cropland         = NDVI ciclico (alta amplitude entre safra/entressafra)
-- Roadmap v2: substituir o classificador heuristico pelo overlay exato
-- com MapBiomas Colecao 9 (GEE service account ou COG range requests).
--
-- Resultado escrito em property_native_coverage (tabela criada em 0033).
-- Estimativa de tCO2 = native_ha * fator IPCC por bioma (carbon_factors).
-- Bioma derivado do UF (biome_by_uf), aproximacao boa pra v1.

-- ============================================================
-- 1. biome_by_uf  — mapeamento simples UF -> bioma dominante
-- ============================================================
CREATE TABLE IF NOT EXISTS public.biome_by_uf (
  uf     varchar(2) PRIMARY KEY,
  biome  text NOT NULL
);

INSERT INTO public.biome_by_uf (uf, biome) VALUES
  ('AC','amazonia'),('AM','amazonia'),('AP','amazonia'),
  ('PA','amazonia'),('RO','amazonia'),('RR','amazonia'),
  ('TO','cerrado'), ('MT','cerrado'), ('MS','cerrado'),
  ('GO','cerrado'), ('DF','cerrado'),
  ('MG','cerrado'), -- 60% cerrado, simplificacao v1
  ('BA','caatinga'),('PI','caatinga'),('CE','caatinga'),
  ('RN','caatinga'),('PB','caatinga'),('PE','caatinga'),
  ('AL','caatinga'),('SE','caatinga'),('MA','caatinga'),
  ('SP','mata_atlantica'),('RJ','mata_atlantica'),
  ('ES','mata_atlantica'),('PR','mata_atlantica'),
  ('SC','mata_atlantica'),
  ('RS','pampa')
ON CONFLICT (uf) DO NOTHING;

-- ============================================================
-- 2. carbon_factors  — tCO2/ha por bioma e classe (IPCC AR6 aprox.)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.carbon_factors (
  id            serial PRIMARY KEY,
  biome         text NOT NULL,
  class_name    text NOT NULL,        -- 'forest', 'shrubland', 'grassland', 'wetland'
  tco2_per_ha   numeric NOT NULL,
  is_native     boolean NOT NULL DEFAULT true,
  source        text,
  UNIQUE (biome, class_name)
);

INSERT INTO public.carbon_factors (biome, class_name, tco2_per_ha, source) VALUES
  ('amazonia',       'forest',     130, 'IPCC AR6 ch.7 — tropical moist forest'),
  ('amazonia',       'shrubland',   45, 'IPCC AR6 — disturbed/secondary'),
  ('amazonia',       'grassland',   15, 'IPCC AR6 — herbaceous'),
  ('cerrado',        'forest',      70, 'IPCC AR6 — tropical dry forest'),
  ('cerrado',        'shrubland',   35, 'IPCC AR6 — savanna woodland'),
  ('cerrado',        'grassland',   12, 'IPCC AR6 — campo limpo'),
  ('mata_atlantica', 'forest',     110, 'IPCC AR6 — tropical moist (degraded)'),
  ('mata_atlantica', 'shrubland',   40, 'IPCC AR6 — capoeira'),
  ('mata_atlantica', 'grassland',   15, 'IPCC AR6'),
  ('caatinga',       'forest',      40, 'IPCC AR6 — semi-arid'),
  ('caatinga',       'shrubland',   25, 'IPCC AR6 — caatinga arborea'),
  ('caatinga',       'grassland',    8, 'IPCC AR6'),
  ('pampa',          'forest',      40, 'IPCC AR6 — sparse temperate'),
  ('pampa',          'shrubland',   15, 'IPCC AR6'),
  ('pampa',          'grassland',   12, 'IPCC AR6 — grassland temperate'),
  ('pantanal',       'forest',      80, 'IPCC AR6'),
  ('pantanal',       'shrubland',   30, 'IPCC AR6'),
  ('pantanal',       'grassland',   18, 'IPCC AR6'),
  ('default',        'forest',     100, 'fallback'),
  ('default',        'shrubland',   30, 'fallback'),
  ('default',        'grassland',   10, 'fallback')
ON CONFLICT (biome, class_name) DO NOTHING;

ALTER TABLE public.carbon_factors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cf_read ON public.carbon_factors;
CREATE POLICY cf_read ON public.carbon_factors FOR SELECT USING (true);

ALTER TABLE public.biome_by_uf ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bbu_read ON public.biome_by_uf;
CREATE POLICY bbu_read ON public.biome_by_uf FOR SELECT USING (true);

-- ============================================================
-- 3. compute_native_coverage(p_property_id)
--    Classifica a propriedade via assinatura NDVI temporal e
--    grava em property_native_coverage.
-- ============================================================
CREATE OR REPLACE FUNCTION public.compute_native_coverage(p_property_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property   properties%ROWTYPE;
  v_biome      text;
  v_n          int;
  v_mean       numeric;
  v_std        numeric;
  v_min        numeric;
  v_max        numeric;
  v_amplitude  numeric;
  v_native_pct numeric;
  v_native_ha  numeric;
  v_class      text;
  v_tco2_ha    numeric;
  v_carbon     numeric;
BEGIN
  SELECT * INTO v_property FROM properties WHERE id = p_property_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'property_not_found');
  END IF;

  SELECT COALESCE(biome, 'default') INTO v_biome
  FROM biome_by_uf
  WHERE uf = v_property.estado;
  v_biome := COALESCE(v_biome, 'default');

  -- Stats de NDVI nos ultimos 12 meses, ignorando nuvem alta
  SELECT COUNT(*), AVG(ndvi), COALESCE(STDDEV_POP(ndvi), 0), MIN(ndvi), MAX(ndvi)
  INTO v_n, v_mean, v_std, v_min, v_max
  FROM satellite_readings
  WHERE property_id = p_property_id
    AND reading_date >= (now() - interval '12 months')::date
    AND ndvi IS NOT NULL
    AND (cloud_coverage IS NULL OR cloud_coverage < 40);

  IF v_n < 6 THEN
    RETURN jsonb_build_object(
      'status', 'insufficient_data',
      'readings', v_n,
      'note', 'precisa de pelo menos 6 leituras limpas nos ultimos 12 meses'
    );
  END IF;

  v_amplitude := v_max - v_min;

  -- Heuristica v1: amplitude temporal -> % nativa
  --   <0.15 = muito estavel = ~90% nativa
  --   0.15-0.25 = estavel    = ~65%
  --   0.25-0.40 = misto      = ~30%
  --   >0.40 = ciclico safra  = ~5%
  v_native_pct := CASE
    WHEN v_amplitude < 0.15 THEN 90
    WHEN v_amplitude < 0.25 THEN 65
    WHEN v_amplitude < 0.40 THEN 30
    ELSE                          5
  END;

  -- Classe da vegetacao nativa pelo nivel medio
  v_class := CASE
    WHEN v_mean >= 0.60 THEN 'forest'
    WHEN v_mean >= 0.40 THEN 'shrubland'
    ELSE                     'grassland'
  END;

  v_native_ha := COALESCE(v_property.area_ha, 0) * v_native_pct / 100.0;

  SELECT tco2_per_ha INTO v_tco2_ha
  FROM carbon_factors
  WHERE biome = v_biome AND class_name = v_class;

  IF v_tco2_ha IS NULL THEN
    SELECT tco2_per_ha INTO v_tco2_ha
    FROM carbon_factors WHERE biome = 'default' AND class_name = v_class;
  END IF;

  v_carbon := v_native_ha * COALESCE(v_tco2_ha, 0);

  INSERT INTO property_native_coverage (
    property_id, native_ha, native_pct, biome, carbon_stock_tco2,
    classes, mapbiomas_collection, mapbiomas_year, last_updated_at
  )
  VALUES (
    p_property_id,
    round(v_native_ha::numeric, 2),
    v_native_pct,
    v_biome,
    round(v_carbon::numeric, 1),
    jsonb_build_object(
      'dominant_class',     v_class,
      'tco2_per_ha_applied', v_tco2_ha,
      'ndvi_stats', jsonb_build_object(
        'n', v_n, 'mean', round(v_mean::numeric, 3),
        'std', round(v_std::numeric, 3),
        'min', round(v_min::numeric, 3),
        'max', round(v_max::numeric, 3),
        'amplitude', round(v_amplitude::numeric, 3)
      ),
      'model_version', 'ndvi-temporal-v1',
      'roadmap', 'v2 = overlay MapBiomas Colecao 9 com ST_Intersection exato'
    ),
    NULL, NULL, now()
  )
  ON CONFLICT (property_id) DO UPDATE SET
    native_ha          = EXCLUDED.native_ha,
    native_pct         = EXCLUDED.native_pct,
    biome              = EXCLUDED.biome,
    carbon_stock_tco2  = EXCLUDED.carbon_stock_tco2,
    classes            = EXCLUDED.classes,
    last_updated_at    = now();

  RETURN jsonb_build_object(
    'status',            'ok',
    'property_id',       p_property_id,
    'biome',             v_biome,
    'native_pct',        v_native_pct,
    'native_ha',         round(v_native_ha::numeric, 2),
    'carbon_stock_tco2', round(v_carbon::numeric, 1),
    'dominant_class',    v_class,
    'model_version',     'ndvi-temporal-v1'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_native_coverage(uuid) TO authenticated, service_role;

-- ============================================================
-- 4. compute_native_coverage_batch — roda pra todas as ativas
-- ============================================================
CREATE OR REPLACE FUNCTION public.compute_native_coverage_batch()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok    int := 0;
  v_skip  int := 0;
  v_rec   record;
  v_res   jsonb;
BEGIN
  FOR v_rec IN
    SELECT id FROM properties WHERE active = true AND geometry IS NOT NULL
  LOOP
    v_res := public.compute_native_coverage(v_rec.id);
    IF v_res->>'status' = 'ok' THEN v_ok := v_ok + 1; ELSE v_skip := v_skip + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', v_ok, 'skipped', v_skip, 'ran_at', now());
END;
$$;

REVOKE ALL ON FUNCTION public.compute_native_coverage_batch() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.compute_native_coverage_batch() TO service_role;

-- ============================================================
-- 5. pg_cron: roda diariamente as 10:30 UTC, depois do satellite fetch (10:00)
-- ============================================================
SELECT cron.schedule(
  'compute-native-coverage-daily',
  '30 10 * * *',
  $$ SELECT public.compute_native_coverage_batch(); $$
);

COMMENT ON FUNCTION public.compute_native_coverage IS
'Sprint 2 v1: classifica % nativa por estabilidade temporal NDVI (amplitude max-min em 12m). Roadmap v2: overlay MapBiomas Colecao 9 com ST_Intersection.';
