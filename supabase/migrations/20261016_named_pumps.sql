-- PREPARED ONLY. Requires 20261015_company_onboarding and explicit deployment review.
-- Existing equipment UUIDs, numeric keys, readings and sales remain unchanged.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
alter table public.nozzles add column if not exists station_id uuid references public.stations(id);
alter table public.nozzles add column if not exists display_name text;
update public.nozzles n set station_id=p.station_id from public.pumps p
where p.id=n.pump_id and n.station_id is null;
-- Abort on ambiguous legacy numbers instead of renumbering historical identities.
do $$ begin
  if exists(select 1 from public.nozzles where station_id is null) or
     exists(select 1 from public.nozzles group by station_id,nozzle_number having count(*)>1)
    then raise exception 'Resolve missing stations or duplicate legacy pump numbers before migration'; end if;
end $$;
update public.nozzles set display_name='Pump'||nozzle_number::text where display_name is null;
alter table public.nozzles alter column station_id set not null;
alter table public.nozzles alter column display_name set not null;
alter table public.nozzles add constraint named_pump_label_valid check (
  display_name=btrim(display_name) and length(display_name) between 1 and 80 and
  display_name !~ '[[:cntrl:]]');
create unique index if not exists named_pumps_station_label_unique on public.nozzles(station_id,lower(display_name));
create unique index if not exists named_pumps_station_number_unique on public.nozzles(station_id,nozzle_number);

create or replace function public.validate_named_pump()
returns trigger language plpgsql set search_path='' as $$
declare parent public.pumps; supply public.tanks; actor public.profiles;
begin
  select * into parent from public.pumps where id=new.pump_id;
  select * into supply from public.tanks where id=new.supplying_tank_id;
  if parent.id is null or supply.id is null or supply.station_id<>parent.station_id or
     supply.product_id<>new.product_id or not parent.is_active or not supply.is_active
    then raise exception 'Pump and supplying tank must belong to the same station/product'; end if;
  if new.station_id is not null and new.station_id<>parent.station_id
    then raise exception 'Pump station mismatch'; end if;
  new.station_id:=parent.station_id;
  if TG_OP='UPDATE' and (new.id<>old.id or new.station_id<>old.station_id or
      new.nozzle_number<>old.nozzle_number or new.pump_id<>old.pump_id)
    then raise exception 'Permanent pump identity cannot be changed'; end if;
  if current_user in ('anon','authenticated') and (TG_OP='INSERT' or
      new.display_name is distinct from old.display_name or new.product_id is distinct from old.product_id) then
    select * into actor from public.profiles where id=(select public.authenticated_profile_id());
    if actor.id is null or actor.role::text<>'director' then raise exception 'Verified director required'; end if;
  end if;
  return new;
end $$;
create trigger named_pump_validate before insert or update on public.nozzles
for each row execute function public.validate_named_pump();

create table public.pump_name_history (
  id bigint generated always as identity primary key,
  nozzle_id uuid not null references public.nozzles(id),
  station_id uuid not null references public.stations(id),
  old_name text, new_name text not null,
  changed_by uuid references public.profiles(id),
  changed_at timestamptz not null default now()
);
create index pump_name_history_pump_idx on public.pump_name_history(nozzle_id,changed_at);
create index pump_name_history_station_idx on public.pump_name_history(station_id);
create index pump_name_history_actor_idx on public.pump_name_history(changed_by);
alter table public.pump_name_history enable row level security;
revoke all on public.pump_name_history from public,anon,authenticated;
grant select on public.pump_name_history to authenticated;
create policy pump_name_history_read on public.pump_name_history for select to authenticated
using (exists(select 1 from public.profiles p where p.id=(select public.authenticated_profile_id())
  and (p.role::text='director' or (p.station_id=pump_name_history.station_id and p.role::text='manager'))));
create or replace function public.audit_pump_name()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if TG_OP='INSERT' or new.display_name is distinct from old.display_name then
    insert into public.pump_name_history(nozzle_id,station_id,old_name,new_name,changed_by)
    values(new.id,new.station_id,case when TG_OP='UPDATE' then old.display_name else null end,
      new.display_name,public.authenticated_profile_id());
  end if;
  return new;
end $$;
create trigger named_pump_audit after insert or update on public.nozzles
for each row execute function public.audit_pump_name();

