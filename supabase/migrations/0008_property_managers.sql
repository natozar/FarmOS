-- ============================================================
-- PROPERTY_MANAGERS — Onboarding Gestores (ADR-003)
-- Executar no SQL Editor do Supabase
-- ============================================================

-- 1. Tabela de relacionamento property_managers
CREATE TABLE IF NOT EXISTS property_managers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  manager_email VARCHAR(255) NOT NULL,
  manager_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  role VARCHAR(30) NOT NULL DEFAULT 'gestor',
  invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  UNIQUE(property_id, manager_email)
);

CREATE INDEX IF NOT EXISTS idx_pm_email ON property_managers(manager_email);
CREATE INDEX IF NOT EXISTS idx_pm_user ON property_managers(manager_user_id);
CREATE INDEX IF NOT EXISTS idx_pm_property ON property_managers(property_id);

-- 2. RLS
ALTER TABLE property_managers ENABLE ROW LEVEL SECURITY;

-- Proprietario ve os gestores das suas propriedades
CREATE POLICY "owner_read_managers" ON property_managers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM properties
      WHERE properties.id = property_managers.property_id
        AND properties.owner_id = auth.uid()
    )
  );

-- Gestor ve seus proprios vinculos
CREATE POLICY "manager_read_own" ON property_managers
  FOR SELECT USING (
    manager_user_id = auth.uid()
    OR manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

-- Proprietario insere gestores nas suas propriedades
CREATE POLICY "owner_insert_managers" ON property_managers
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM properties
      WHERE properties.id = property_managers.property_id
        AND properties.owner_id = auth.uid()
    )
  );

-- Proprietario remove gestores das suas propriedades
CREATE POLICY "owner_delete_managers" ON property_managers
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM properties
      WHERE properties.id = property_managers.property_id
        AND properties.owner_id = auth.uid()
    )
  );

-- 3. Atualizar RLS de properties para gestores verem as fazendas vinculadas
-- Policy existente: owner_id = auth.uid() (somente dono)
-- Adicionar: OU gestor vinculado pelo email/id
CREATE POLICY "manager_read_properties" ON properties
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM property_managers pm
      WHERE pm.property_id = properties.id
        AND (
          pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    )
  );

-- 4. Gestores podem ler satellite_readings das propriedades vinculadas
CREATE POLICY "manager_read_readings" ON satellite_readings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM property_managers pm
      WHERE pm.property_id = satellite_readings.property_id
        AND (
          pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    )
  );

-- 5. Gestores podem ler alertas das propriedades vinculadas
CREATE POLICY "manager_read_alerts" ON alerts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM property_managers pm
      WHERE pm.property_id = alerts.property_id
        AND (
          pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    )
  );

-- 6. Gestores podem ler e inserir field_logs das propriedades vinculadas
CREATE POLICY "manager_read_field_logs" ON field_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM property_managers pm
      WHERE pm.property_id = field_logs.property_id
        AND (
          pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    )
  );

CREATE POLICY "manager_insert_field_logs" ON field_logs
  FOR INSERT WITH CHECK (
    auth.uid() = author_id
    AND EXISTS (
      SELECT 1 FROM property_managers pm
      WHERE pm.property_id = field_logs.property_id
        AND (
          pm.manager_user_id = auth.uid()
          OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    )
  );

-- 7. Trigger: quando gestor faz login pela primeira vez, vincular manager_user_id
CREATE OR REPLACE FUNCTION link_manager_on_login()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE property_managers
  SET manager_user_id = NEW.id,
      accepted_at = COALESCE(accepted_at, now())
  WHERE manager_email = NEW.email
    AND manager_user_id IS NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger no auth.users (dispara quando novo user é criado)
DROP TRIGGER IF EXISTS on_auth_user_link_manager ON auth.users;
CREATE TRIGGER on_auth_user_link_manager
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION link_manager_on_login();

-- 8. RPC: listar gestores de uma propriedade (para o proprietario)
CREATE OR REPLACE FUNCTION get_property_managers(p_property_id UUID)
RETURNS TABLE (
  id UUID,
  manager_email VARCHAR,
  manager_user_id UUID,
  role VARCHAR,
  invited_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ
) AS $$
  SELECT pm.id, pm.manager_email, pm.manager_user_id, pm.role, pm.invited_at, pm.accepted_at
  FROM property_managers pm
  WHERE pm.property_id = p_property_id
  ORDER BY pm.invited_at DESC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 9. RPC: dashboard que inclui propriedades gerenciadas (para gestores)
-- O get_dashboard_overview existente filtra por owner_id.
-- Criamos uma versão para gestores:
CREATE OR REPLACE FUNCTION get_managed_properties(p_user_email TEXT)
RETURNS TABLE (
  property_id UUID,
  nome VARCHAR,
  municipio VARCHAR,
  estado VARCHAR,
  area_ha NUMERIC,
  role VARCHAR,
  last_ndvi NUMERIC,
  last_classification VARCHAR,
  geojson JSONB
) AS $$
  SELECT
    p.id AS property_id,
    p.nome,
    p.municipio,
    p.estado,
    p.area_ha,
    pm.role,
    sr.ndvi AS last_ndvi,
    sr.classification AS last_classification,
    ST_AsGeoJSON(p.geometry)::jsonb AS geojson
  FROM property_managers pm
  JOIN properties p ON p.id = pm.property_id
  LEFT JOIN LATERAL (
    SELECT ndvi, classification
    FROM satellite_readings
    WHERE property_id = p.id
    ORDER BY reading_date DESC
    LIMIT 1
  ) sr ON true
  WHERE pm.manager_email = p_user_email
    AND p.active = true
  ORDER BY p.nome;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
