-- ============================================================
-- ADR-005: Atualizar RPCs para retornar sector
-- Executar DEPOIS do primeiro script
-- ============================================================

DROP FUNCTION IF EXISTS get_property_timeline(UUID, INT);

CREATE FUNCTION get_property_timeline(p_property_id UUID, p_limit INT DEFAULT 30)
RETURNS TABLE (
  id UUID,
  entry_type TEXT,
  content TEXT,
  author_name TEXT,
  sector TEXT,
  severity TEXT,
  created_at TIMESTAMPTZ
) AS $$
  SELECT
    fl.id,
    'log'::TEXT AS entry_type,
    fl.content,
    COALESCE(p.raw_user_meta_data->>'nome', u.email) AS author_name,
    COALESCE(fl.sector, pm.sector, 'operacional')::TEXT AS sector,
    NULL::TEXT AS severity,
    fl.created_at
  FROM field_logs fl
  JOIN auth.users u ON u.id = fl.author_id
  LEFT JOIN profiles p ON p.id = fl.author_id
  LEFT JOIN property_managers pm ON pm.manager_email = u.email AND pm.property_id = fl.property_id
  WHERE fl.property_id = p_property_id

  UNION ALL

  SELECT
    a.id,
    'alert'::TEXT AS entry_type,
    a.message AS content,
    'Satélite'::TEXT AS author_name,
    'satelite'::TEXT AS sector,
    a.severity,
    a.created_at
  FROM alerts a
  WHERE a.property_id = p_property_id

  ORDER BY created_at DESC
  LIMIT p_limit;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
