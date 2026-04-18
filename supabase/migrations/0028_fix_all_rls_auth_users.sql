-- 0028: purga definitiva do bug (SELECT FROM auth.users) nas RLS
-- ============================================================
-- Varredura achou 6 policies adicionais alem das corrigidas em 0026/0027:
--   satellite_readings.sr_select
--   alerts.alert_select
--   inventory_items.inv_select
--   inventory_items.inv_update
--   inventory_items.manager_read_inventory
--   inventory_items.manager_update_inventory
-- Todas impediam o gestor por email de ver NDVI, alertas e estoque
-- da propriedade gerenciada. Fix uniforme: auth.jwt()->>'email'.

DROP POLICY IF EXISTS sr_select ON public.satellite_readings;
CREATE POLICY sr_select ON public.satellite_readings FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = satellite_readings.property_id
      AND (
        p.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.property_managers pm
          WHERE pm.property_id = p.id
            AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (auth.jwt() ->> 'email'))
        )
      )
  )
);

DROP POLICY IF EXISTS alert_select ON public.alerts;
CREATE POLICY alert_select ON public.alerts FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = alerts.property_id
      AND (
        p.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.property_managers pm
          WHERE pm.property_id = p.id
            AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (auth.jwt() ->> 'email'))
        )
      )
  )
);

DROP POLICY IF EXISTS inv_select ON public.inventory_items;
CREATE POLICY inv_select ON public.inventory_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = inventory_items.property_id
      AND (
        p.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.property_managers pm
          WHERE pm.property_id = p.id
            AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (auth.jwt() ->> 'email'))
        )
      )
  )
);

DROP POLICY IF EXISTS inv_update ON public.inventory_items;
CREATE POLICY inv_update ON public.inventory_items FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.properties p
    WHERE p.id = inventory_items.property_id
      AND (
        p.owner_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.property_managers pm
          WHERE pm.property_id = p.id
            AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (auth.jwt() ->> 'email'))
        )
      )
  )
);

DROP POLICY IF EXISTS manager_read_inventory ON public.inventory_items;
CREATE POLICY manager_read_inventory ON public.inventory_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.property_managers pm
    WHERE pm.property_id = inventory_items.property_id
      AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (auth.jwt() ->> 'email'))
  )
);

DROP POLICY IF EXISTS manager_update_inventory ON public.inventory_items;
CREATE POLICY manager_update_inventory ON public.inventory_items FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.property_managers pm
    WHERE pm.property_id = inventory_items.property_id
      AND (pm.manager_user_id = auth.uid() OR pm.manager_email = (auth.jwt() ->> 'email'))
  )
);
