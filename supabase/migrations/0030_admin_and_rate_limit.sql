-- 0030: admin_users + ai_usage (rate limit pra IA/transcricao)
-- =============================================================
-- Objetivo:
-- 1. Tirar o email 'chatsagrado@gmail.com' hard-coded de politicas RLS
--    e edge functions. Fonte da verdade vira a tabela admin_users.
-- 2. Introduzir rate-limit diario por usuario nas edge functions de
--    custo (ai-suggest no Gemini free tier, transcribe-audio no Groq),
--    pra um convidado nao esgotar a cota do sistema.

-- ============================================================
-- admin_users: quem pode operar godmode / convidar leads
-- ============================================================
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  added_at timestamp with time zone NOT NULL DEFAULT now(),
  added_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  note text
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Ninguem le admin_users direto via RLS (so service_role, que ignora RLS).
-- Evita que um admin comprometido descubra os outros via SQL publico.
DROP POLICY IF EXISTS admin_users_no_read ON public.admin_users;
CREATE POLICY admin_users_no_read ON public.admin_users FOR SELECT USING (false);

-- Seed inicial: converte o email hard-coded em row de verdade
INSERT INTO public.admin_users (user_id, email, note)
SELECT id, email, 'seed inicial — CEO'
FROM auth.users
WHERE email = 'chatsagrado@gmail.com'
ON CONFLICT (user_id) DO NOTHING;

-- Helper pra RLS e para funcoes: e admin o user_id atual?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users WHERE user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- Substitui a policy de 0029 que lia email hard-coded
DROP POLICY IF EXISTS participantes_admin_read ON public.participantes;
CREATE POLICY participantes_admin_read ON public.participantes
FOR SELECT
USING (public.is_admin());

-- ============================================================
-- ai_usage: rate-limit diario por (user, kind)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_usage (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL,           -- 'ai_suggest' | 'transcribe'
  day date NOT NULL DEFAULT (now() AT TIME ZONE 'America/Sao_Paulo')::date,
  count integer NOT NULL DEFAULT 0,
  last_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, kind, day)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

-- Usuarios podem ver o proprio consumo (UX futura: "voce usou 12/30 hoje").
DROP POLICY IF EXISTS ai_usage_self_read ON public.ai_usage;
CREATE POLICY ai_usage_self_read ON public.ai_usage
FOR SELECT USING (auth.uid() = user_id);

-- Admins veem tudo, pra monitorar abuso.
DROP POLICY IF EXISTS ai_usage_admin_read ON public.ai_usage;
CREATE POLICY ai_usage_admin_read ON public.ai_usage
FOR SELECT USING (public.is_admin());

-- Ningem escreve via RLS; so service_role (edge functions).

-- Increment atomico + enforcement. Retorna:
--   { allowed: true,  remaining: N,  count: X }  se dentro do limite
--   { allowed: false, remaining: 0,  count: X,  max: M }  se bateu limite
-- Usa fuso BRT pra "o dia comeca as 00:00 em Sao Paulo", nao UTC.
CREATE OR REPLACE FUNCTION public.bump_ai_usage(
  p_user_id uuid,
  p_kind text,
  p_max_per_day integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
  v_count integer;
BEGIN
  -- Lock da linha se existir, ou cria em 0
  INSERT INTO public.ai_usage (user_id, kind, day, count, last_at)
  VALUES (p_user_id, p_kind, v_today, 0, now())
  ON CONFLICT (user_id, kind, day) DO NOTHING;

  -- Valor atual (ja travado pela proxima update)
  SELECT count INTO v_count
  FROM public.ai_usage
  WHERE user_id = p_user_id AND kind = p_kind AND day = v_today
  FOR UPDATE;

  IF v_count >= p_max_per_day THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'count', v_count,
      'max', p_max_per_day,
      'remaining', 0
    );
  END IF;

  UPDATE public.ai_usage
  SET count = count + 1, last_at = now()
  WHERE user_id = p_user_id AND kind = p_kind AND day = v_today
  RETURNING count INTO v_count;

  RETURN jsonb_build_object(
    'allowed', true,
    'count', v_count,
    'max', p_max_per_day,
    'remaining', p_max_per_day - v_count
  );
END;
$$;

-- Apenas service_role executa (edge functions usam service key).
REVOKE ALL ON FUNCTION public.bump_ai_usage(uuid, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bump_ai_usage(uuid, text, integer) TO service_role;

-- Retencao barata: 90 dias de historico chega. Indice pra limpeza.
CREATE INDEX IF NOT EXISTS idx_ai_usage_day ON public.ai_usage (day);
