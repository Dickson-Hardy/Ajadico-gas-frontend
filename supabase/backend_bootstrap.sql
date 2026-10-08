-- ============================================================================
-- Ajadico Filling Station — backend bootstrap migration
--
-- Aligns the Supabase schema with what the Flutter app actually writes
-- (lib/core/network/supabase_repository.dart + offline queue dispatchers).
--
-- Safe to run more than once (idempotent). Run the whole file in the
-- Supabase SQL Editor (Dashboard > SQL Editor > New query > Run).
--
-- What it does:
--   1. Creates the 4 missing tables the offline queue writes to
--   2. Adds columns the app writes but the DB is missing (schema drift)
--   3. Aligns id/code column types with what the app sends
--      (app sends station CODES and 'SHIFT-...' text ids; DB had uuids)
--   4. Relaxes NOT NULL on write-path tables (app inserts partial rows)
--      and adds defaults for id/created_at so server-side generation works
--   5. Price-change trigger: directive rows (product/new_price) update the
--      live read model (product_id/price_per_litre/effective_from)
--   6. attendant_pin_login RPC (works with plaintext today, crypt() hashes
--      tomorrow) — the app calls it as p_station_id/p_profile_id/p_pin
--   7. Storage buckets remittance-evidence + delivery-waybills (public)
--   8. RLS policies + grants so the app's publishable (anon) key can write
-- ----------------------------------------------------------------------------

-- ============================================================================
-- SECTION 1 — Missing tables
-- ============================================================================

create table if not exists public.branch_expenses (
  id                text primary key,
  station_id        text,
  category          text,
  amount            numeric(14,2),
  payment_source    text,
  description       text,
  status            text default 'Pending Approval',
  recorded_by       text,
  approved_by       text,
  approved_at       timestamptz,
  receipt_url       text,
  notes             text,
  created_at        timestamptz default now()
);

create table if not exists public.fuel_returns (
  id                uuid primary key default gen_random_uuid(),
  tank_id           text,
  reason            text,
  litres            numeric(14,3),
  attendant_id      text,
  status            text default 'verified',
  created_at        timestamptz default now()
);

create table if not exists public.tank_deliveries (
  id                text primary key,
  tank_code         text,
  supplier          text,
  waybill_number    text,
  stated_litres     numeric(14,2),
  dip_before        numeric(14,2),
  dip_after         numeric(14,2),
  received_litres   numeric(14,2),
  discrepancy       numeric(14,2),
  purchase_price    numeric(14,2),
  created_at        timestamptz default now()
);

create table if not exists public.app_notifications (
  id            text primary key,
  title         text,
  message       text,
  type          text,
  target_role   text,
  action_route  text,
  is_read       boolean default false,
  created_at    timestamptz default now()
);

create table if not exists public.attendant_shortages (
  id                        text primary key,
  attendant_id              text,
  attendant_name            text,
  station_name              text,
  month_year                text,
  base_salary               numeric(14,2),
  total_shortages_deducted  numeric(14,2),
  total_excesses_credited   numeric(14,2),
  net_payable               numeric(14,2),
  carried_deficit           numeric(14,2),
  shortfall_shift_count     integer,
  settled_by                text,
  settled_at                timestamptz,
  status                    text default 'Pending Review',
  created_at                timestamptz default now()
);

-- ============================================================================
-- SECTION 2 — Schema drift: columns the app writes that don't exist yet
-- ============================================================================

alter table public.bank_deposits      add column if not exists is_confirmed boolean default false;
alter table public.credit_sales       add column if not exists vehicle_reg text;
alter table public.credit_sales       add column if not exists total_amount numeric(14,2);
alter table public.credit_sales       add column if not exists recorded_at timestamptz default now();
alter table public.remittance_evidence add column if not exists created_at timestamptz default now();
alter table public.tank_dips          add column if not exists physical_dip_litres numeric(14,3);
alter table public.tank_dips          add column if not exists dip_stick_cm numeric(8,2);
alter table public.tank_dips          add column if not exists book_stock_litres numeric(14,3);
alter table public.tank_dips          add column if not exists variance_litres numeric(14,3);
alter table public.fuel_prices        add column if not exists product text;
alter table public.fuel_prices        add column if not exists new_price numeric(14,2);
alter table public.fuel_prices        add column if not exists reason text;
alter table public.fuel_prices        add column if not exists meter_snapshots jsonb;
alter table public.fuel_prices        add column if not exists authorized_at timestamptz;
alter table public.expenses           add column if not exists status text default 'Pending Approval';
alter table public.expenses           add column if not exists approved_at timestamptz;
alter table public.expenses           add column if not exists notes text;

