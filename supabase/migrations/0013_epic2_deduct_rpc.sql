-- EPIC 2: RPC para registrar uso de insumo com abatimento atômico — Rodar TERCEIRO
CREATE OR REPLACE FUNCTION use_inventory_item(
  p_item_id UUID,
  p_qty NUMERIC
) RETURNS NUMERIC AS $$
  UPDATE inventory_items
  SET quantidade = GREATEST(quantidade - p_qty, 0),
      updated_at = now()
  WHERE id = p_item_id
  RETURNING quantidade;
$$ LANGUAGE sql SECURITY DEFINER;
