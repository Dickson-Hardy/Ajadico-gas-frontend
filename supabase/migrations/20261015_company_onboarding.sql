-- PREPARED ONLY. Requires review and explicit approval before production use.
-- Single-company deployment. Does not isolate multiple companies or secure
-- legacy anonymous business APIs. Never renumbers existing profile IDs.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

alter table public.profiles add column if not exists auth_user_id uuid
  references auth.users(id) on delete set null;
create unique index if not exists profiles_auth_user_id_unique
  on public.profiles(auth_user_id) where auth_user_id is not null;

-- Legacy clients must not claim an Auth identity through direct profile writes.
create or replace function public.protect_profile_auth_mapping()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon','authenticated') and
    ((TG_OP = 'INSERT' and new.auth_user_id is not null) or
     (TG_OP = 'UPDATE' and new.auth_user_id is distinct from old.auth_user_id))
  then raise exception 'Account linking requires trusted administration'; end if;
  return new;
end;
$$;
drop trigger if exists profiles_protect_auth_mapping on public.profiles;
create trigger profiles_protect_auth_mapping before insert or update on public.profiles
for each row execute function public.protect_profile_auth_mapping();

create or replace function public.authenticated_profile_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select p.id from public.profiles p join auth.users u on u.id=p.auth_user_id
  where p.auth_user_id=(select auth.uid()) and p.is_active
    and (u.banned_until is null or u.banned_until <= now())
    and (p.role::text not in ('manager','director') or u.email_confirmed_at is not null)
$$;
revoke all on function public.authenticated_profile_id() from public, anon;
grant execute on function public.authenticated_profile_id() to authenticated;

create or replace function public.current_staff_profile()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id',p.id,'auth_user_id',p.auth_user_id,
    'display_name',p.display_name,'full_name',p.full_name,'role',p.role,
    'station_id',p.station_id,'station_name',coalesce(s.name,''),'is_active',p.is_active)
  from public.profiles p left join public.stations s on s.id=p.station_id
  where p.id=(select public.authenticated_profile_id())
    and (p.role::text='director' or s.is_active)
$$;
revoke all on function public.current_staff_profile() from public, anon;
grant execute on function public.current_staff_profile() to authenticated;

-- Retain the reviewed business rules and update only their actor lookup.
-- Abort on an unexpected installed definition rather than silently adapting it.
do $$
declare signature text; definition text; updated text;
begin
  foreach signature in array array[
    'public.configure_operational_policy(numeric,numeric,text[],bigint)',
    'public.can_read_shift_adjustment(text,uuid)',
    'public.submit_shift_adjustment(jsonb)',
    'public.review_shift_adjustment(uuid,boolean,text)']
  loop
    definition := pg_get_functiondef(signature::regprocedure);
    updated := replace(definition,'(select auth.uid())','(select public.authenticated_profile_id())');
    if updated=definition and position('public.authenticated_profile_id()' in definition)=0
      then raise exception 'Unexpected actor lookup in %; review manually',signature; end if;
    execute updated;
  end loop;
end;
$$;
drop policy if exists operational_policy_read on public.operational_policy;
create policy operational_policy_read on public.operational_policy
for select to authenticated using ((select public.authenticated_profile_id()) is not null);
drop policy if exists operational_policy_audit_director_read on public.operational_policy_audit;
create policy operational_policy_audit_director_read on public.operational_policy_audit
for select to authenticated using (exists(select 1 from public.profiles
  where id=(select public.authenticated_profile_id()) and role::text='director'));

create table if not exists public.company_workspace (
  id text primary key check(id='company'),
  company_name text not null check(length(btrim(company_name)) between 2 and 150),
  web_url text check(web_url is null or web_url ~ '^https://[^[:space:]]+$'),
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now()
);
-- Also supports a staging deployment of the earlier prepared definition.
alter table public.company_workspace alter column web_url drop not null;
create index if not exists company_workspace_updated_by_idx on public.company_workspace(updated_by);
alter table public.company_workspace enable row level security;
revoke all on public.company_workspace from public, anon, authenticated;
grant select on public.company_workspace to authenticated;
drop policy if exists company_workspace_read on public.company_workspace;
create policy company_workspace_read on public.company_workspace for select to authenticated
using ((select public.authenticated_profile_id()) is not null);

