-- ============================================================
-- RLS FINAL — Auditoria de Segurança Pre-Launch
-- Rodar no SQL Editor do Supabase
--
-- Garante que TODAS as tabelas críticas têm RLS ativo
-- com policies restritivas por owner_id + property_managers
-- ============================================================

-- 1. FORÇAR RLS ATIVO em todas as tabelas
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE satellite_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE field_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_managers ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

-- Forçar RLS mesmo para o owner da tabela (previne bypass)
ALTER TABLE properties FORCE ROW LEVEL SECURITY;
ALTER TABLE satellite_readings FORCE ROW LEVEL SECURITY;
ALTER TABLE alerts FORCE ROW LEVEL SECURITY;
ALTER TABLE field_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE property_managers FORCE ROW LEVEL SECURITY;
ALTER TABLE inventory_items FORCE ROW LEVEL SECURITY;

-- ============================================================
-- 2. PROPERTIES — dono ve as suas, gestor ve as vinculadas
-- ============================================================
-- Dropar policies antigas que possam conflitar
DROP POLICY IF EXISTS "owner_read_properties" ON properties;
DROP POLICY IF EXISTS "manager_read_properties" ON properties;
DROP POLICY IF EXISTS "Users can view own properties" ON properties;
DROP POLICY IF EXISTS "users_own_properties" ON properties;

CREATE POLICY "prop_select" ON properties FOR SELECT USING (
  owner_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM property_managers pm
    WHERE pm.property_id = properties.id
    AND (pm.manager_user_id = auth.uid()
      OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
  )
);

DROP POLICY IF EXISTS "owner_insert_properties" ON properties;
CREATE POLICY "prop_insert" ON properties FOR INSERT
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "owner_update_properties" ON properties;
CREATE POLICY "prop_update" ON properties FOR UPDATE
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "owner_delete_properties" ON properties;
CREATE POLICY "prop_delete" ON properties FOR DELETE
  USING (owner_id = auth.uid());

-- ============================================================
-- 3. SATELLITE_READINGS — dono + gestores (somente leitura)
-- ============================================================
DROP POLICY IF EXISTS "owner_read_readings" ON satellite_readings;
DROP POLICY IF EXISTS "manager_read_readings" ON satellite_readings;
DROP POLICY IF EXISTS "Users can view own readings" ON satellite_readings;

CREATE POLICY "sr_select" ON satellite_readings FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = satellite_readings.property_id
    AND (p.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM property_managers pm
        WHERE pm.property_id = p.id
        AND (pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
      ))
  )
);

-- ============================================================
-- 4. ALERTS — dono + gestores leem, dono resolve
-- ============================================================
DROP POLICY IF EXISTS "owner_read_alerts" ON alerts;
DROP POLICY IF EXISTS "manager_read_alerts" ON alerts;

CREATE POLICY "alert_select" ON alerts FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = alerts.property_id
    AND (p.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM property_managers pm
        WHERE pm.property_id = p.id
        AND (pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
      ))
  )
);

DROP POLICY IF EXISTS "owner_update_alerts" ON alerts;
CREATE POLICY "alert_update" ON alerts FOR UPDATE USING (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = alerts.property_id AND p.owner_id = auth.uid())
);

-- ============================================================
-- 5. FIELD_LOGS — dono + gestores leem/inserem, autor deleta
-- ============================================================
DROP POLICY IF EXISTS "owner_read_field_logs" ON field_logs;
DROP POLICY IF EXISTS "owner_insert_field_logs" ON field_logs;
DROP POLICY IF EXISTS "owner_delete_own_logs" ON field_logs;
DROP POLICY IF EXISTS "manager_read_field_logs" ON field_logs;
DROP POLICY IF EXISTS "manager_insert_field_logs" ON field_logs;

CREATE POLICY "fl_select" ON field_logs FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = field_logs.property_id
    AND (p.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM property_managers pm
        WHERE pm.property_id = p.id
        AND (pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
      ))
  )
);

CREATE POLICY "fl_insert" ON field_logs FOR INSERT WITH CHECK (
  auth.uid() = author_id
  AND EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = field_logs.property_id
    AND (p.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM property_managers pm
        WHERE pm.property_id = p.id
        AND (pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
      ))
  )
);

CREATE POLICY "fl_delete" ON field_logs FOR DELETE
  USING (auth.uid() = author_id);

-- ============================================================
-- 6. INVENTORY_ITEMS — dono CRUD, gestores leem/atualizam
-- ============================================================
DROP POLICY IF EXISTS "owner_all_inventory" ON inventory_items;
DROP POLICY IF EXISTS "manager_read_inventory" ON inventory_items;
DROP POLICY IF EXISTS "manager_update_inventory" ON inventory_items;

CREATE POLICY "inv_select" ON inventory_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = inventory_items.property_id
    AND (p.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM property_managers pm
        WHERE pm.property_id = p.id
        AND (pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
      ))
  )
);

CREATE POLICY "inv_insert" ON inventory_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = inventory_items.property_id AND p.owner_id = auth.uid())
);

CREATE POLICY "inv_update" ON inventory_items FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = inventory_items.property_id
    AND (p.owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM property_managers pm
        WHERE pm.property_id = p.id
        AND (pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
      ))
  )
);

CREATE POLICY "inv_delete" ON inventory_items FOR DELETE USING (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = inventory_items.property_id AND p.owner_id = auth.uid())
);

-- ============================================================
-- 7. PROPERTY_MANAGERS — dono gerencia, gestor lê o seu
-- ============================================================
DROP POLICY IF EXISTS "owner_read_managers" ON property_managers;
DROP POLICY IF EXISTS "owner_insert_managers" ON property_managers;
DROP POLICY IF EXISTS "owner_delete_managers" ON property_managers;
DROP POLICY IF EXISTS "manager_read_own" ON property_managers;

CREATE POLICY "pm_select" ON property_managers FOR SELECT USING (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = property_managers.property_id AND p.owner_id = auth.uid())
  OR manager_user_id = auth.uid()
  OR manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

CREATE POLICY "pm_insert" ON property_managers FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = property_managers.property_id AND p.owner_id = auth.uid())
);

CREATE POLICY "pm_delete" ON property_managers FOR DELETE USING (
  EXISTS (SELECT 1 FROM properties p WHERE p.id = property_managers.property_id AND p.owner_id = auth.uid())
);
