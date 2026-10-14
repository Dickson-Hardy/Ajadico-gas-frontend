-- Configuration only. Does NOT secure legacy tables or establish user sessions.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create table if not exists public.operational_policy (
  id text primary key check (id = 'company'),
  revision bigint not null default 1 check (revision > 0),
  cashier_approval_limit numeric(14,2) not null check (cashier_approval_limit >= 0),
  manager_approval_limit numeric(14,2) not null
    check (manager_approval_limit >= cashier_approval_limit),
  expense_categories text[] not null
    check (cardinality(expense_categories) between 1 and 50
      and array_position(expense_categories, null) is null),
  updated_at timestamptz not null default now()
);
create or replace function public.touch_operational_policy()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.revision := old.revision + 1;
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;
drop trigger if exists operational_policy_updated on public.operational_policy;
create trigger operational_policy_updated before update on public.operational_policy
for each row execute function public.touch_operational_policy();
alter table public.operational_policy enable row level security;
revoke all on public.operational_policy from public, anon, authenticated;
grant select on public.operational_policy to authenticated;
drop policy if exists operational_policy_read on public.operational_policy;
create policy operational_policy_read on public.operational_policy
for select to authenticated using (
  exists (select 1 from public.profiles where id=(select auth.uid()) and is_active)
);

-- No seeded limits or categories. An empty table means Setup is required.
create table if not exists public.operational_policy_audit (
  revision bigint primary key,
  changed_by uuid not null references public.profiles(id),
  changed_at timestamptz not null default now(),
  policy_snapshot jsonb not null
);
create index if not exists operational_policy_audit_actor_idx on public.operational_policy_audit(changed_by);
alter table public.operational_policy_audit enable row level security;
revoke all on public.operational_policy_audit from public, anon, authenticated;
grant select on public.operational_policy_audit to authenticated;
drop policy if exists operational_policy_audit_director_read on public.operational_policy_audit;
create policy operational_policy_audit_director_read on public.operational_policy_audit for select to authenticated
using (exists (select 1 from public.profiles where id=(select auth.uid()) and is_active and role::text='director'));

create or replace function public.configure_operational_policy(
  p_cashier_limit numeric, p_manager_limit numeric, p_categories text[], p_expected_revision bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor public.profiles; existing public.operational_policy; saved public.operational_policy;
begin
  select * into actor from public.profiles where id=(select auth.uid()) and is_active and role::text='director';
  if actor.id is null then raise exception 'Verified director required'; end if;
  if p_cashier_limit is null or p_manager_limit is null or p_cashier_limit<0 or
     p_manager_limit<p_cashier_limit or p_manager_limit>=1000000000000 or
     p_cashier_limit::text in ('NaN','Infinity','-Infinity') or p_manager_limit::text in ('NaN','Infinity','-Infinity') or
     p_categories is null or cardinality(p_categories) not between 1 and 50 or
     array_position(p_categories,null) is not null or
     exists (select 1 from unnest(p_categories) category where length(btrim(category)) not between 1 and 100 or category<>btrim(category)) or
     (select count(distinct category) from unnest(p_categories) category)<>cardinality(p_categories)
    then raise exception 'Invalid limits or categories'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('company-operational-policy',0));
  select * into existing from public.operational_policy where id='company' for update;
  if p_expected_revision is distinct from coalesce(existing.revision,0)
    then raise exception 'Policy changed; refresh before saving'; end if;
  insert into public.operational_policy(id,cashier_approval_limit,manager_approval_limit,expense_categories)
    values ('company',p_cashier_limit,p_manager_limit,p_categories)
  on conflict(id) do update set cashier_approval_limit=excluded.cashier_approval_limit,
    manager_approval_limit=excluded.manager_approval_limit,expense_categories=excluded.expense_categories
  returning * into saved;
  insert into public.operational_policy_audit(revision,changed_by,policy_snapshot)
    values(saved.revision,actor.id,to_jsonb(saved));
  return to_jsonb(saved);
end;
$$;
revoke all on function public.configure_operational_policy(numeric,numeric,text[],bigint) from public,anon;
grant execute on function public.configure_operational_policy(numeric,numeric,text[],bigint) to authenticated;
commit;