create or replace function public.configure_company_workspace(p_name text,p_web_url text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor public.profiles; saved public.company_workspace;
begin
  select * into actor from public.profiles where id=(select public.authenticated_profile_id());
  if actor.id is null or actor.role::text<>'director' then raise exception 'Verified director required'; end if;
  if p_name is null or length(btrim(p_name)) not between 2 and 150 or
     (nullif(btrim(p_web_url),'') is not null and
       (p_web_url !~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]?#]*)?$' or
        p_web_url ~* '^https://(localhost|127\.0\.0\.1)([:/]|$)'))
    then raise exception 'Company name and optional valid HTTPS URL required'; end if;
  insert into public.company_workspace(id,company_name,web_url,updated_by)
  values('company',btrim(p_name),nullif(btrim(p_web_url),''),actor.id)
  on conflict(id) do update set company_name=excluded.company_name,
    web_url=excluded.web_url,updated_by=excluded.updated_by,updated_at=now()
  returning * into saved;
  return to_jsonb(saved);
end;
$$;
revoke all on function public.configure_company_workspace(text,text) from public,anon;
grant execute on function public.configure_company_workspace(text,text) to authenticated;

create or replace function public.register_company_station(p_station jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor public.profiles; saved public.stations;
  station_code text := upper(btrim(p_station->>'code'));
  station_name text := btrim(p_station->>'name');
begin
  select * into actor from public.profiles where id=(select public.authenticated_profile_id());
  if actor.id is null or actor.role::text<>'director' then raise exception 'Verified director required'; end if;
  if station_code is null or station_code !~ '^[A-Z0-9][A-Z0-9-]{0,19}$' or
     station_name is null or length(station_name) not between 2 and 100 or
     length(coalesce(p_station->>'address',''))>1000 or length(coalesce(p_station->>'phone',''))>30 or
     length(coalesce(p_station->>'manager_name',''))>100
    then raise exception 'Invalid station details'; end if;
  insert into public.stations(code,name,address,phone,manager_name,has_interlocked_tanks,is_active)
  values(station_code,station_name,nullif(btrim(p_station->>'address'),''),
    nullif(btrim(p_station->>'phone'),''),nullif(btrim(p_station->>'manager_name'),''),
    coalesce((p_station->>'has_interlocked_tanks')::boolean,false),true)
  returning * into saved;
  return to_jsonb(saved);
end;
$$;
revoke all on function public.register_company_station(jsonb) from public,anon;
grant execute on function public.register_company_station(jsonb) to authenticated;

create or replace function public.company_onboarding_status()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor public.profiles;
begin
  select * into actor from public.profiles where id=(select public.authenticated_profile_id());
  if actor.id is null or actor.role::text<>'director' then raise exception 'Verified director required'; end if;
  return jsonb_build_object(
    'workspace',(select to_jsonb(w) from public.company_workspace w where id='company'),
    'policy_configured',exists(select 1 from public.operational_policy where id='company'),
    'active_stations',(select count(*) from public.stations where is_active),
    'unlinked_management',(select count(*) from public.profiles where is_active
       and role::text in ('manager','director') and auth_user_id is null),
    'active_staff',(select count(*) from public.profiles where is_active and role::text<>'director'),
    'unlinked_staff',(select count(*) from public.profiles where is_active and role::text<>'director' and auth_user_id is null),
    'infrastructure_configured',
      exists(select 1 from public.stations where is_active) and not exists(
        select 1 from public.stations s where s.is_active and (
          not exists(select 1 from public.tanks t where t.station_id=s.id and t.is_active and t.capacity_litres>0) or
          not exists(select 1 from public.nozzles n join public.pumps p on p.id=n.pump_id
            where p.station_id=s.id and p.is_active and n.is_active) or
          exists(select 1 from public.nozzles n join public.pumps p on p.id=n.pump_id
            left join public.tanks t on t.id=n.supplying_tank_id
            where p.station_id=s.id and p.is_active and n.is_active and
              (t.id is null or not t.is_active or t.station_id<>s.id or t.product_id<>n.product_id or
               n.latest_meter_reading is null or n.latest_meter_reading<0 or
               not exists(select 1 from public.fuel_prices f where f.station_id=s.id
                 and f.product_id=n.product_id and f.effective_from<=now()
                 and (f.effective_to is null or f.effective_to>now()) and f.price_per_litre>0)))
        )),
    -- A capability declaration, not a simulated enrollment or seeded device.
    -- Replace only when the reviewed device/session service is deployed.
    'tablet_authentication_available',false);
end;
$$;
revoke all on function public.company_onboarding_status() from public,anon;
grant execute on function public.company_onboarding_status() to authenticated;
notify pgrst,'reload schema';
commit;
