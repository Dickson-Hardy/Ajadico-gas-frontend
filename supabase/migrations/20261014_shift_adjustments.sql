-- Applied to gasstation main production on 2026-10-14; see deployment record.
-- Requires verified Supabase Auth users mapped
-- to profiles.id, the operational_policy migration and compatible shift tables.
-- Legacy anonymous/PIN-only sessions deliberately cannot submit or approve.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create table if not exists public.shift_adjustments (
  id uuid primary key,
  shift_id uuid not null references public.shifts(id),
  station_code varchar(20) not null references public.stations(code),
  attendant_id uuid not null references public.profiles(id),
  attendant_name text not null,
  kind text not null check (kind in ('expense','calibrationReturn','generatorFuel','companyVehicle')),
  category text not null default '',
  reason text not null check (length(btrim(reason)) between 1 and 2000),
  amount numeric(14,2) not null check (amount > 0),
  litres numeric(14,3) not null default 0 check (litres >= 0),
  price_per_litre numeric(12,2) not null default 0 check (price_per_litre >= 0),
  nozzle_number integer,
  tank_code text,
  evidence jsonb not null check (jsonb_typeof(evidence) = 'array' and jsonb_array_length(evidence) between 1 and 4),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by text,
  reviewer_id uuid references public.profiles(id),
  review_notes text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  check ((kind = 'expense' and litres = 0 and price_per_litre = 0) or
    (kind <> 'expense' and litres > 0 and price_per_litre > 0 and nozzle_number is not null
     and tank_code is not null and amount = round(litres * price_per_litre, 2)))
);
create index if not exists shift_adjustments_shift_idx on public.shift_adjustments(shift_id, attendant_id);
create index if not exists shift_adjustments_attendant_idx on public.shift_adjustments(attendant_id);
create index if not exists shift_adjustments_reviewer_idx on public.shift_adjustments(reviewer_id);
create index if not exists shift_adjustments_review_idx on public.shift_adjustments(station_code, status, created_at);

create or replace function public.can_read_shift_adjustment(p_station text, p_attendant uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    left join public.stations s on s.id::text = p.station_id::text
    where p.id = (select auth.uid()) and p.is_active
      and (p.role::text = 'director' or
        (s.code = p_station and (p.id = p_attendant or p.role::text in ('cashier','manager'))))
  );
$$;
revoke all on function public.can_read_shift_adjustment(text,uuid) from public, anon;
grant execute on function public.can_read_shift_adjustment(text,uuid) to authenticated;
alter table public.shift_adjustments enable row level security;
revoke all on public.shift_adjustments from public, anon, authenticated;
grant select on public.shift_adjustments to authenticated;
drop policy if exists shift_adjustments_read on public.shift_adjustments;
create policy shift_adjustments_read on public.shift_adjustments for select to authenticated
using (public.can_read_shift_adjustment(station_code, attendant_id));

