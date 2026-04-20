-- 0029: marca de aprovação do lead (fluxo manual via godmode)
-- ============================================================
-- aprovado_at NULL = lead ainda pendente de convite.
-- aprovado_at timestamp = foi convidado. aprovado_por = user.id do admin.

ALTER TABLE public.participantes
  ADD COLUMN IF NOT EXISTS aprovado_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS aprovado_por uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_participantes_pendentes
  ON public.participantes (created_at DESC)
  WHERE aprovado_at IS NULL;

-- RLS: landing insere como anon; admin CEO lê tudo. Updates feitos via
-- service_role na edge function invite-lead (RLS nao aplica).
DROP POLICY IF EXISTS participantes_admin_read ON public.participantes;
CREATE POLICY participantes_admin_read ON public.participantes
FOR SELECT
USING (auth.jwt() ->> 'email' = 'chatsagrado@gmail.com');

DROP POLICY IF EXISTS participantes_public_insert ON public.participantes;
CREATE POLICY participantes_public_insert ON public.participantes
FOR INSERT
WITH CHECK (true);
