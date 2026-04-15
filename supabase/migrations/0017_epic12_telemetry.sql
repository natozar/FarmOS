-- ============================================================
-- EPIC 12: Telemetria Anônima + Perfil Enriquecido
-- LGPD-safe: sem PII na telemetria, consentimento no perfil
-- Rodar no SQL Editor do Supabase
-- ============================================================

-- 1. Telemetria de comportamento (anônima, sem PII)
CREATE TABLE IF NOT EXISTS behavioral_telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id VARCHAR(40) NOT NULL,
  event_name VARCHAR(60) NOT NULL,
  event_data JSONB DEFAULT '{}',
  property_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bt_event ON behavioral_telemetry(event_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bt_session ON behavioral_telemetry(session_id);

-- RLS: ninguém lê via API client (só admin RPCs)
ALTER TABLE behavioral_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE behavioral_telemetry FORCE ROW LEVEL SECURITY;

-- Qualquer autenticado insere (mas não lê)
CREATE POLICY "bt_insert" ON behavioral_telemetry
  FOR INSERT WITH CHECK (true);

-- 2. Perfil enriquecido do fazendeiro (voluntário, com consentimento)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS farm_profile JSONB DEFAULT '{}';

COMMENT ON COLUMN profiles.farm_profile IS 'Dados voluntários: marca_trator, raca_gado, cabecas, fornecedor_racao, etc. Preenchidos pelo fazendeiro com consentimento.';

-- 3. RPC admin: dashboard de telemetria agregada
CREATE OR REPLACE FUNCTION admin_telemetry_summary()
RETURNS TABLE (
  event_name VARCHAR,
  total_count BIGINT,
  unique_sessions BIGINT,
  last_7d BIGINT
) AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE id = auth.uid()
    AND email IN ('chatsagrado@gmail.com','fazendeiro.teste@agruai.com')
  ) THEN RAISE EXCEPTION 'Acesso negado'; END IF;

  RETURN QUERY
  SELECT
    bt.event_name,
    COUNT(*)::BIGINT AS total_count,
    COUNT(DISTINCT bt.session_id)::BIGINT AS unique_sessions,
    COUNT(*) FILTER (WHERE bt.created_at >= now() - INTERVAL '7 days')::BIGINT AS last_7d
  FROM behavioral_telemetry bt
  GROUP BY bt.event_name
  ORDER BY total_count DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
