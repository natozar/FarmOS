-- 0027: mesmo bug do 0026, agora em field_logs
-- ============================================================
-- fl_select e fl_insert liam (SELECT email FROM auth.users WHERE id = auth.uid())
-- dentro do USING/WITH CHECK — role authenticated nao tem permissao nessa tabela.
-- Resultado: gestor por email nao conseguia ler nem postar no diario.
-- Fix: usa auth.jwt()->>'email'.

DROP POLICY IF EXISTS fl_select ON public.field_logs;
DROP POLICY IF EXISTS fl_insert ON public.field_logs;

CREATE POLICY fl_select ON public.field_logs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = field_logs.property_id
      AND (
        p.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.property_managers pm
          WHERE pm.property_id = p.id
            AND (
              pm.manager_user_id = auth.uid()
              OR pm.manager_email = (auth.jwt() ->> 'email')
            )
        )
      )
  )
);

CREATE POLICY fl_insert ON public.field_logs FOR INSERT
WITH CHECK (
  auth.uid() = author_id
  AND EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = field_logs.property_id
      AND (
        p.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.property_managers pm
          WHERE pm.property_id = p.id
            AND (
              pm.manager_user_id = auth.uid()
              OR pm.manager_email = (auth.jwt() ->> 'email')
            )
        )
      )
  )
);
