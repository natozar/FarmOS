-- 0026: corrige 403 (permission denied for table users)
-- ============================================================
-- Duas policies RLS liam auth.users dentro do USING, mas o role
-- 'authenticated' nao tem SELECT em auth.users — resultado: 403
-- pra TODO SELECT em properties (porque prop_select cascade em
-- property_managers via EXISTS, e pm_select tambem tinha o bug).
--
-- Fix em ambas: substitui (SELECT email FROM auth.users WHERE id=auth.uid())
-- por auth.jwt()->>'email', que pega o email direto do token.

DROP POLICY IF EXISTS prop_select ON public.properties;

CREATE POLICY prop_select ON public.properties FOR SELECT
USING (
  owner_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.property_managers pm
    WHERE pm.property_id = properties.id
      AND (
        pm.manager_user_id = auth.uid()
        OR pm.manager_email = (auth.jwt() ->> 'email')
      )
  )
);

DROP POLICY IF EXISTS pm_select ON public.property_managers;

CREATE POLICY pm_select ON public.property_managers FOR SELECT
USING (
  auth_user_owns_property(property_id)
  OR manager_user_id = auth.uid()
  OR manager_email = (auth.jwt() ->> 'email')
);
