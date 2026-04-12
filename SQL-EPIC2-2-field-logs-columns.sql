-- EPIC 2: Colunas de insumo em field_logs — Rodar SEGUNDO
ALTER TABLE field_logs
  ADD COLUMN IF NOT EXISTS inventory_item_id UUID REFERENCES inventory_items(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS inventory_qty_used NUMERIC;
