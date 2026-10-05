-- =============================================================================
-- AJADICO FILLING STATION MANAGEMENT SYSTEM
-- Database Webhook Triggers for Push Notifications (BRD v3 §5.5)
-- Wires PostgreSQL table events to the push-notifications Supabase Edge Function
-- =============================================================================

-- Enable pg_net extension for asynchronous outbound HTTP requests
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- Generic trigger function to forward events to the Edge Function
CREATE OR REPLACE FUNCTION public.dispatch_push_notification_webhook()
RETURNS TRIGGER AS $$
DECLARE
  v_payload JSONB;
  v_edge_function_url TEXT := 'https://haeakygzrnrjwphmhlkp.supabase.co/functions/v1/push-notifications';
  v_anon_key TEXT := 'sb_publishable_SmQ1nwW78Hh6Gi3RtK956w_E-QNmFMl';
BEGIN
  v_payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END,
    'old_record', CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD) ELSE NULL END
  );

  -- Perform non-blocking async HTTP POST via pg_net
  PERFORM net.http_post(
    url := v_edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', v_anon_key,
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body := v_payload
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block the business transaction if webhook dispatch encounters a network failure
  RAISE WARNING 'Push notification webhook failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. Trigger for New Remittances (§4.5)
DROP TRIGGER IF EXISTS trg_notify_remittance ON public.remittances;
CREATE TRIGGER trg_notify_remittance
AFTER INSERT ON public.remittances
FOR EACH ROW EXECUTE FUNCTION public.dispatch_push_notification_webhook();

-- 2. Trigger for Shift Status Changes & Shortages (§4.6)
DROP TRIGGER IF EXISTS trg_notify_shift_status ON public.shifts;
CREATE TRIGGER trg_notify_shift_status
AFTER UPDATE ON public.shifts
FOR EACH ROW
WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION public.dispatch_push_notification_webhook();

-- 3. Trigger for Price Change Directives (§2.8)
DROP TRIGGER IF EXISTS trg_notify_price_change ON public.fuel_prices;
CREATE TRIGGER trg_notify_price_change
AFTER INSERT ON public.fuel_prices
FOR EACH ROW EXECUTE FUNCTION public.dispatch_push_notification_webhook();

-- 4. Trigger for Fuel Delivery Tanker Discharges (§3.1)
DROP TRIGGER IF EXISTS trg_notify_fuel_delivery ON public.fuel_deliveries;
CREATE TRIGGER trg_notify_fuel_delivery
AFTER INSERT ON public.fuel_deliveries
FOR EACH ROW EXECUTE FUNCTION public.dispatch_push_notification_webhook();

-- 5. Trigger for Tank Physical Dip Deficits (§3.2, §3.3)
DROP TRIGGER IF EXISTS trg_notify_tank_dip ON public.tank_dips;
CREATE TRIGGER trg_notify_tank_dip
AFTER INSERT ON public.tank_dips
FOR EACH ROW EXECUTE FUNCTION public.dispatch_push_notification_webhook();

-- 6. Trigger for Salary Adjustments Approval / Decisions (§4.6)
DROP TRIGGER IF EXISTS trg_notify_salary_adjustment ON public.attendant_salary_adjustments;
CREATE TRIGGER trg_notify_salary_adjustment
AFTER UPDATE ON public.attendant_salary_adjustments
FOR EACH ROW EXECUTE FUNCTION public.dispatch_push_notification_webhook();
