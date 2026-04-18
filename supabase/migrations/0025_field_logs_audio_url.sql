-- 0025: campo audio_url em field_logs + audio_url no RPC de timeline
-- ============================================================
-- Adiciona suporte pra anexar o arquivo de audio original ao log,
-- permitindo playback na timeline e transcricao Whisper opcional.

ALTER TABLE public.field_logs
  ADD COLUMN IF NOT EXISTS audio_url text;

-- Recria get_property_timeline expondo photo_url e audio_url
DROP FUNCTION IF EXISTS public.get_property_timeline(uuid, integer);

CREATE FUNCTION public.get_property_timeline(p_property_id uuid, p_limit integer DEFAULT 30)
 RETURNS TABLE (
   id uuid,
   entry_type text,
   content text,
   author_name text,
   sector text,
   severity text,
   kanban_status text,
   photo_url text,
   audio_url text,
   created_at timestamp with time zone
 )
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT fl.id, 'log'::TEXT, fl.content,
    COALESCE(u.raw_user_meta_data->>'nome', u.email)::TEXT,
    COALESCE(fl.sector, pm.sector, 'operacional')::TEXT, NULL::TEXT,
    COALESCE(fl.kanban_status, 'pendente')::TEXT,
    fl.photo_url::TEXT,
    fl.audio_url::TEXT,
    fl.created_at
  FROM field_logs fl
  JOIN auth.users u ON u.id = fl.author_id
  LEFT JOIN property_managers pm ON pm.manager_email = u.email AND pm.property_id = fl.property_id
  WHERE fl.property_id = p_property_id
  UNION ALL
  SELECT a.id, 'alert'::TEXT, a.message, 'Satélite'::TEXT,
    'satelite'::TEXT, a.severity, NULL::TEXT, NULL::TEXT, NULL::TEXT, a.created_at
  FROM alerts a WHERE a.property_id = p_property_id
  ORDER BY created_at DESC LIMIT p_limit;
$function$;
