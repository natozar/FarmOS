-- ============================================================
-- SEED: Fazenda Santa Cruz (Demo para Zoom)
-- Colar INTEIRO no SQL Editor do Supabase e executar
-- ============================================================
-- ATENÇÃO: Este script usa o user_id do usuário de teste já criado.
-- Se necessário, altere o UUID abaixo para o ID correto.
-- ============================================================

DO $seed$
DECLARE
  v_user_id UUID := '01c5ac5d-c6de-4654-bae7-14b850e6370d'; -- fazendeiro.teste@agruai.com
  v_prop_id UUID;
  v_inv_diesel UUID;
  v_log_mec UUID;
BEGIN

-- ============================================================
-- 1. PROPRIEDADE: Fazenda Santa Cruz (12.000 ha, MT)
--    Polígono real na região de Sorriso/MT (Polo da Soja)
-- ============================================================
INSERT INTO properties (
  id, owner_id, nome, car_code, municipio, estado, source, crop_type, area_ha, active,
  geometry
) VALUES (
  gen_random_uuid(),
  v_user_id,
  'Fazenda Santa Cruz (Polo Soja e Gado)',
  'MT-5107925-A1B2C3D4E5F6G7H8',
  'Sorriso', 'MT', 'manual', 'soja_milho', 12000, true,
  ST_SetSRID(ST_GeomFromGeoJSON('{
    "type": "MultiPolygon",
    "coordinates": [[[
      [-55.78, -12.50],
      [-55.78, -12.38],
      [-55.62, -12.38],
      [-55.62, -12.50],
      [-55.78, -12.50]
    ]]]
  }'), 4326)
)
RETURNING id INTO v_prop_id;

RAISE NOTICE 'Propriedade criada: %', v_prop_id;

-- ============================================================
-- 2. SATELLITE_READINGS: 12 leituras (10 meses)
--    Mostra queda drástica recente para impactar na demo
-- ============================================================

-- Mês 1 (10 meses atrás) — Saudável
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '300 days', 0.82, 0.45, 0.32, 'healthy', 5, 'sentinel-2-l2a');

-- Mês 2 — Saudável
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '270 days', 0.79, 0.43, 0.30, 'healthy', 8, 'sentinel-2-l2a');

-- Mês 3 — Saudável
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '240 days', 0.81, 0.44, 0.31, 'healthy', 3, 'sentinel-2-l2a');

-- Mês 4 — Saudável
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '210 days', 0.77, 0.42, 0.29, 'healthy', 12, 'sentinel-2-l2a');

-- Mês 5 — Saudável (pico)
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '180 days', 0.85, 0.48, 0.34, 'healthy', 2, 'sentinel-2-l2a');

-- Mês 6 — Início da queda sutil
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '150 days', 0.74, 0.40, 0.27, 'healthy', 7, 'sentinel-2-l2a');

-- Mês 7 — Queda moderada
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '120 days', 0.68, 0.37, 0.24, 'healthy', 9, 'sentinel-2-l2a');

-- Mês 8 — Entrando em zona moderada
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '90 days', 0.58, 0.32, 0.20, 'moderate', 4, 'sentinel-2-l2a');

-- Mês 9 — Moderado caindo
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '60 days', 0.48, 0.26, 0.16, 'moderate', 6, 'sentinel-2-l2a');

-- Mês 10 — Estresse (queda acelerada)
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '30 days', 0.35, 0.19, 0.11, 'stressed', 3, 'sentinel-2-l2a');

-- 15 dias atrás — Estresse severo
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE - INTERVAL '15 days', 0.22, 0.12, 0.06, 'stressed', 2, 'sentinel-2-l2a');

-- HOJE — Crítico (a bomba na demo!)
INSERT INTO satellite_readings (property_id, reading_date, ndvi, evi, ndwi, classification, cloud_coverage, source)
VALUES (v_prop_id, CURRENT_DATE, 0.14, 0.07, 0.03, 'critical', 1, 'sentinel-2-l2a');

RAISE NOTICE 'Satellite readings: 12 inseridas (queda de 0.85 → 0.14)';

-- ============================================================
-- 3. ALERTAS: 3 alertas engatilhados
--    O primeiro é o grito vermelho da demo
-- ============================================================

-- Alerta 1: CRÍTICO — a estrela do show
INSERT INTO alerts (property_id, type, severity, message, estimated_risk, resolved, data)
VALUES (
  v_prop_id, 'ndvi_low', 'critical',
  'RISCO CRÍTICO: Queda na Soja Lote 3. NDVI despencou de 0.85 para 0.14 em 5 meses. Prejuízo projetado: - R$ 94.500,00. Ação imediata necessária.',
  94500, false,
  '{"ndvi": 0.14, "prev_ndvi": 0.85, "lote": "Lote 3 - Soja Safrinha", "area_afetada_ha": 126}'::jsonb
);

-- Alerta 2: Warning — pasto comprometido
INSERT INTO alerts (property_id, type, severity, message, estimated_risk, resolved, data)
VALUES (
  v_prop_id, 'ndvi_low', 'warning',
  'Pasto do Retiro Norte com biomassa em declínio. NDVI: 0.32. Lotação de 3.2 UA/ha pode estar acima da capacidade de suporte. Avaliar suplementação ou remanejamento.',
  28000, false,
  '{"ndvi": 0.32, "area_afetada_ha": 350, "ua_ha": 3.2}'::jsonb
);

