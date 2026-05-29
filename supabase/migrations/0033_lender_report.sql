-- 0033: Sprint 1 — Relatorio consolidado pra credoras
-- ====================================================
-- Objetivo:
-- 1. crop_yield_curves: coeficientes NDVI -> sacas/ha por cultura/regiao,
--    em tabela pra calibrar sem mexer no codigo. Seed inicial: soja BR.
-- 2. property_native_coverage: hectares de vegetacao nativa + tCO2 estocado
--    por propriedade. Placeholder ate o Sprint 2 preencher via overlay
--    MapBiomas Colecao 9.
-- 3. get_lender_report(p_property_id) -> jsonb: relatorio unico que junta
--    identificacao + serie satelite (24 meses) + producao estimada + mata.
--    Owner-only por padrao; service_role bypassa (Edge Function da credora
--    no Sprint 3).

-- ============================================================
-- 1. crop_yield_curves
-- ============================================================
-- Modelo linear: yield_sacas_ha = coef_a * ndvi_peak + coef_b
-- Coeficientes a calibrar com dados historicos. Versao v1 conservadora.

CREATE TABLE IF NOT EXISTS public.crop_yield_curves (
  id           serial PRIMARY KEY,
  crop_type    text NOT NULL,
  region       text NOT NULL DEFAULT 'BR',
  cycle_days   int  NOT NULL DEFAULT 120,
  coef_a       numeric NOT NULL,
  coef_b       numeric NOT NULL,
  unit         text NOT NULL DEFAULT 'sacas/ha',
  source       text,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (crop_type, region)
);

INSERT INTO public.crop_yield_curves (crop_type, region, cycle_days, coef_a, coef_b, source)
VALUES ('soja', 'BR', 120, 80, -6, 'v1 — curva linear conservadora baseline Embrapa Soja')
ON CONFLICT (crop_type, region) DO NOTHING;

-- Leitura publica (tabela de referencia, sem PII).
ALTER TABLE public.crop_yield_curves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS yield_curves_read ON public.crop_yield_curves;
CREATE POLICY yield_curves_read ON public.crop_yield_curves FOR SELECT USING (true);