create or replace function public.submit_shift_adjustment(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor public.profiles; st public.stations; entry public.shift_adjustments;
  shift_ref uuid := (p_entry->>'shift_id')::uuid;
begin
  select * into actor from public.profiles where id = (select auth.uid()) and is_active;
  if actor.id is null or actor.role::text <> 'attendant' then raise exception 'Authenticated attendant required'; end if;
  select * into st from public.stations where id::text = actor.station_id::text and is_active;
  if st.code is distinct from p_entry->>'station_code' or actor.id::text is distinct from p_entry->>'attendant_id'
    then raise exception 'Shift owner/station mismatch'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(shift_ref::text,0));
  if not exists (select 1 from public.shifts s where s.id = shift_ref
    and coalesce(to_jsonb(s)->>'attendant_id',to_jsonb(s)->>'opened_by') = actor.id::text
    and (s.station_id::text = st.id::text or s.station_id::text = st.code))
    then raise exception 'Shift does not belong to attendant'; end if;
  -- A retry may recover its own already-recorded entry, never overwrite review.
  select * into entry from public.shift_adjustments where id = (p_entry->>'id')::uuid;
  if found then
    if entry.attendant_id <> actor.id or entry.shift_id <> shift_ref then raise exception 'Entry conflict'; end if;
    return to_jsonb(entry);
  end if;
  if exists (select 1 from public.remittances where shift_id::text = shift_ref::text)
    then raise exception 'Shift already submitted'; end if;
  if p_entry->>'kind' = 'expense' and not exists (
    select 1 from public.operational_policy where id='company' and (p_entry->>'category') = any(expense_categories))
    then raise exception 'Unconfigured expense category'; end if;
  if p_entry->>'kind' <> 'expense' and not exists (
    select 1 from public.tanks t join public.fuel_products f on f.id = t.product_id
    where t.code = p_entry->>'tank_code' and (t.station_id::text = st.id::text or t.station_id::text = st.code)
      and (p_entry->>'kind' <> 'generatorFuel' or f.code = 'AGO'))
    then raise exception 'Invalid tank/product'; end if;
  if exists (select 1 from jsonb_array_elements_text(p_entry->'evidence') as proof(reference)
    where proof.reference !~ '^(storage|queued-offline)://(expense-receipts|calibration-evidence)/[^[:space:]]+$'
      or proof.reference ~ '(^|/)\.\.?(/|$)' or proof.reference ~* '%(2e|2f|5c|00)')
    then raise exception 'Durable evidence references required'; end if;
  insert into public.shift_adjustments(id,shift_id,station_code,attendant_id,attendant_name,
    kind,category,reason,amount,litres,price_per_litre,nozzle_number,tank_code,evidence)
  values ((p_entry->>'id')::uuid,shift_ref,st.code,actor.id,actor.display_name,
    p_entry->>'kind',coalesce(p_entry->>'category',''),p_entry->>'reason',(p_entry->>'amount')::numeric,
    coalesce((p_entry->>'litres')::numeric,0),coalesce((p_entry->>'price_per_litre')::numeric,0),
    (p_entry->>'nozzle_number')::integer,p_entry->>'tank_code',p_entry->'evidence') returning * into entry;
  return to_jsonb(entry);
end;
$$;

create or replace function public.review_shift_adjustment(p_id uuid,p_approved boolean,p_notes text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor public.profiles; entry public.shift_adjustments; rules public.operational_policy;
begin
  select * into actor from public.profiles where id=(select auth.uid()) and is_active;
  if actor.id is null or actor.role::text not in ('cashier','manager','director') or
    p_approved is null or length(btrim(coalesce(p_notes,''))) not between 1 and 2000
    then raise exception 'Authorized reviewer and notes required'; end if;
  select * into entry from public.shift_adjustments where id=p_id for update;
  if entry.id is null or entry.status <> 'pending' or entry.attendant_id=actor.id or
    not public.can_read_shift_adjustment(entry.station_code,entry.attendant_id)
    then raise exception 'Entry not reviewable'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(entry.shift_id::text,0));
  if exists (select 1 from public.remittances where shift_id::text=entry.shift_id::text)
    then raise exception 'Shift already submitted'; end if;
  select * into rules from public.operational_policy where id='company';
  if rules.id is null or (actor.role::text='cashier' and entry.amount>rules.cashier_approval_limit)
    or (actor.role::text='manager' and entry.amount>rules.manager_approval_limit)
    then raise exception 'Approval authority exceeded'; end if;
  if p_approved and entry.kind='calibrationReturn' then
    update public.tanks t set calculated_stock_litres=coalesce(t.calculated_stock_litres,0)+entry.litres
    from public.stations s where s.code=entry.station_code and t.code=entry.tank_code
      and (t.station_id::text=s.id::text or t.station_id::text=s.code);
    if not found then raise exception 'Tank not found'; end if;
    -- Do not change current_dip_litres: that is a physical measurement.
  end if;
  update public.shift_adjustments set status=case when p_approved then 'approved' else 'rejected' end,
    reviewer_id=actor.id, reviewed_by=actor.display_name, review_notes=btrim(p_notes),reviewed_at=now()
    where id=p_id returning * into entry;
  return to_jsonb(entry);