create or replace function public.register_named_pump(p_station_code text,p_id uuid,p_name text,
  p_product_code text,p_tank_code text,p_opening numeric,p_legacy_number integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.profiles; branch public.stations; supply public.tanks;
  product public.fuel_products; existing public.nozzles; saved public.nozzles;
  parent_id uuid; next_number integer;
begin
  select * into actor from public.profiles where id=(select public.authenticated_profile_id());
  if actor.id is null or actor.role::text<>'director' then raise exception 'Verified director required'; end if;
  select * into branch from public.stations where code=p_station_code and is_active;
  select * into product from public.fuel_products where code=p_product_code and is_active;
  if p_id is null or branch.id is null or product.id is null or p_name is null or
     length(btrim(p_name)) not between 1 and 80 or p_name ~ '[[:cntrl:]]' or p_opening is null or
     p_opening<0 or p_opening>=1000000000000 or p_opening::text in ('NaN','Infinity','-Infinity') or
     (p_legacy_number is not null and p_legacy_number<=0)
    then raise exception 'Valid pump name, station, product and opening meter required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(branch.id::text||':named-pumps',0));
  select * into existing from public.nozzles where id=p_id;
  if found then
    if existing.station_id<>branch.id or existing.display_name<>btrim(p_name) or existing.product_id<>product.id
      then raise exception 'Equipment ID conflicts with an existing pump'; end if;
    return to_jsonb(existing);
  end if;
  select * into supply from public.tanks where station_id=branch.id and code=p_tank_code and is_active;
  if supply.id is null or supply.product_id<>product.id then raise exception 'Supplying tank/product mismatch'; end if;
  select coalesce(max(nozzle_number),0)+1 into next_number from public.nozzles where station_id=branch.id;
  next_number:=coalesce(p_legacy_number,next_number);
  insert into public.pumps(station_id,code,name,is_active)
    values(branch.id,'PT-'||left(replace(p_id::text,'-',''),17),left(btrim(p_name),50),true) returning id into parent_id;
  insert into public.nozzles(id,pump_id,station_id,nozzle_number,display_name,product_id,supplying_tank_id,latest_meter_reading,is_active)
    values(p_id,parent_id,branch.id,next_number,btrim(p_name),product.id,supply.id,p_opening,true) returning * into saved;
  return to_jsonb(saved);
end $$;
revoke all on function public.register_named_pump(text,uuid,text,text,text,numeric,integer) from public,anon;
grant execute on function public.register_named_pump(text,uuid,text,text,text,numeric,integer) to authenticated;

create or replace function public.rename_named_pump(p_id uuid,p_station_code text,p_name text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.profiles; saved public.nozzles;
begin
  select * into actor from public.profiles where id=(select public.authenticated_profile_id());
  if actor.id is null or actor.role::text<>'director' then raise exception 'Verified director required'; end if;
  if p_name is null or length(btrim(p_name)) not between 1 and 80 or p_name ~ '[[:cntrl:]]'
    then raise exception 'Invalid pump name'; end if;
  update public.nozzles n set display_name=btrim(p_name) from public.stations s
  where n.id=p_id and s.code=p_station_code and s.id=n.station_id and s.is_active returning n.* into saved;
  if saved.id is null then raise exception 'Pump not found in this station'; end if;
  return to_jsonb(saved);
end $$;
revoke all on function public.rename_named_pump(uuid,text,text) from public,anon;
grant execute on function public.rename_named_pump(uuid,text,text) to authenticated;

-- Shift adjustments keep immutable equipment identity and the name at entry time.
alter table public.shift_adjustments add column if not exists nozzle_id uuid references public.nozzles(id);
alter table public.shift_adjustments add column if not exists pump_name_snapshot text;
create index if not exists shift_adjustments_pump_idx on public.shift_adjustments(nozzle_id);
update public.shift_adjustments a set nozzle_id=n.id,pump_name_snapshot=n.display_name
from public.nozzles n join public.stations s on s.id=n.station_id
where a.station_code=s.code and a.nozzle_number=n.nozzle_number and a.kind<>'expense' and a.nozzle_id is null;
create or replace function public.bind_adjustment_pump()
returns trigger language plpgsql security definer set search_path='' as $$
declare point public.nozzles;
begin
  if new.kind<>'expense' then
    select n.* into point from public.nozzles n join public.stations s on s.id=n.station_id
    where s.code=new.station_code and n.nozzle_number=new.nozzle_number and n.is_active;
    if point.id is null or (new.nozzle_id is not null and new.nozzle_id<>point.id)
      then raise exception 'Pump does not belong to this shift station'; end if;
    new.nozzle_id:=point.id; new.pump_name_snapshot:=point.display_name;
  end if;
  return new;
end $$;
create trigger shift_adjustment_pump_identity before insert on public.shift_adjustments
for each row execute function public.bind_adjustment_pump();

-- UUID-first submission while retaining the reviewed adjustment business rules.
alter function public.submit_shift_adjustment(jsonb) rename to submit_shift_adjustment_numeric_legacy;
revoke all on function public.submit_shift_adjustment_numeric_legacy(jsonb) from public,anon,authenticated;
create function public.submit_shift_adjustment(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.profiles; point public.nozzles;
begin
  if p_entry->>'kind'<>'expense' and nullif(p_entry->>'nozzle_id','') is not null then
    select * into actor from public.profiles where id=(select public.authenticated_profile_id());
    select * into point from public.nozzles where id=(p_entry->>'nozzle_id')::uuid and station_id=actor.station_id;
    if point.id is null then raise exception 'Pump identity does not belong to this station'; end if;
    if (p_entry->>'nozzle_number') is not null and (p_entry->>'nozzle_number')::integer<>point.nozzle_number
      then raise exception 'Conflicting pump identity'; end if;
    p_entry:=p_entry||jsonb_build_object('nozzle_number',point.nozzle_number);
  end if;
  return public.submit_shift_adjustment_numeric_legacy(p_entry);
end $$;
revoke all on function public.submit_shift_adjustment(jsonb) from public,anon;
grant execute on function public.submit_shift_adjustment(jsonb) to authenticated;

alter table public.credit_sales add column if not exists pump_name_snapshot text;
update public.credit_sales c set pump_name_snapshot=n.display_name from public.nozzles n
where n.id=c.nozzle_id and c.pump_name_snapshot is null;
create function public.snapshot_credit_pump_name()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  select display_name into new.pump_name_snapshot from public.nozzles where id=new.nozzle_id;
  return new;
end $$;
create trigger credit_pump_name_snapshot before insert on public.credit_sales
for each row execute function public.snapshot_credit_pump_name();
notify pgrst,'reload schema';
commit;