-- ============================================================
-- 2. property_native_coverage  (preenchida no Sprint 2)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.property_native_coverage (
  property_id           uuid PRIMARY KEY REFERENCES public.properties(id) ON DELETE CASCADE,
  native_ha             numeric NOT NULL DEFAULT 0,
  native_pct            numeric NOT NULL DEFAULT 0,
  biome                 text,
  carbon_stock_tco2     numeric NOT NULL DEFAULT 0,
  classes               jsonb,
  mapbiomas_collection  int,
  mapbiomas_year        int,
  last_updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.property_native_coverage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pnc_owner_read ON public.property_native_coverage;
CREATE POLICY pnc_owner_read ON public.property_native_coverage
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = property_native_coverage.property_id
      AND p.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS pnc_admin_read ON public.property_native_coverage;
CREATE POLICY pnc_admin_read ON public.property_native_coverage
FOR SELECT USING (public.is_admin());

-- ============================================================
-- 3. get_lender_report  — JSON consolidado por propriedade
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_lender_report(p_property_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property         properties%ROWTYPE;
  v_curve            crop_yield_curves%ROWTYPE;
  v_series           jsonb;
  v_readings_count   int;
  v_ndvi_peak        numeric;
  v_ndvi_mean        numeric;
  v_yield_estimate   numeric;
  v_native           jsonb;
BEGIN
  SELECT * INTO v_property FROM properties WHERE id = p_property_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'property_not_found');
  END IF;

  -- Autorizacao: dono, admin, ou service_role (auth.uid() IS NULL)
  IF auth.uid() IS NOT NULL
     AND auth.uid() <> v_property.owner_id
     AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('error', 'forbidden');
  END IF;

  -- Serie satelite 24 meses
  SELECT
    jsonb_agg(
      jsonb_build_object(
        'date',           reading_date,
        'ndvi',           ndvi,
        'evi',            evi,
        'ndwi',           ndwi,
        'classification', classification,
        'cloud_coverage', cloud_coverage
      ) ORDER BY reading_date DESC
    ),
    COUNT(*)
  INTO v_series, v_readings_count
  FROM satellite_readings
  WHERE property_id = p_property_id
    AND reading_date >= (now() - interval '24 months')::date;

  -- Producao estimada: busca curva da cultura (regiao especifica > BR generico)
  IF v_property.crop_type IS NOT NULL THEN
    SELECT * INTO v_curve
    FROM crop_yield_curves
    WHERE crop_type = v_property.crop_type
    ORDER BY (CASE region WHEN v_property.estado THEN 0 ELSE 1 END), id
    LIMIT 1;

    IF FOUND THEN
      SELECT MAX(ndvi), AVG(ndvi)
      INTO v_ndvi_peak, v_ndvi_mean
      FROM satellite_readings
      WHERE property_id = p_property_id
        AND reading_date >= (now() - (v_curve.cycle_days || ' days')::interval)::date
        AND ndvi IS NOT NULL;

      IF v_ndvi_peak IS NOT NULL THEN
        v_yield_estimate := v_curve.coef_a * v_ndvi_peak + v_curve.coef_b;
      END IF;
    END IF;
  END IF;

  -- Mata preservada (placeholder ate Sprint 2)
  SELECT jsonb_build_object(
    'status',                'available',
    'native_ha',             native_ha,
    'native_pct',            native_pct,
    'biome',                 biome,
    'carbon_stock_tco2',     carbon_stock_tco2,
    'classes',               classes,
    'mapbiomas_collection',  mapbiomas_collection,
    'mapbiomas_year',        mapbiomas_year,
    'last_updated_at',       last_updated_at
  )
  INTO v_native
  FROM property_native_coverage
  WHERE property_id = p_property_id;

  IF v_native IS NULL THEN
    v_native := jsonb_build_object(
      'status', 'pending',
      'note',   'preenchido pelo overlay MapBiomas no Sprint 2'
    );
  END IF;

  RETURN jsonb_build_object(
    'schema_version', 1,
    'generated_at',   now(),
    'property', jsonb_build_object(
      'id',         v_property.id,
      'owner_id',   v_property.owner_id,
      'nome',       v_property.nome,
      'car_code',   v_property.car_code,
      'municipio',  v_property.municipio,
      'estado',     v_property.estado,
      'area_ha',    v_property.area_ha,
      'crop_type',  v_property.crop_type,
      'geometry',   ST_AsGeoJSON(v_property.geometry)::jsonb,
      'centroid',   ST_AsGeoJSON(ST_Centroid(v_property.geometry))::jsonb
    ),
    'satellite', jsonb_build_object(
      'readings_count', COALESCE(v_readings_count, 0),
      'window_months',  24,
      'series',         COALESCE(v_series, '[]'::jsonb)
    ),
    'production', CASE
      WHEN v_yield_estimate IS NULL THEN jsonb_build_object(
        'status', 'unavailable',
        'reason', CASE
          WHEN v_property.crop_type IS NULL THEN 'crop_type_missing'
          WHEN v_curve.id IS NULL         THEN 'curve_not_found'
          ELSE 'no_ndvi_in_cycle'
        END
      )
      ELSE jsonb_build_object(
        'status',                'estimated',
        'crop_type',             v_property.crop_type,
        'cycle_days',            v_curve.cycle_days,
        'ndvi_peak',             v_ndvi_peak,
        'ndvi_mean',             v_ndvi_mean,
        'estimate_sacas_ha',     round(v_yield_estimate::numeric, 1),
        'estimate_range',        jsonb_build_object(
          'low',  round((v_yield_estimate * 0.85)::numeric, 1),
          'high', round((v_yield_estimate * 1.10)::numeric, 1)
        ),
        'total_sacas_estimated', round((v_yield_estimate * COALESCE(v_property.area_ha, 0))::numeric, 0),
        'model_version',         'linear-v1',
        'curve_source',          v_curve.source
      )
    END,
    'native_coverage', v_native
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_lender_report(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.get_lender_report IS
'Sprint 1 (credora): JSON consolidado por propriedade — identificacao + serie satelite 24m + producao estimada (NDVI pico -> sacas/ha via crop_yield_curves) + mata preservada (placeholder ate Sprint 2 MapBiomas). Owner-only, admin ou service_role.';