-- Alerta 3: Warning — estresse hídrico
INSERT INTO alerts (property_id, type, severity, message, estimated_risk, resolved, data, created_at)
VALUES (
  v_prop_id, 'ndvi_low', 'warning',
  'Talhão Sul apresenta sinais de estresse hídrico. NDWI caiu 48% em 30 dias. Verificar irrigação e estado dos pivôs.',
  12800, false,
  '{"ndwi": 0.06, "prev_ndwi": 0.20, "area_afetada_ha": 180}'::jsonb,
  now() - INTERVAL '2 days'
);

RAISE NOTICE 'Alertas: 3 inseridos (R$94.500 + R$28.000 + R$12.800)';

-- ============================================================
-- 4. INVENTORY_ITEMS: Insumos no galpão
-- ============================================================

-- Diesel (vai ser abatido pelo mecânico)
INSERT INTO inventory_items (id, property_id, nome, quantidade, unidade, categoria, custo_unitario)
VALUES (gen_random_uuid(), v_prop_id, 'Óleo Diesel S-10', 8500, 'L', 'combustivel', 6.29)
RETURNING id INTO v_inv_diesel;

INSERT INTO inventory_items (property_id, nome, quantidade, unidade, categoria, custo_unitario)
VALUES (v_prop_id, 'Semente Soja NK 7059 RR', 420, 'sc', 'semente', 285.00);

INSERT INTO inventory_items (property_id, nome, quantidade, unidade, categoria, custo_unitario)
VALUES (v_prop_id, 'Roundup Original DI (Glifosato)', 340, 'L', 'defensivo', 32.50);

INSERT INTO inventory_items (property_id, nome, quantidade, unidade, categoria, custo_unitario)
VALUES (v_prop_id, 'MAP Fertilizante 10-50-00', 180, 'sc', 'fertilizante', 198.00);

INSERT INTO inventory_items (property_id, nome, quantidade, unidade, categoria, custo_unitario)
VALUES (v_prop_id, 'Sal Mineral Matsuda Fosbovi 20', 95, 'sc', 'racao', 142.00);

INSERT INTO inventory_items (property_id, nome, quantidade, unidade, categoria, custo_unitario)
VALUES (v_prop_id, 'Filtro de Óleo John Deere RE509672', 12, 'un', 'peca', 89.90);

RAISE NOTICE 'Inventário: 6 insumos cadastrados';

-- ============================================================
-- 5. FIELD_LOGS: 5 postagens de setores mistos
--    Simulando operação real no meio do mapa temporal
-- ============================================================

-- Log 1: Zootecnista — 45 dias atrás (alerta de pasto)
INSERT INTO field_logs (property_id, author_id, content, sector, created_at)
VALUES (
  v_prop_id, v_user_id,
  'Inspeção no Retiro Norte. Pasto apresentando sinais evidentes de estresse hídrico. Braquiária com altura média de 8cm quando deveria estar em 25cm. Recomendo reduzir lotação de 3.2 UA/ha para 2.0 UA/ha imediatamente e iniciar suplementação com volumoso.',
  'zootecnia',
  now() - INTERVAL '45 days'
);

-- Log 2: Agrônomo — 30 dias atrás (pulverização)
INSERT INTO field_logs (property_id, author_id, content, sector, created_at)
VALUES (
  v_prop_id, v_user_id,
  'Aplicação de Glifosato no Talhão 3 (Soja Safrinha). Identificamos foco de buva resistente na bordadura oeste. Dose aplicada: 3L/ha em 180 ha. Observar re-brotação em 15 dias. Se persistir, recomendar manejo com 2,4-D.',
  'agronomia',
  now() - INTERVAL '30 days'
);

-- Log 3: Mecânico — 20 dias atrás (colheitadeira + consumo de diesel)
INSERT INTO field_logs (id, property_id, author_id, content, sector, inventory_item_id, inventory_qty_used, created_at)
VALUES (
  gen_random_uuid(),
  v_prop_id, v_user_id,
  'Manutenção preventiva na John Deere S790. Troca de filtros, verificação do côncavo e ajuste do molinete. Consumo de diesel para deslocamento e teste: 320L. Colheitadeira liberada para operação. [Óleo Diesel S-10: 320 L]',
  'mecanica',
  v_inv_diesel, 320,
  now() - INTERVAL '20 days'
)
RETURNING id INTO v_log_mec;

-- Abater diesel do estoque (simula o que o front faria)
UPDATE inventory_items SET quantidade = quantidade - 320, updated_at = now()
WHERE id = v_inv_diesel;

-- Log 4: Operacional — 10 dias atrás (irrigação)
INSERT INTO field_logs (property_id, author_id, content, sector, created_at)
VALUES (
  v_prop_id, v_user_id,
  'Pivô central #2 do Talhão Sul parou às 14h. Motor da bomba desarmou por sobrecarga. Técnico da WEG acionado. Estimativa de reparo: 48h. Área de 180 ha ficará sem irrigação nesse período.',
  'operacional',
  now() - INTERVAL '10 days'
);

-- Log 5: Financeiro — 5 dias atrás (compra de insumo)
INSERT INTO field_logs (property_id, author_id, content, sector, created_at)
VALUES (
  v_prop_id, v_user_id,
  'Ordem de compra aprovada: 200 sacas adicionais de MAP 10-50-00 para cobertura de emergência no Talhão 3. Fornecedor: Agroceres. Valor total: R$ 39.600,00. Previsão de entrega: 3 dias úteis.',
  'financeiro',
  now() - INTERVAL '5 days'
);

RAISE NOTICE 'Field logs: 5 inseridos (zoo, agro, mec+diesel, oper, fin)';
RAISE NOTICE '=== SEED COMPLETO: Fazenda Santa Cruz pronta para demo! ===';

END $seed$;
