-- ============================================================
-- ADR-005: Setores e Especialidades
-- Executar no SQL Editor do Supabase
-- ============================================================

-- 1. Adicionar sector em property_managers
ALTER TABLE property_managers
  ADD COLUMN IF NOT EXISTS sector VARCHAR(30) DEFAULT 'operacional';

COMMENT ON COLUMN property_managers.sector IS 'agronomia, zootecnia, veterinaria, mecanica, operacional, financeiro';

-- 2. Adicionar sector em field_logs (herda do autor ou selecionado na hora)
ALTER TABLE field_logs
  ADD COLUMN IF NOT EXISTS sector VARCHAR(30);

COMMENT ON COLUMN field_logs.sector IS 'Setor da ocorrencia: agronomia, zootecnia, veterinaria, mecanica, operacional, financeiro';
