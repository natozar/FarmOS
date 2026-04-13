-- ============================================================
-- EPIC 9: Cron semanal — Sexta 18:00 UTC (15:00 BRT)
-- Dispara geração de relatório para cada propriedade ativa
-- Rodar no SQL Editor do Supabase
-- ============================================================

-- 1. Tabela de relatórios agendados
CREATE TABLE IF NOT EXISTS weekly_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL,
  owner_email TEXT NOT NULL,
  owner_nome TEXT,
  property_nome VARCHAR,
  report_url TEXT,
  sent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Função que gera os registros de relatório
CREATE OR REPLACE FUNCTION generate_weekly_reports()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_prop RECORD;
BEGIN
  FOR v_prop IN
    SELECT p.id, p.nome, p.owner_id,
           u.email, COALESCE(u.raw_user_meta_data->>'nome', split_part(u.email,'@',1)) as user_nome
    FROM properties p
    JOIN auth.users u ON u.id = p.owner_id
    WHERE p.active = true
  LOOP
    INSERT INTO weekly_reports (property_id, owner_id, owner_email, owner_nome, property_nome, report_url)
    VALUES (
      v_prop.id, v_prop.owner_id, v_prop.email, v_prop.user_nome, v_prop.nome,
      'https://agruai.com/report.html?id=' || v_prop.id
    );
    v_count := v_count + 1;
  END LOOP;

  -- Log no admin_alerts
  INSERT INTO admin_alerts (event_type, message, data)
  VALUES ('weekly_report', v_count || ' relatórios semanais gerados.',
    jsonb_build_object('count', v_count, 'generated_at', now()));

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Agendar no pg_cron: toda sexta às 18:00 UTC (15:00 BRT)
SELECT cron.schedule(
  'weekly-reports',
  '0 18 * * 5',
  $$ SELECT generate_weekly_reports(); $$
);

-- ============================================================
-- TEMPLATE DE EMAIL (para configurar no Resend/SMTP):
--
-- Assunto: 🌾 {owner_nome}, o relatório semanal da {property_nome} fechou
--
-- Corpo:
-- Senhor {owner_nome},
--
-- O relatório semanal da {property_nome} está pronto.
-- Clique no Link Mágico Seguro abaixo para puxar o PDF executivo:
--
-- 👉 {report_url}
--
-- Bom final de semana.
-- AgrUAI — Inteligência Rural por Satélite
-- ============================================================