-- Evidence photos linked to their source record (credit sale / fuel return)
alter table public.remittance_evidence add column if not exists credit_sale_id uuid;
alter table public.remittance_evidence add column if not exists fuel_return_id uuid;

-- Credit sale audit columns the app sends
alter table public.credit_sales       add column if not exists nozzle_number integer;

-- Credit ledger: real "last repayment" instead of a hardcoded label
alter table public.credit_customers   add column if not exists last_payment_at timestamptz;

-- Salary ledger: columns the SalaryAdjustment model reads back
alter table public.attendant_salary_adjustments add column if not exists attendant_name text;
alter table public.attendant_salary_adjustments add column if not exists station text;
alter table public.attendant_salary_adjustments add column if not exists shift_ref text;
alter table public.attendant_salary_adjustments add column if not exists recorded_at timestamptz;

-- Status columns were declared as enums whose values don't match what the
-- app writes ('Pending Review', 'Salary Deduction Approved', ...). Convert
-- them to plain text so app statuses are never rejected by Postgres.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'remittances'
                and column_name = 'status' and data_type = 'USER-DEFINED') then
    execute 'alter table public.remittances alter column status type text using status::text';
  end if;

  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'attendant_salary_adjustments'
                and column_name = 'status' and data_type = 'USER-DEFINED') then
    execute 'alter table public.attendant_salary_adjustments alter column status type text using status::text';
  end if;

  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'shifts'
                and column_name = 'status' and data_type = 'USER-DEFINED') then
    execute 'alter table public.shifts alter column status type text using status::text';
  end if;
end $$;

-- ============================================================================
-- SECTION 3 — Column type alignment (uuid FKs -> types the app sends)
--
-- The app sends station CODES ('LEKKI-01') and synthetic text shift ids
-- ('SHIFT-<timestamp>'). Drop the FKs that assume uuid, then retype.
-- None of these columns are embedded in any app read query (verified:
-- reads join profiles/stations/tanks only where the FK is kept).
-- ============================================================================

-- Helper: drop every FK on (table, column) if present
create or replace function public.app_drop_fk(p_table text, p_column text)
returns void language plpgsql as $$
declare c record;
begin
  for c in
    select con.conname
      from pg_constraint con
      join unnest(con.conkey) with ordinality as k(attnum, ord) on true
      join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
     where con.contype = 'f'
       and to_regclass('public.' || quote_ident(p_table)) is not null
       and con.conrelid = to_regclass('public.' || quote_ident(p_table))
       and a.attname = p_column
  loop
    execute format('alter table public.%I drop constraint %I', p_table, c.conname);
  end loop;
end $$;

-- Helper: retype a column to text whatever its current type (uuid/int need
-- an explicit USING cast, which plain `alter column ... type text` lacks).
create or replace function public.app_retype_text(p_table text, p_column text)
returns void language plpgsql as $$
declare v_type text;
begin
  if to_regclass('public.' || quote_ident(p_table)) is null then
    return;
  end if;
  select data_type into v_type
    from information_schema.columns
   where table_schema = 'public' and table_name = p_table and column_name = p_column;
  if v_type is null or v_type = 'text' then
    return;
  end if;
  execute format(
    'alter table public.%I alter column %I type text using %I::text',
    p_table, p_column, p_column);
end $$;

-- Helper: retype to integer, tolerating uuid/text payloads by parsing digits
-- (shift_nozzle_assignments.nozzle_id is uuid; the app sends the int number).
create or replace function public.app_retype_int(p_table text, p_column text)
returns void language plpgsql as $$
declare v_type text;
begin
  if to_regclass('public.' || quote_ident(p_table)) is null then
    return;
  end if;
  select data_type into v_type
    from information_schema.columns
   where table_schema = 'public' and table_name = p_table and column_name = p_column;
  if v_type is null or v_type = 'integer' then
    return;
  end if;
  execute format(
    'alter table public.%I alter column %I type integer using (case when %I::text ~ ''^[0-9]+$'' then %I::text::integer else null end)',
    p_table, p_column, p_column, p_column);
end $$;

select public.app_drop_fk('remittances', 'shift_id');
select public.app_drop_fk('shift_nozzle_assignments', 'shift_id');
select public.app_drop_fk('shift_nozzle_assignments', 'nozzle_id');
select public.app_drop_fk('interim_cash_drops', 'station_id');
select public.app_drop_fk('shift_pos_transactions', 'station_id');
select public.app_drop_fk('tank_dips', 'tank_id');
select public.app_drop_fk('shifts', 'station_id');

