-- Staging prerequisite for the current runtime's tank_deliveries payload.
-- Existing rows are retained; historical station ownership needs manual review.
begin;
alter table if exists public.tank_deliveries
  add column if not exists waybill_references jsonb not null default '[]'::jsonb,
  add column if not exists station_id uuid references public.stations(id);
commit;
