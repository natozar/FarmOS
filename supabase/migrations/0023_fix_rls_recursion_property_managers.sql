-- Fix da recursão infinita de RLS entre properties e property_managers.
--
-- Cenário do bug:
--   1. SELECT em properties dispara prop_select
--   2. prop_select faz EXISTS em property_managers
--   3. property_managers.pm_select faz EXISTS em properties
--   4. ⇒ properties.prop_select dispara de novo → ∞
--
-- Sintoma: report.html quebrado com
-- "infinite recursion detected in policy for relation 'properties'".
-- O painel não sentia porque usa get_dashboard_overview (SECURITY DEFINER).
--
-- Fix padrão Postgres: helper SECURITY DEFINER que checa ownership
-- bypassando RLS. As policies de property_managers passam a chamar a função
-- em vez do EXISTS direto em properties — recursão quebrada na raiz.
--
-- Aplicado em produção em 2026-04-15.

CREATE OR REPLACE FUNCTION auth_user_owns_property(p_property_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM properties
    WHERE id = p_property_id AND owner_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS pm_select ON property_managers;
CREATE POLICY pm_select ON property_managers
  FOR SELECT USING (
    auth_user_owns_property(property_id)
    OR manager_user_id = auth.uid()
    OR manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS pm_insert ON property_managers;
CREATE POLICY pm_insert ON property_managers
  FOR INSERT WITH CHECK (auth_user_owns_property(property_id));

DROP POLICY IF EXISTS pm_delete ON property_managers;
CREATE POLICY pm_delete ON property_managers
  FOR DELETE USING (auth_user_owns_property(property_id));
