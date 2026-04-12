-- ============================================================
-- GODMODE: RPC admin para dashboard do CEO
-- Rodar no SQL Editor do Supabase
-- ============================================================

-- Lista de emails admin (alterar conforme necessário)
-- A validação é feita dentro da function

CREATE OR REPLACE FUNCTION admin_dashboard_data()
RETURNS TABLE (
  user_id UUID,
  user_email TEXT,
  user_nome TEXT,
  last_sign_in TIMESTAMPTZ,
  property_id UUID,
  property_nome VARCHAR,
  municipio VARCHAR,
  estado VARCHAR,
  area_ha NUMERIC,
  crop_type VARCHAR,
  last_ndvi NUMERIC,
  last_classification VARCHAR,
  last_reading_date DATE,
  financial_risk NUMERIC
) AS $$
BEGIN
  -- Validação: apenas emails autorizados
  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND email IN (
      'fazendeiro.teste@agruai.com',
      'renato@agruai.com',
      'admin@agruai.com'
    )
  ) THEN
    RAISE EXCEPTION 'Acesso negado: usuário não é admin';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email::TEXT AS user_email,
    COALESCE(u.raw_user_meta_data->>'nome', split_part(u.email, '@', 1))::TEXT AS user_nome,
    u.last_sign_in_at AS last_sign_in,
    p.id AS property_id,
    p.nome AS property_nome,
    p.municipio,
    p.estado,
    p.area_ha,
    p.crop_type,
    sr.ndvi AS last_ndvi,
    sr.classification AS last_classification,
    sr.reading_date::DATE AS last_reading_date,
    COALESCE(
      (SELECT SUM(a.estimated_risk) FROM alerts a WHERE a.property_id = p.id AND a.resolved = false),
      0
    ) AS financial_risk
  FROM auth.users u
  JOIN properties p ON p.owner_id = u.id AND p.active = true
  LEFT JOIN LATERAL (
    SELECT ndvi, classification, reading_date
    FROM satellite_readings
    WHERE property_id = p.id
    ORDER BY COALESCE(reading_date, captured_at) DESC
    LIMIT 1
  ) sr ON true
  ORDER BY COALESCE(
    (SELECT SUM(a2.estimated_risk) FROM alerts a2 WHERE a2.property_id = p.id AND a2.resolved = false),
    0
  ) DESC, u.email, p.nome;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Contagem de leads
CREATE OR REPLACE FUNCTION admin_stats()
RETURNS TABLE (
  total_users BIGINT,
  total_properties BIGINT,
  total_leads BIGINT,
  total_risk NUMERIC
) AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE id = auth.uid()
    AND email IN ('chatsagrado@gmail.com','fazendeiro.teste@agruai.com')
  ) THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM auth.users)::BIGINT,
    (SELECT COUNT(*) FROM properties WHERE active = true)::BIGINT,
    (SELECT COUNT(*) FROM participantes)::BIGINT,
    COALESCE((SELECT SUM(estimated_risk) FROM alerts WHERE resolved = false), 0)::NUMERIC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
