-- Fix do trigger calculate_centroid: ROUND(double precision, integer) não existe
-- no Postgres. ST_Area retorna double precision; é preciso castar para numeric
-- antes de chamar ROUND.
--
-- Bug descoberto ao tentar inserir uma propriedade nova durante o seed do
-- tutorial. Aplicado em produção em 2026-04-15.

CREATE OR REPLACE FUNCTION calculate_centroid()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.geometry IS NOT NULL THEN
    NEW.centroid := ST_Centroid(NEW.geometry);
    NEW.area_ha := ROUND((ST_Area(NEW.geometry::geography) / 10000)::numeric, 2);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
