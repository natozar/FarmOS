-- ============================================================
-- FIX: RLS para weekly_reports — Patch de Segurança
-- Rodar no SQL Editor do Supabase
-- ============================================================

ALTER TABLE weekly_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_reports FORCE ROW LEVEL SECURITY;

-- Dono só vê seus próprios relatórios
CREATE POLICY "wr_select" ON weekly_reports
  FOR SELECT USING (owner_id = auth.uid());

-- Apenas o sistema insere (via SECURITY DEFINER)
CREATE POLICY "wr_insert" ON weekly_reports
  FOR INSERT WITH CHECK (false);
