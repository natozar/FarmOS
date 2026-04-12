-- ============================================================
-- FIELD_LOGS — Diario de Campo (ADR-002)
-- Executar no SQL Editor do Supabase
-- ============================================================

-- 1. Tabela field_logs
CREATE TABLE IF NOT EXISTS field_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  photo_url VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_field_logs_property ON field_logs(property_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_field_logs_author ON field_logs(author_id);

-- 2. RLS
ALTER TABLE field_logs ENABLE ROW LEVEL SECURITY;

-- Gestor ve logs das suas propriedades
CREATE POLICY "owner_read_field_logs" ON field_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM properties
      WHERE properties.id = field_logs.property_id
        AND properties.owner_id = auth.uid()
    )
  );

-- Gestor insere logs nas suas propriedades
CREATE POLICY "owner_insert_field_logs" ON field_logs
  FOR INSERT WITH CHECK (
    auth.uid() = author_id
    AND EXISTS (
      SELECT 1 FROM properties
      WHERE properties.id = field_logs.property_id
        AND properties.owner_id = auth.uid()
    )
  );

-- Gestor deleta seus proprios logs
CREATE POLICY "owner_delete_own_logs" ON field_logs
  FOR DELETE USING (
    auth.uid() = author_id
  );

-- 3. RPC: buscar logs de uma propriedade (com nome do autor)
CREATE OR REPLACE FUNCTION get_field_logs(p_property_id UUID, p_limit INT DEFAULT 50)
RETURNS TABLE (
  id UUID,
  property_id UUID,
  author_id UUID,
  author_name TEXT,
  content TEXT,
  photo_url VARCHAR,
  created_at TIMESTAMPTZ
) AS $$
  SELECT
    fl.id,
    fl.property_id,
    fl.author_id,
    COALESCE(p.raw_user_meta_data->>'nome', u.email) AS author_name,
    fl.content,
    fl.photo_url,
    fl.created_at
  FROM field_logs fl
  JOIN auth.users u ON u.id = fl.author_id
  LEFT JOIN profiles p ON p.id = fl.author_id
  WHERE fl.property_id = p_property_id
  ORDER BY fl.created_at DESC
  LIMIT p_limit;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 4. RPC: timeline mista (logs + alertas juntos, ordenados por data)
CREATE OR REPLACE FUNCTION get_property_timeline(p_property_id UUID, p_limit INT DEFAULT 30)
RETURNS TABLE (
  id UUID,
  entry_type TEXT,
  content TEXT,
  author_name TEXT,
  severity TEXT,
  created_at TIMESTAMPTZ
) AS $$
  -- Logs do diario
  SELECT
    fl.id,
    'log'::TEXT AS entry_type,
    fl.content,
    COALESCE(p.raw_user_meta_data->>'nome', u.email) AS author_name,
    NULL::TEXT AS severity,
    fl.created_at
  FROM field_logs fl
  JOIN auth.users u ON u.id = fl.author_id
  LEFT JOIN profiles p ON p.id = fl.author_id
  WHERE fl.property_id = p_property_id

  UNION ALL

  -- Alertas automaticos
  SELECT
    a.id,
    'alert'::TEXT AS entry_type,
    a.message AS content,
    'Satélite'::TEXT AS author_name,
    a.severity,
    a.created_at
  FROM alerts a
  WHERE a.property_id = p_property_id

  ORDER BY created_at DESC
  LIMIT p_limit;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
