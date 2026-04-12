-- ============================================================
-- GODMODE SECURITY: Kill switch + alert trigger + recent users
-- Rodar no SQL Editor do Supabase
-- ============================================================

-- 1. Tabela de log de alertas admin (webhook queue)
CREATE TABLE IF NOT EXISTS admin_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  webhook_sent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Trigger: registra alerta quando nova propriedade é cadastrada
CREATE OR REPLACE FUNCTION notify_new_property()
RETURNS TRIGGER AS $$
DECLARE
  v_email TEXT;
  v_nome TEXT;
BEGIN
  SELECT email, COALESCE(raw_user_meta_data->>'nome', email)
  INTO v_email, v_nome
  FROM auth.users WHERE id = NEW.owner_id;

  INSERT INTO admin_alerts (event_type, message, data)
  VALUES (
    'new_property',
    '!! ALERTA: ' || v_nome || ' cadastrou "' || NEW.nome || '" (' || COALESCE(NEW.municipio,'') || '/' || COALESCE(NEW.estado,'') || '). Verifique GodMode !!',
    jsonb_build_object(
      'user_email', v_email,
      'user_nome', v_nome,
      'property_nome', NEW.nome,
      'municipio', NEW.municipio,
      'estado', NEW.estado,
      'area_ha', NEW.area_ha,
      'crop_type', NEW.crop_type
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notify_new_property ON properties;
CREATE TRIGGER trg_notify_new_property
  AFTER INSERT ON properties
  FOR EACH ROW EXECUTE FUNCTION notify_new_property();

-- 3. Trigger: registra alerta quando novo usuário se cadastra
CREATE OR REPLACE FUNCTION notify_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO admin_alerts (event_type, message, data)
  VALUES (
    'new_user',
    '!! ALERTA: Novo usuário cadastrado: ' || COALESCE(NEW.raw_user_meta_data->>'nome', NEW.email) || ' (' || NEW.email || '). Verifique GodMode !!',
    jsonb_build_object('email', NEW.email, 'nome', NEW.raw_user_meta_data->>'nome')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notify_new_user ON auth.users;
CREATE TRIGGER trg_notify_new_user
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION notify_new_user();

-- 4. RPC: Listar usuarios recentes (ultimos 7 dias)
CREATE OR REPLACE FUNCTION admin_recent_users()
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  nome TEXT,
  created_at TIMESTAMPTZ,
  property_count BIGINT
) AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE id = auth.uid()
    AND email IN ('chatsagrado@gmail.com','fazendeiro.teste@agruai.com')
  ) THEN RAISE EXCEPTION 'Acesso negado'; END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.email::TEXT,
    COALESCE(u.raw_user_meta_data->>'nome', split_part(u.email, '@', 1))::TEXT,
    u.created_at,
    (SELECT COUNT(*) FROM properties p WHERE p.owner_id = u.id AND p.active = true)
  FROM auth.users u
  WHERE u.created_at >= now() - INTERVAL '7 days'
  ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5. RPC: Admin alerts feed
CREATE OR REPLACE FUNCTION admin_alerts_feed(p_limit INT DEFAULT 20)
RETURNS TABLE (
  id UUID,
  event_type VARCHAR,
  message TEXT,
  data JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE id = auth.uid()
    AND email IN ('chatsagrado@gmail.com','fazendeiro.teste@agruai.com')
  ) THEN RAISE EXCEPTION 'Acesso negado'; END IF;

  RETURN QUERY
  SELECT a.id, a.event_type, a.message, a.data, a.created_at
  FROM admin_alerts a
  ORDER BY a.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 6. RPC: Kill switch (desativar propriedade)
CREATE OR REPLACE FUNCTION admin_kill_property(p_property_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users WHERE id = auth.uid()
    AND email IN ('chatsagrado@gmail.com','fazendeiro.teste@agruai.com')
  ) THEN RAISE EXCEPTION 'Acesso negado'; END IF;

  UPDATE properties SET active = false WHERE id = p_property_id;

  INSERT INTO admin_alerts (event_type, message, data)
  VALUES ('kill_switch', 'Propriedade desativada via Kill Switch pelo admin.', jsonb_build_object('property_id', p_property_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
