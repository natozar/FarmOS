-- 0031: defense-in-depth contra bot gastando tokens de IA
-- ========================================================
-- Camadas:
-- 1. feature_flags: kill switch admin-toggleable (sem deploy)
-- 2. ai_request_log: uma linha por chamada aprovada (pra burst e auditoria)
-- 3. bump_ai_usage v2: checa flag + burst (60s) + daily-user + daily-global
-- 4. cleanup_ai_request_log: remove registros > 7 dias (cron opcional)

-- ============================================================
-- feature_flags: admin liga/desliga features sem redeploy
-- ============================================================
CREATE TABLE IF NOT EXISTS public.feature_flags (
  key text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT true,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  note text
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

-- Leitura publica (o painel pode mostrar "IA indisponivel" pro user)
DROP POLICY IF EXISTS ff_read ON public.feature_flags;
CREATE POLICY ff_read ON public.feature_flags FOR SELECT USING (true);

-- Escrita so admin
DROP POLICY IF EXISTS ff_admin_update ON public.feature_flags;
CREATE POLICY ff_admin_update ON public.feature_flags FOR UPDATE
  USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS ff_admin_insert ON public.feature_flags;
CREATE POLICY ff_admin_insert ON public.feature_flags FOR INSERT
  WITH CHECK (public.is_admin());

INSERT INTO public.feature_flags (key, enabled, note) VALUES
  ('ai_suggest', true, 'Gemini — sugestoes no diario'),
  ('transcribe', true, 'Groq Whisper — transcricao de audio')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- ai_request_log: um evento por chamada aprovada
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_request_log (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  kind text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Indice composto pra burst-check (user + kind + tempo recente)
CREATE INDEX IF NOT EXISTS idx_ai_log_user_kind_time
  ON public.ai_request_log (user_id, kind, created_at DESC);

-- Indice pra global-check e dashboard (kind + tempo)
CREATE INDEX IF NOT EXISTS idx_ai_log_kind_time
  ON public.ai_request_log (kind, created_at DESC);

ALTER TABLE public.ai_request_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ail_admin_read ON public.ai_request_log;
CREATE POLICY ail_admin_read ON public.ai_request_log FOR SELECT
  USING (public.is_admin());

-- ============================================================
-- bump_ai_usage v2: checa tudo em uma transacao + registra evento
-- ============================================================
-- Contrato de retorno (jsonb):
--   Bloqueado: {allowed:false, reason:<str>, ...metadata}
--   Aprovado:  {allowed:true,  count_user, remaining_user, count_global, remaining_global}
-- Razoes possiveis: feature_disabled | burst | daily_user | global_ceiling
--
-- Sinatura com defaults — backward compat com chamadas da versao anterior.
CREATE OR REPLACE FUNCTION public.bump_ai_usage(
  p_user_id uuid,
  p_kind text,
  p_max_per_day integer,
  p_max_global_per_day integer DEFAULT 500,
  p_max_per_minute integer DEFAULT 5
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
  v_enabled boolean;
  v_minute_count integer;
  v_user_count integer;
  v_global_count integer;
BEGIN
  -- 1. Feature flag (kill switch). Sem row = default ON.
  SELECT enabled INTO v_enabled FROM feature_flags WHERE key = p_kind;
  IF v_enabled IS NOT NULL AND v_enabled = false THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'feature_disabled'
    );
  END IF;

  -- 2. Burst: 5 req/60s por user. Bloqueia loops apertados.
  SELECT count(*) INTO v_minute_count
  FROM ai_request_log
  WHERE user_id = p_user_id
    AND kind = p_kind
    AND created_at > now() - interval '60 seconds';

  IF v_minute_count >= p_max_per_minute THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'burst',
      'count_last_minute', v_minute_count,
      'max_per_minute', p_max_per_minute
    );
  END IF;

  -- 3. Per-user diario (fuso BRT)
  SELECT count(*) INTO v_user_count
  FROM ai_request_log
  WHERE user_id = p_user_id
    AND kind = p_kind
    AND (created_at AT TIME ZONE 'America/Sao_Paulo')::date = v_today;

  IF v_user_count >= p_max_per_day THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'daily_user',
      'count', v_user_count,
      'max', p_max_per_day
    );
  END IF;

  -- 4. Global diario (todos os users combinados)
  SELECT count(*) INTO v_global_count
  FROM ai_request_log
  WHERE kind = p_kind
    AND (created_at AT TIME ZONE 'America/Sao_Paulo')::date = v_today;

  IF v_global_count >= p_max_global_per_day THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'global_ceiling',
      'count_global', v_global_count,
      'max_global', p_max_global_per_day
    );
  END IF;

  -- Tudo OK — registra o evento e atualiza agregado
  INSERT INTO ai_request_log (user_id, kind) VALUES (p_user_id, p_kind);

  INSERT INTO ai_usage (user_id, kind, day, count, last_at)
  VALUES (p_user_id, p_kind, v_today, 1, now())
  ON CONFLICT (user_id, kind, day) DO UPDATE
    SET count = ai_usage.count + 1, last_at = now();

  RETURN jsonb_build_object(
    'allowed', true,
    'count_user', v_user_count + 1,
    'remaining_user', p_max_per_day - v_user_count - 1,
    'count_global', v_global_count + 1,
    'remaining_global', p_max_global_per_day - v_global_count - 1
  );
END;
$$;

REVOKE ALL ON FUNCTION public.bump_ai_usage(uuid, text, integer, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bump_ai_usage(uuid, text, integer, integer, integer) TO service_role;

-- ============================================================
-- cleanup: deleta registros > 7 dias
-- ============================================================
-- Burst check so olha 60s, daily olha 24h. Historico >7 dias so serve
-- pra auditoria manual via godmode. Admin pode chamar quando quiser
-- ou agendar via pg_cron.
CREATE OR REPLACE FUNCTION public.cleanup_ai_request_log()
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH deleted AS (
    DELETE FROM ai_request_log
    WHERE created_at < now() - interval '7 days'
    RETURNING 1
  )
  SELECT count(*)::int FROM deleted;
$$;

REVOKE ALL ON FUNCTION public.cleanup_ai_request_log() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_ai_request_log() TO service_role;

-- ============================================================
-- RPC: ai_usage_overview — dashboard do godmode
-- ============================================================
-- Retorna consumo de hoje (global + top users) pra admin ver ataque.
CREATE OR REPLACE FUNCTION public.ai_usage_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
  v_result jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin_only';
  END IF;

  SELECT jsonb_build_object(
    'today', v_today,
    'ai_suggest_today', (
      SELECT count(*) FROM ai_request_log
      WHERE kind = 'ai_suggest'
        AND (created_at AT TIME ZONE 'America/Sao_Paulo')::date = v_today
    ),
    'transcribe_today', (
      SELECT count(*) FROM ai_request_log
      WHERE kind = 'transcribe'
        AND (created_at AT TIME ZONE 'America/Sao_Paulo')::date = v_today
    ),
    'top_users_today', (
      SELECT coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) FROM (
        SELECT user_id, kind, count(*) AS n
        FROM ai_request_log
        WHERE (created_at AT TIME ZONE 'America/Sao_Paulo')::date = v_today
        GROUP BY user_id, kind
        ORDER BY n DESC
        LIMIT 10
      ) t
    ),
    'flags', (
      SELECT coalesce(jsonb_object_agg(key, enabled), '{}'::jsonb)
      FROM feature_flags
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ai_usage_overview() TO authenticated;
