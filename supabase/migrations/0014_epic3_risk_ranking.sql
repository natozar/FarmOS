-- EPIC 3: Risco financeiro nos alertas — Rodar no SQL Editor
ALTER TABLE alerts
  ADD COLUMN IF NOT EXISTS estimated_risk NUMERIC DEFAULT 0;

COMMENT ON COLUMN alerts.estimated_risk IS 'Valor estimado de prejuizo em R$ calculado pelo front com base no crop_type e area afetada';
