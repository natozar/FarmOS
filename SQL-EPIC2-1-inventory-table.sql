-- EPIC 2: Inventário de Insumos — Rodar PRIMEIRO
CREATE TABLE IF NOT EXISTS inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  nome VARCHAR(200) NOT NULL,
  quantidade NUMERIC NOT NULL DEFAULT 0,
  unidade VARCHAR(30) NOT NULL DEFAULT 'un',
  categoria VARCHAR(50),
  custo_unitario NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_property ON inventory_items(property_id);

ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_all_inventory" ON inventory_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM properties WHERE properties.id = inventory_items.property_id AND properties.owner_id = auth.uid())
  );

CREATE POLICY "manager_read_inventory" ON inventory_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM property_managers pm WHERE pm.property_id = inventory_items.property_id
      AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())))
  );

CREATE POLICY "manager_update_inventory" ON inventory_items
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM property_managers pm WHERE pm.property_id = inventory_items.property_id
      AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (SELECT email FROM auth.users WHERE id = auth.uid())))
  );