select public.app_retype_text('remittances', 'shift_id');
select public.app_retype_text('shift_nozzle_assignments', 'shift_id');
select public.app_retype_int('shift_nozzle_assignments', 'nozzle_id');
select public.app_retype_text('interim_cash_drops', 'shift_id');
select public.app_retype_text('interim_cash_drops', 'station_id');
select public.app_retype_text('shift_pos_transactions', 'shift_id');
select public.app_retype_text('shift_pos_transactions', 'station_id');
select public.app_retype_text('tank_dips', 'tank_id');
select public.app_retype_text('shifts', 'station_id');

-- Kept as uuid (the app resolves code->uuid before inserting):
--   bank_deposits.station_id, tank_changeovers.station_id,
--   daily_cash_counts.station_id (recordDailyCashAuditPayload resolves),
--   *.attendant_id / cashier_id / customer_id / remittance_id (uuids)

-- Closing-readings upsert business key: one assignment per shift+nozzle.
-- (PostgREST defaults upsert to the uuid PK, which these payloads omit —
-- the Dart side passes on_conflict=shift_id,nozzle_id to hit this index.)
create unique index if not exists shift_nozzle_assignments_shift_nozzle_key
  on public.shift_nozzle_assignments (shift_id, nozzle_id);

-- ============================================================================
-- SECTION 4 — Relax NOT NULL on write-path tables (partial app inserts),
-- give id columns a server default, and default created_at/updated_at.
-- Primary keys are left NOT NULL.
-- ============================================================================

do $$
declare
  t  text;
  c  record;
  pk text[];
begin
  foreach t in array array[
    'remittances','remittance_evidence','shift_nozzle_assignments',
    'interim_cash_drops','shift_pos_transactions','daily_cash_counts',
    'bank_deposits','credit_sales','tank_dips','tank_changeovers',
    'fuel_prices','expenses',
    'branch_expenses','fuel_returns','tank_deliveries','attendant_shortages',
    'attendant_salary_adjustments','shifts',
    'tanks','nozzles','credit_customers'
  ] loop
    if to_regclass('public.' || quote_ident(t)) is null then
      continue;
    end if;

    -- primary key columns (stay NOT NULL)
    select coalesce(array_agg(a.attname), '{}') into pk
      from pg_constraint con
      join unnest(con.conkey) with ordinality as k(attnum, ord) on true
      join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
     where con.contype = 'p'
       and con.conrelid = to_regclass('public.' || quote_ident(t));

    -- drop NOT NULL on every non-PK column
    for c in
      select column_name
        from information_schema.columns
       where table_schema = 'public'
         and table_name = t
         and is_nullable = 'NO'
         and not (column_name = any (pk))
    loop
      execute format('alter table public.%I alter column %I drop not null', t, c.column_name);
    end loop;

    -- uuid id without default -> server-generated
    for c in
      select column_name, column_default
        from information_schema.columns
       where table_schema = 'public'
         and table_name = t
         and column_name = 'id'
         and data_type = 'uuid'
         and column_default is null
    loop
      execute format('alter table public.%I alter column %I set default gen_random_uuid()', t, c.column_name);
    end loop;

    -- created_at / updated_at without default -> now()
    for c in
      select column_name
        from information_schema.columns
       where table_schema = 'public'
         and table_name = t
         and column_name in ('created_at','updated_at')
         and data_type = 'timestamp with time zone'
    loop
      execute format('alter table public.%I alter column %I set default now()', t, c.column_name);
    end loop;
  end loop;
end $$;

-- ============================================================================
-- SECTION 5 — Price-change directive trigger
--
-- The app inserts fuel_prices rows with (product, new_price, reason,
-- meter_snapshots, authorized_at) while reads use
-- (product_id, price_per_litre, effective_from). This BEFORE INSERT
-- trigger fills the read model from the directive so a Director price
-- change actually shows up everywhere.
-- ============================================================================

create or replace function public.app_price_directive_fill()
returns trigger language plpgsql as $$
declare v_id uuid;
begin
  if new.product is not null and new.price_per_litre is null then
    select id into v_id
      from public.fuel_products
     where upper(code) = upper(new.product)
     limit 1;
    if v_id is not null then
      new.product_id      := v_id;
      new.price_per_litre := new.new_price;
      new.effective_from  := coalesce(new.authorized_at, now());
    end if;
  end if;
  return new;
end $$;

drop trigger if exists app_price_directive_fill on public.fuel_prices;
create trigger app_price_directive_fill
  before insert on public.fuel_prices
  for each row execute function public.app_price_directive_fill();