end;
$$;
revoke all on function public.submit_shift_adjustment(jsonb) from public, anon;
revoke all on function public.review_shift_adjustment(uuid,boolean,text) from public, anon;
grant execute on function public.submit_shift_adjustment(jsonb) to authenticated;
grant execute on function public.review_shift_adjustment(uuid,boolean,text) to authenticated;

alter table public.remittances add column if not exists approved_pump_expenses numeric(14,2) not null default 0;
alter table public.remittances add column if not exists approved_non_sale_fuel numeric(14,2) not null default 0;
alter table public.remittances add column if not exists metered_stock jsonb not null default '[]'::jsonb;
-- Verified production server is PostgreSQL 17. Preserve the generated column
-- and its dependencies while making SQL variance match the app calculation.
-- Historical rows retain the same result because the new expense default is 0.
alter table public.remittances alter column variance set expression as (
  cash_declared + pos_card_declared + pos_transfer_declared +
  bank_transfer_declared + credit_sales_declared + approved_pump_expenses - expected_sales_value
);
-- Snapshot validation also serializes submission against entry creation/review.
create or replace function public.validate_shift_adjustment_snapshot()
returns trigger language plpgsql security definer set search_path = '' as $$
declare expenses numeric; fuel numeric;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.shift_id::text,0));
  if exists (select 1 from public.shift_adjustments where shift_id::text=new.shift_id::text and status='pending')
    then raise exception 'Pending shift adjustments'; end if;
  select coalesce(sum(amount) filter(where kind='expense'),0),
    coalesce(sum(amount) filter(where kind<>'expense'),0) into expenses,fuel
    from public.shift_adjustments where shift_id::text=new.shift_id::text and status='approved';
  if new.approved_pump_expenses<>expenses or new.approved_non_sale_fuel<>fuel
    then raise exception 'Shift adjustment snapshot mismatch'; end if;
  return new;
end;
$$;
revoke all on function public.validate_shift_adjustment_snapshot() from public,anon,authenticated;
drop trigger if exists remittance_adjustment_snapshot on public.remittances;
create trigger remittance_adjustment_snapshot before insert on public.remittances
  for each row execute function public.validate_shift_adjustment_snapshot();
-- Atomic book-stock deltas preserve approved calibration restorations. Actual
-- physical dip is untouched. Retries of the same remittance do not fire twice.
create or replace function public.apply_shift_metered_stock()
returns trigger language plpgsql security definer set search_path = '' as $$
declare line jsonb; station_ref text; volume numeric;
begin
  select station_id::text into station_ref from public.shifts where id::text=new.shift_id::text;
  if jsonb_typeof(new.metered_stock)<>'array' then raise exception 'Invalid meter snapshot'; end if;
  for line in select value from jsonb_array_elements(new.metered_stock) loop
    volume := (line->>'litres')::numeric;
    if volume is null or volume<0 or volume>100000000 then raise exception 'Invalid metered volume'; end if;
    update public.tanks t set calculated_stock_litres=coalesce(t.calculated_stock_litres,0)-volume
      from public.stations s where (s.id::text=station_ref or s.code=station_ref)
      and t.code=line->>'tank_code' and (t.station_id::text=s.id::text or t.station_id::text=s.code);
    if not found then raise exception 'Meter snapshot tank not found'; end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.apply_shift_metered_stock() from public,anon,authenticated;
drop trigger if exists remittance_metered_stock on public.remittances;
create trigger remittance_metered_stock after insert on public.remittances
  for each row execute function public.apply_shift_metered_stock();
commit;
