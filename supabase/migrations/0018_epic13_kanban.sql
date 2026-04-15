-- ============================================================
-- EPIC 13: Kanban status em field_logs + work orders
-- Rodar no SQL Editor do Supabase
-- ============================================================

-- 1. Status kanban nos field_logs
ALTER TABLE field_logs
  ADD COLUMN IF NOT EXISTS kanban_status VARCHAR(20) DEFAULT 'pendente';

COMMENT ON COLUMN field_logs.kanban_status IS 'pendente, em_andamento, resolvido';

-- 2. Atualizar RPC get_property_timeline para retornar kanban_status
DROP FUNCTION IF EXISTS get_property_timeline(UUID, INT);

CREATE FUNCTION get_property_timeline(p_property_id UUID, p_limit INT DEFAULT 30)
RETURNS TABLE (
  id UUID, entry_type TEXT, content TEXT, author_name TEXT,
  sector TEXT, severity TEXT, kanban_status TEXT, created_at TIMESTAMPTZ
) AS $$
  SELECT fl.id, 'log'::TEXT, fl.content,
    COALESCE(p.raw_user_meta_data->>'nome', u.email)::TEXT,
    COALESCE(fl.sector, pm.sector, 'operacional')::TEXT, NULL::TEXT,
    COALESCE(fl.kanban_status, 'pendente')::TEXT, fl.created_at
  FROM field_logs fl
  JOIN auth.users u ON u.id = fl.author_id
  LEFT JOIN profiles p ON p.id = fl.author_id
  LEFT JOIN property_managers pm ON pm.manager_email = u.email AND pm.property_id = fl.property_id
  WHERE fl.property_id = p_property_id
  UNION ALL
  SELECT a.id, 'alert'::TEXT, a.message, 'Satélite'::TEXT,
    'satelite'::TEXT, a.severity, NULL::TEXT, a.created_at
  FROM alerts a WHERE a.property_id = p_property_id
  ORDER BY created_at DESC LIMIT p_limit;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
