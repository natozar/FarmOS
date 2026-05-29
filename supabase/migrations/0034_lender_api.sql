-- 0034: Sprint 3 — Endpoint pra credora consumir get_lender_report
-- =================================================================
-- 1. lender_clients: cada credora cadastrada recebe uma API key.
--    Guarda so o hash sha256 (nunca o segredo em claro).
-- 2. lender_property_access: que propriedade cada credora pode ler.
--    Concessao explicita do dono (ou do admin).
-- 3. lender_audit_log: toda chamada da API loga aqui. Base do
--    billing futuro e trail de compliance.

-- ============================================================
-- 1. lender_clients
-- ============================================================
CREATE TABLE IF NOT EXISTS public.lender_clients (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  contact_email   text,
  api_key_hash    text NOT NULL UNIQUE,         -- sha256 hex da chave
  api_key_prefix  text NOT NULL,                 -- primeiros 8 chars pra identificar nos logs
  active          boolean NOT NULL DEFAULT true,
  monthly_quota   int,                            -- null = ilimitado
  created_at      timestamptz NOT NULL DEFAULT now(),
  notes           text
);

ALTER TABLE public.lender_clients ENABLE ROW LEVEL SECURITY;

-- Ninguem le via RLS publico — so service_role (Edge Function) e admin.
DROP POLICY IF EXISTS lender_clients_admin_read ON public.lender_clients;
CREATE POLICY lender_clients_admin_read ON public.lender_clients
FOR SELECT USING (public.is_admin());

-- ============================================================
-- 2. lender_property_access
-- ============================================================
CREATE TABLE IF NOT EXISTS public.lender_property_access (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lender_id     uuid NOT NULL REFERENCES public.lender_clients(id) ON DELETE CASCADE,
  property_id   uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  granted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  granted_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz,
  UNIQUE (lender_id, property_id)
);

CREATE INDEX IF NOT EXISTS idx_lpa_lender ON public.lender_property_access (lender_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lpa_property ON public.lender_property_access (property_id) WHERE revoked_at IS NULL;

ALTER TABLE public.lender_property_access ENABLE ROW LEVEL SECURITY;

-- Dono ve quem ta vendo a fazenda dele.
DROP POLICY IF EXISTS lpa_owner_read ON public.lender_property_access;
CREATE POLICY lpa_owner_read ON public.lender_property_access
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = lender_property_access.property_id
      AND p.owner_id = auth.uid()
  )
);

-- Admin ve tudo.
DROP POLICY IF EXISTS lpa_admin_read ON public.lender_property_access;
CREATE POLICY lpa_admin_read ON public.lender_property_access
FOR SELECT USING (public.is_admin());

-- Dono concede acesso (futuro: UI no painel pra isso).
DROP POLICY IF EXISTS lpa_owner_grant ON public.lender_property_access;
CREATE POLICY lpa_owner_grant ON public.lender_property_access
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = lender_property_access.property_id
      AND p.owner_id = auth.uid()
  )
);

DROP POLICY IF EXISTS lpa_admin_grant ON public.lender_property_access;
CREATE POLICY lpa_admin_grant ON public.lender_property_access
FOR INSERT WITH CHECK (public.is_admin());

-- ============================================================
-- 3. lender_audit_log
-- ============================================================
CREATE TABLE IF NOT EXISTS public.lender_audit_log (
  id              bigserial PRIMARY KEY,
  lender_id       uuid REFERENCES public.lender_clients(id) ON DELETE SET NULL,
  api_key_prefix  text,
  property_id     uuid,
  endpoint        text NOT NULL,
  status_code     int NOT NULL,
  reason          text,
  ip              text,
  user_agent      text,
  called_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lal_lender_day ON public.lender_audit_log (lender_id, called_at DESC);

ALTER TABLE public.lender_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lal_admin_read ON public.lender_audit_log;
CREATE POLICY lal_admin_read ON public.lender_audit_log
FOR SELECT USING (public.is_admin());

-- ============================================================
-- 4. RPC pra Edge Function autenticar a credora
--    Recebe hash da api key, retorna lender_id se ativa, NULL caso contrario.
-- ============================================================
CREATE OR REPLACE FUNCTION public.lender_auth(p_api_key_hash text)
RETURNS TABLE (
  lender_id     uuid,
  name          text,
  monthly_quota int,
  prefix        text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, name, monthly_quota, api_key_prefix
  FROM lender_clients
  WHERE api_key_hash = p_api_key_hash
    AND active = true
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.lender_auth(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lender_auth(text) TO service_role;

-- ============================================================
-- 5. RPC pra checar acesso a uma propriedade (usada pela Edge Function)
-- ============================================================
CREATE OR REPLACE FUNCTION public.lender_has_access(p_lender_id uuid, p_property_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM lender_property_access
    WHERE lender_id = p_lender_id
      AND property_id = p_property_id
      AND revoked_at IS NULL
  );
$$;

REVOKE ALL ON FUNCTION public.lender_has_access(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lender_has_access(uuid, uuid) TO service_role;

-- ============================================================
-- 6. RPC admin: criar credora + retornar api_key em claro UMA VEZ
--    (CEO usa via godmode pra emitir chave)
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_lender_client(
  p_name text,
  p_contact_email text DEFAULT NULL,
  p_monthly_quota int DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_raw_key text;
  v_hash text;
  v_prefix text;
  v_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin_only';
  END IF;

  -- chave: prefixo agruai_lk_ + 40 chars random hex
  v_raw_key := 'agruai_lk_' || encode(gen_random_bytes(20), 'hex');
  v_prefix  := substring(v_raw_key from 1 for 18);
  v_hash    := encode(extensions.digest(v_raw_key, 'sha256'), 'hex');

  INSERT INTO lender_clients (name, contact_email, api_key_hash, api_key_prefix, monthly_quota, notes)
  VALUES (p_name, p_contact_email, v_hash, v_prefix, p_monthly_quota, p_notes)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'id', v_id,
    'name', p_name,
    'api_key', v_raw_key,
    'api_key_prefix', v_prefix,
    'warning', 'guarde essa chave em local seguro — nao podera ser recuperada'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_lender_client(text, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_lender_client(text, text, int, text) TO authenticated;

-- ============================================================
-- 7. RPC admin: conceder acesso a propriedade (sem precisar de UI)
-- ============================================================
CREATE OR REPLACE FUNCTION public.grant_lender_access(p_lender_id uuid, p_property_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
BEGIN
  SELECT owner_id INTO v_owner FROM properties WHERE id = p_property_id;
  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('error', 'property_not_found');
  END IF;

  -- So dono ou admin podem conceder
  IF auth.uid() <> v_owner AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO lender_property_access (lender_id, property_id, granted_by)
  VALUES (p_lender_id, p_property_id, auth.uid())
  ON CONFLICT (lender_id, property_id) DO UPDATE
    SET revoked_at = NULL, granted_at = now(), granted_by = auth.uid();

  RETURN jsonb_build_object('ok', true, 'lender_id', p_lender_id, 'property_id', p_property_id);
END;
$$;

REVOKE ALL ON FUNCTION public.grant_lender_access(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grant_lender_access(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION public.create_lender_client IS
'Admin-only. Gera api_key em claro UMA vez (retorno), grava sha256. Use no godmode pra emitir credenciais pra credoras.';