-- ============================================================================
-- SECTION 6 — attendant_pin_login RPC (the app's staff login path)
--
-- App call: client.rpc('attendant_pin_login',
--            params: {p_station_id, p_profile_id, p_pin})
-- Returns:  {"success": true, "user": {...}} | {"success": false, "message": ...}
-- Accepts today's plaintext pin_hash values and crypt() hashes ($...$...) too.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

create or replace function public.attendant_pin_login(
  p_station_id uuid,
  p_profile_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  prof  public.profiles%rowtype;
  v_ok  boolean := false;
begin
  select * into prof
    from public.profiles
   where id = p_profile_id
     and is_active
     and (station_id = p_station_id or station_id is null);

  if found and prof.pin_hash is not null and p_pin is not null then
    if prof.pin_hash ~ '^\$[^$]+\$' then
      v_ok := (crypt(p_pin, prof.pin_hash) = prof.pin_hash);
    else
      v_ok := (prof.pin_hash = p_pin);
    end if;
  end if;

  if not v_ok then
    return jsonb_build_object('success', false, 'message', 'Invalid PIN');
  end if;

  return jsonb_build_object('success', true, 'user', to_jsonb(prof));
end $$;

revoke all on function public.attendant_pin_login(uuid, uuid, text) from public;
grant execute on function public.attendant_pin_login(uuid, uuid, text) to anon, authenticated;

-- ============================================================================
-- SECTION 6b — app_add_credit_outstanding (credit sales + repayments)
--
-- Single atomic read-modify-write for the credit ledger balance so every
-- device agrees on a customer's outstanding. Negative p_delta = repayment
-- (floors at zero and stamps last_payment_at).
-- ============================================================================

create or replace function public.app_add_credit_outstanding(
  p_customer_id uuid,
  p_delta numeric
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  update public.credit_customers
     set outstanding_balance = greatest(coalesce(outstanding_balance, 0) + p_delta, 0),
         last_payment_at = case when p_delta < 0 then now() else last_payment_at end
   where id = p_customer_id;
end $$;

revoke all on function public.app_add_credit_outstanding(uuid, numeric) from public;
grant execute on function public.app_add_credit_outstanding(uuid, numeric) to anon, authenticated;

-- ============================================================================
-- SECTION 7 — Storage buckets for evidence photos & waybills
-- (app: SupabaseConfig.evidenceBucket / waybillBucket, getPublicUrl reads)
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('remittance-evidence', 'remittance-evidence', true),
       ('delivery-waybills',   'delivery-waybills',   true)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'ajadico evidence public read'
  ) then
    create policy "ajadico evidence public read"
      on storage.objects for select to public
      using (bucket_id in ('remittance-evidence', 'delivery-waybills'));
  end if;

  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname = 'ajadico evidence write'
  ) then
    create policy "ajadico evidence write"
      on storage.objects for all to anon, authenticated
      using (bucket_id in ('remittance-evidence', 'delivery-waybills'))
      with check (bucket_id in ('remittance-evidence', 'delivery-waybills'));
  end if;
end $$;

-- ============================================================================
-- SECTION 8 — RLS + grants for every table the app touches
--
-- The app authenticates with the publishable (anon) key only, so policies
-- must allow anon. This matches the 8 tables that already work. Note the
-- honest trade-off: the publishable key ships in the APK, so this protects
-- against schema accidents, not against a determined attacker. Server-
-- provisioned auth is the hardening step later.
-- ============================================================================

grant usage on schema public to anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'stations','profiles','shifts','shift_nozzle_assignments','remittances',
    'remittance_evidence','interim_cash_drops','shift_pos_transactions',
    'daily_cash_counts','bank_deposits','credit_customers','fuel_prices',
    'fuel_products','tanks','nozzles','tank_changeovers','expenses',
    'attendant_salary_adjustments','credit_sales','tank_dips',
    'branch_expenses','fuel_returns','tank_deliveries','attendant_shortages',
    'app_notifications'
  ] loop
    if to_regclass('public.' || quote_ident(t)) is null then
      continue;
    end if;

    execute format('alter table public.%I enable row level security', t);

    if not exists (
      select 1 from pg_policies
       where schemaname = 'public' and tablename = t
         and policyname = 'ajadico full access'
    ) then
      execute format(
        'create policy "ajadico full access" on public.%I for all to anon, authenticated using (true) with check (true)',
        t
      );
    end if;

    execute format('grant select, insert, update, delete on public.%I to anon, authenticated', t);
  end loop;
end $$;

-- ============================================================================
-- SECTION 9 — OPTIONAL: reset demo staff PINs (review before running!)
--
-- The 4 seeded profiles (Amaka/Bello/Chidi/Dickson) currently have
-- pin_hash = '1234' in plaintext. After this migration the recommended
-- path is: log in as Director (override PIN), open Staff Management, and
-- reset each PIN there. To force all staff PINs invalid in one shot,
-- uncomment the line below — every login then fails until PINs are
-- re-provisioned:
--
-- update public.profiles set pin_hash = 'REPROVISION-REQUIRED' where pin_hash = '1234';
-- ============================================================================
