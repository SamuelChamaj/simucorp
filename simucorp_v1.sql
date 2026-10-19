-- ============================================================
-- SimuCorp v1 – finálny kandidát na prvé testovacie spustenie
-- NEBOL REÁLNE SPUSTENÝ
-- ============================================================
-- Pred spustením over gen_random_bytes:
-- select n.nspname, p.proname
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where p.proname = 'gen_random_bytes';
-- a uprav volanie v create_class podľa skutočnej schémy.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'student' check (role in ('student', 'teacher', 'admin')),
  teacher_approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  teacher_id uuid not null references public.profiles(id),
  join_code text not null unique,
  simulation_status text not null default 'paused'
    check (simulation_status in ('paused', 'running', 'archived')),
  allow_new_members boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.class_members (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'inactive')),
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  unique (class_id, user_id)
);

create table public.firms (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  owner_user_id uuid not null references public.profiles(id),
  name text not null,
  initial_capital numeric(15,2) not null check (initial_capital >= 0),
  cash_balance numeric(15,2) not null check (cash_balance >= 0),
  total_contributions numeric(15,2) not null check (total_contributions >= 0),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  unique (class_id, owner_user_id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  name text not null,
  description text,
  unit text not null default 'ks',
  created_at timestamptz not null default now(),
  unique (class_id, name)
);

create table public.inventory (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity numeric(15,4) not null check (quantity >= 0),
  unit_cost numeric(15,6) not null check (unit_cost >= 0),
  updated_at timestamptz not null default now(),
  unique (firm_id, product_id)
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid references public.firms(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity_available numeric(15,4) not null check (quantity_available >= 0),
  unit_price numeric(15,4) not null check (unit_price > 0),
  status text not null default 'active' check (status in ('active', 'closed')),
  seller_type text not null check (seller_type in ('firm', 'system')),
  created_at timestamptz not null default now(),
  check (
    (seller_type = 'firm' and firm_id is not null) or
    (seller_type = 'system' and firm_id is null)
  )
);

create table public.trades (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  seller_type text not null check (seller_type in ('firm', 'system')),
  seller_firm_id uuid references public.firms(id),
  buyer_type text not null check (buyer_type in ('firm', 'system')),
  buyer_firm_id uuid references public.firms(id),
  product_id uuid not null references public.products(id),
  quantity numeric(15,4) not null check (quantity > 0),
  unit_price numeric(15,4) not null check (unit_price > 0),
  total_amount numeric(15,2) not null check (total_amount > 0),
  trade_type text not null check (trade_type in ('peer', 'system_supply', 'automatic_demand')),
  idempotency_key uuid not null unique,
  created_at timestamptz not null default now(),
  check (
    (seller_type = 'firm' and seller_firm_id is not null) or
    (seller_type = 'system' and seller_firm_id is null)
  ),
  check (
    (buyer_type = 'firm' and buyer_firm_id is not null) or
    (buyer_type = 'system' and buyer_firm_id is null)
  )
);

create table public.financial_transactions (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete cascade,
  amount numeric(15,2) not null check (amount > 0),
  type text not null check (type in (
    'initial_capital', 'contribution', 'sale_revenue',
    'purchase_cash', 'cogs', 'other_cost'
  )),
  related_trade_id uuid references public.trades(id),
  description text,
  created_at timestamptz not null default now()
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity_change numeric(15,4) not null,
  unit_cost numeric(15,6) not null,
  related_trade_id uuid references public.trades(id),
  created_at timestamptz not null default now()
);

create table public.idempotency_keys (
  key uuid primary key,
  user_id uuid not null references public.profiles(id),
  listing_id uuid not null,
  quantity numeric(15,4) not null,
  buyer_firm_id uuid not null,
  created_at timestamptz not null default now()
);

create index idx_cm_active on public.class_members(class_id, user_id) where status = 'active';
create index idx_firms_class_owner on public.firms(class_id, owner_user_id);
create index idx_listings_active on public.listings(firm_id, product_id) where status = 'active';
create index idx_inv on public.inventory(firm_id, product_id);

create or replace function public.is_active_member(p_class_id uuid)
returns boolean language sql security definer set search_path = '' stable as $$
  select exists (
    select 1 from public.class_members
    where class_id = p_class_id and user_id = auth.uid() and status = 'active'
  );
$$;

create or replace function public.is_class_teacher(p_class_id uuid)
returns boolean language sql security definer set search_path = '' stable as $$
  select exists (
    select 1 from public.classes c
    join public.profiles p on p.id = auth.uid()
    where c.id = p_class_id and c.teacher_id = auth.uid()
      and p.role = 'teacher' and p.teacher_approved = true
  );
$$;

revoke all on function public.is_active_member(uuid) from public;
revoke all on function public.is_class_teacher(uuid) from public;
grant execute on function public.is_active_member(uuid) to authenticated;
grant execute on function public.is_class_teacher(uuid) to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''), 'student');
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.protect_profile_privileges()
returns trigger language plpgsql as $$
begin
  if new.role is distinct from old.role
     or new.teacher_approved is distinct from old.teacher_approved then
    if current_user in ('authenticated', 'anon') then
      raise exception 'role change not allowed';
    end if;
  end if;
  return new;
end; $$;
create trigger trg_protect_profile before update on public.profiles
  for each row execute function public.protect_profile_privileges();

create or replace function public.trg_listing_class()
returns trigger language plpgsql as $$
declare v_pc uuid; v_fc uuid;
begin
  select class_id into v_pc from public.products where id = new.product_id;
  if new.seller_type = 'firm' then
    select class_id into v_fc from public.firms where id = new.firm_id;
    if v_fc is distinct from v_pc then raise exception 'listing class mismatch'; end if;
  end if;
  return new;
end; $$;
create trigger trg_listing_class before insert or update on public.listings
  for each row execute function public.trg_listing_class();

create or replace function public.trg_trade_class()
returns trigger language plpgsql as $$
declare v_pc uuid; v_sc uuid; v_bc uuid;
begin
  select class_id into v_pc from public.products where id = new.product_id;
  if new.seller_type = 'firm' then
    select class_id into v_sc from public.firms where id = new.seller_firm_id;
    if v_sc is distinct from new.class_id or v_sc is distinct from v_pc then
      raise exception 'trade seller class mismatch';
    end if;
  end if;
  if new.buyer_type = 'firm' then
    select class_id into v_bc from public.firms where id = new.buyer_firm_id;
    if v_bc is distinct from new.class_id or v_bc is distinct from v_pc then
      raise exception 'trade buyer class mismatch';
    end if;
  end if;
  if v_pc is distinct from new.class_id then raise exception 'trade product class mismatch'; end if;
  return new;
end; $$;
create trigger trg_trade_class before insert or update on public.trades
  for each row execute function public.trg_trade_class();

create or replace function public.trg_inventory_class()
returns trigger language plpgsql as $$
declare v_fc uuid; v_pc uuid;
begin
  select class_id into v_fc from public.firms where id = new.firm_id;
  select class_id into v_pc from public.products where id = new.product_id;
  if v_fc is distinct from v_pc then raise exception 'inventory class mismatch'; end if;
  return new;
end; $$;
create trigger trg_inventory_class before insert or update on public.inventory
  for each row execute function public.trg_inventory_class();

create or replace function public.request_teacher_role()
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_count int;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  update public.profiles set role = 'teacher', teacher_approved = false
  where id = v_uid and role = 'student';
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'cannot request teacher role'; end if;
end; $$;
revoke all on function public.request_teacher_role() from public;
grant execute on function public.request_teacher_role() to authenticated;

create or replace function public.approve_teacher(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'admin') then
    raise exception 'not admin';
  end if;
  update public.profiles set teacher_approved = true where id = p_user_id and role = 'teacher';
end; $$;
revoke all on function public.approve_teacher(uuid) from public;
grant execute on function public.approve_teacher(uuid) to authenticated;

create or replace function public.create_class(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_id uuid; v_code text; v_tries int := 0;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and role = 'teacher' and teacher_approved = true) then
    raise exception 'not approved teacher';
  end if;
  if p_name is null or length(trim(p_name)) < 1 then raise exception 'invalid name'; end if;
  loop
    v_tries := v_tries + 1;
    if v_tries > 5 then raise exception 'could not generate join code'; end if;
    -- Uprav podľa skutočnej schémy gen_random_bytes
    v_code := upper(encode(extensions.gen_random_bytes(4), 'hex'));
    begin
      insert into public.classes (name, teacher_id, join_code)
      values (trim(p_name), v_uid, v_code) returning id into v_id;
      return v_id;
    exception when unique_violation then
      null;
    end;
  end loop;
end; $$;
revoke all on function public.create_class(text) from public;
grant execute on function public.create_class(text) to authenticated;

create or replace function public.join_class(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_class_id uuid; v_status text; v_allow boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select id, simulation_status, allow_new_members into v_class_id, v_status, v_allow
  from public.classes where join_code = upper(trim(p_code)) for update;
  if v_class_id is null then raise exception 'invalid code'; end if;
  if v_status = 'archived' or not coalesce(v_allow, false) then raise exception 'cannot join'; end if;
  insert into public.class_members (class_id, user_id, status)
  values (v_class_id, v_uid, 'active')
  on conflict (class_id, user_id) do nothing;
  if not public.is_active_member(v_class_id) then
    raise exception 'membership inactive – ask teacher to reactivate';
  end if;
  return v_class_id;
end; $$;
revoke all on function public.join_class(text) from public;
grant execute on function public.join_class(text) to authenticated;

create or replace function public.reactivate_class_member(p_class_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_status text; v_class_status text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_class_teacher(p_class_id) then raise exception 'not class teacher'; end if;
  select simulation_status into v_class_status from public.classes where id = p_class_id for update;
  if v_class_status is null then raise exception 'class not found'; end if;
  if v_class_status = 'archived' then raise exception 'cannot reactivate member in archived class'; end if;
  select status into v_status from public.class_members
  where class_id = p_class_id and user_id = p_user_id;
  if v_status is distinct from 'inactive' then
    raise exception 'no inactive membership to reactivate';
  end if;
  update public.class_members set status = 'active', removed_at = null
  where class_id = p_class_id and user_id = p_user_id;
  update public.firms set status = 'active'
  where class_id = p_class_id and owner_user_id = p_user_id and status = 'inactive';
end; $$;
revoke all on function public.reactivate_class_member(uuid, uuid) from public;
grant execute on function public.reactivate_class_member(uuid, uuid) to authenticated;

create or replace function public.remove_class_member(p_class_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_firm_id uuid;
  v_class_status text;
  v_count integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_class_teacher(p_class_id) then raise exception 'not class teacher'; end if;
  select simulation_status into v_class_status from public.classes where id = p_class_id for update;
  if v_class_status is null then raise exception 'class not found'; end if;
  if v_class_status = 'archived' then raise exception 'cannot modify archived class'; end if;

  update public.class_members set status = 'inactive', removed_at = now()
  where class_id = p_class_id and user_id = p_user_id and status = 'active';
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'no active membership to remove'; end if;

  select id into v_firm_id from public.firms
  where class_id = p_class_id and owner_user_id = p_user_id and status = 'active';
  if v_firm_id is not null then
    perform 1 from public.firms where id = v_firm_id for update;
    update public.firms set status = 'inactive' where id = v_firm_id;
    update public.listings set status = 'closed', quantity_available = 0
    where firm_id = v_firm_id and status = 'active';
  end if;
end; $$;
revoke all on function public.remove_class_member(uuid, uuid) from public;
grant execute on function public.remove_class_member(uuid, uuid) to authenticated;

create or replace function public.set_class_status(p_class_id uuid, p_status text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_current text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_status is null or p_status not in ('paused','running','archived') then
    raise exception 'invalid status';
  end if;
  if not public.is_class_teacher(p_class_id) then raise exception 'not class teacher'; end if;
  select simulation_status into v_current from public.classes where id = p_class_id for update;
  if v_current is null then raise exception 'class not found'; end if;
  if v_current = 'archived' and p_status <> 'archived' then
    raise exception 'archived class cannot be reactivated';
  end if;
  update public.classes set simulation_status = p_status where id = p_class_id;
end; $$;
revoke all on function public.set_class_status(uuid, text) from public;
grant execute on function public.set_class_status(uuid, text) to authenticated;

create or replace function public.create_firm(p_class_id uuid, p_name text, p_initial_capital numeric)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_firm_id uuid; v_status text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_name is null or length(trim(p_name)) < 2 or length(trim(p_name)) > 100 then raise exception 'invalid name'; end if;
  if p_initial_capital is null or p_initial_capital < 0 or p_initial_capital > 1000000 then
    raise exception 'invalid capital';
  end if;
  if p_initial_capital <> round(p_initial_capital, 2) then
    raise exception 'capital precision exceeds 2 decimal places';
  end if;
  select simulation_status into v_status from public.classes where id = p_class_id for update;
  if v_status is null or v_status = 'archived' then raise exception 'class not available'; end if;
  if not public.is_active_member(p_class_id) then raise exception 'not active member'; end if;
  if exists (select 1 from public.firms where class_id = p_class_id and owner_user_id = v_uid) then
    raise exception 'firm already exists';
  end if;
  insert into public.firms (class_id, owner_user_id, name, initial_capital, cash_balance, total_contributions)
  values (p_class_id, v_uid, trim(p_name), p_initial_capital, p_initial_capital, p_initial_capital)
  returning id into v_firm_id;
  if p_initial_capital > 0 then
    insert into public.financial_transactions (firm_id, amount, type, description)
    values (v_firm_id, p_initial_capital, 'initial_capital', 'Počiatočný kapitál');
  end if;
  return v_firm_id;
end; $$;
revoke all on function public.create_firm(uuid, text, numeric) from public;
grant execute on function public.create_firm(uuid, text, numeric) to authenticated;

create or replace function public.create_product(p_class_id uuid, p_name text, p_unit text default 'ks')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_id uuid; v_status text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_class_teacher(p_class_id) then raise exception 'not class teacher'; end if;
  select simulation_status into v_status from public.classes where id = p_class_id for update;
  if v_status is null then raise exception 'class not found'; end if;
  if v_status = 'archived' then raise exception 'class archived'; end if;
  if p_name is null or length(trim(p_name)) < 1 then raise exception 'invalid name'; end if;
  insert into public.products (class_id, name, unit)
  values (p_class_id, trim(p_name), coalesce(nullif(trim(p_unit),''), 'ks'))
  returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.create_product(uuid, text, text) from public;
grant execute on function public.create_product(uuid, text, text) to authenticated;

create or replace function public.create_system_listing(p_product_id uuid, p_quantity numeric, p_unit_price numeric)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_class_id uuid; v_status text; v_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'invalid quantity'; end if;
  if p_quantity <> round(p_quantity, 4) then raise exception 'quantity precision exceeds 4 decimal places'; end if;
  if p_unit_price is null or p_unit_price <= 0 then raise exception 'invalid price'; end if;
  if p_unit_price <> round(p_unit_price, 4) then raise exception 'price precision exceeds 4 decimal places'; end if;
  select class_id into v_class_id from public.products where id = p_product_id;
  if v_class_id is null then raise exception 'product not found'; end if;
  if not public.is_class_teacher(v_class_id) then raise exception 'not class teacher'; end if;
  select simulation_status into v_status from public.classes where id = v_class_id for update;
  if v_status is null then raise exception 'class not found'; end if;
  if v_status = 'archived' then raise exception 'class archived'; end if;
  insert into public.listings (firm_id, product_id, quantity_available, unit_price, seller_type, status)
  values (null, p_product_id, p_quantity, p_unit_price, 'system', 'active')
  returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.create_system_listing(uuid, numeric, numeric) from public;
grant execute on function public.create_system_listing(uuid, numeric, numeric) to authenticated;

create or replace function public.upsert_firm_listing(
  p_firm_id uuid, p_product_id uuid, p_quantity numeric, p_unit_price numeric
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_firm public.firms%rowtype;
  v_class_id uuid;
  v_status text;
  v_prod_class uuid;
  v_inv numeric := 0;
  v_listing_id uuid;
  r record;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_quantity is null or p_quantity < 0 then raise exception 'invalid quantity'; end if;
  if p_quantity <> round(p_quantity, 4) then raise exception 'quantity precision exceeds 4 decimal places'; end if;
  if p_unit_price is null or p_unit_price <= 0 then raise exception 'invalid price'; end if;
  if p_unit_price <> round(p_unit_price, 4) then raise exception 'price precision exceeds 4 decimal places'; end if;

  select class_id into v_class_id from public.firms where id = p_firm_id;
  if v_class_id is null then raise exception 'firm not found'; end if;

  select simulation_status into v_status from public.classes where id = v_class_id for update;
  if v_status is null then raise exception 'class not found'; end if;
  if v_status is distinct from 'running' then raise exception 'simulation not running'; end if;

  perform 1 from public.firms where id = p_firm_id for update;
  select * into v_firm from public.firms where id = p_firm_id;
  if v_firm.owner_user_id <> v_uid or v_firm.status <> 'active' then raise exception 'invalid firm'; end if;
  if not public.is_active_member(v_class_id) then raise exception 'not active member'; end if;

  select class_id into v_prod_class from public.products where id = p_product_id;
  if v_prod_class is distinct from v_class_id then raise exception 'product class mismatch'; end if;

  select coalesce(quantity, 0) into v_inv
  from public.inventory where firm_id = p_firm_id and product_id = p_product_id for update;

  for r in
    select id from public.listings
    where firm_id = p_firm_id and product_id = p_product_id and status = 'active'
    order by id for update
  loop null; end loop;

  if coalesce(v_inv, 0) < p_quantity then raise exception 'quantity exceeds inventory'; end if;

  update public.listings set status = 'closed', quantity_available = 0
  where firm_id = p_firm_id and product_id = p_product_id and status = 'active';

  if p_quantity > 0 then
    insert into public.listings (firm_id, product_id, quantity_available, unit_price, seller_type, status)
    values (p_firm_id, p_product_id, p_quantity, p_unit_price, 'firm', 'active')
    returning id into v_listing_id;
  end if;
  return v_listing_id;
end; $$;
revoke all on function public.upsert_firm_listing(uuid, uuid, numeric, numeric) from public;
grant execute on function public.upsert_firm_listing(uuid, uuid, numeric, numeric) to authenticated;

create or replace function public.execute_trade(
  p_listing_id uuid, p_quantity numeric, p_buyer_firm_id uuid, p_idempotency_key uuid
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_listing public.listings%rowtype;
  v_buyer public.firms%rowtype;
  v_seller public.firms%rowtype;
  v_class_id uuid;
  v_status text;
  v_total numeric(15,2);
  v_trade_id uuid;
  v_req public.idempotency_keys%rowtype;
  v_sq numeric; v_sc numeric; v_cogs numeric(15,2);
  v_oq numeric; v_oc numeric; v_new_value numeric; v_nc numeric;
  v_fids uuid[]; v_fid uuid;
  v_seller_is_member boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'invalid quantity'; end if;
  if p_quantity <> round(p_quantity, 4) then raise exception 'quantity precision exceeds 4 decimal places'; end if;
  if p_listing_id is null or p_buyer_firm_id is null or p_idempotency_key is null then
    raise exception 'invalid parameters';
  end if;

  insert into public.idempotency_keys (key, user_id, listing_id, quantity, buyer_firm_id)
  values (p_idempotency_key, v_uid, p_listing_id, p_quantity, p_buyer_firm_id)
  on conflict (key) do nothing;

  select * into v_req from public.idempotency_keys where key = p_idempotency_key for update;
  if v_req.user_id <> v_uid or v_req.listing_id <> p_listing_id
     or v_req.quantity <> p_quantity or v_req.buyer_firm_id <> p_buyer_firm_id then
    raise exception 'idempotency mismatch';
  end if;

  select id into v_trade_id from public.trades where idempotency_key = p_idempotency_key;
  if v_trade_id is not null then return v_trade_id; end if;

  select * into v_listing from public.listings where id = p_listing_id;
  if not found then raise exception 'listing not found'; end if;
  select class_id into v_class_id from public.products where id = v_listing.product_id;
  if v_class_id is null then raise exception 'product not found'; end if;

  select simulation_status into v_status from public.classes where id = v_class_id for update;
  if v_status is null then raise exception 'class not found'; end if;
  if v_status <> 'running' then raise exception 'simulation not running'; end if;

  v_fids := array[p_buyer_firm_id];
  if v_listing.seller_type = 'firm' and v_listing.firm_id is not null then
    v_fids := array(select distinct x from unnest(v_fids || array[v_listing.firm_id]) x order by x);
  end if;
  foreach v_fid in array v_fids loop
    perform 1 from public.firms where id = v_fid for update;
  end loop;

  select * into v_buyer from public.firms where id = p_buyer_firm_id;
  if not found or v_buyer.owner_user_id <> v_uid or v_buyer.status <> 'active' or v_buyer.class_id <> v_class_id then
    raise exception 'invalid buyer';
  end if;
  if not public.is_active_member(v_class_id) then raise exception 'not active member'; end if;

  if v_listing.seller_type = 'firm' then
    select * into v_seller from public.firms where id = v_listing.firm_id;
    if not found or v_seller.status <> 'active' or v_seller.class_id <> v_class_id or v_seller.id = v_buyer.id then
      raise exception 'invalid seller';
    end if;
    select exists (
      select 1 from public.class_members
      where class_id = v_class_id and user_id = v_seller.owner_user_id and status = 'active'
    ) into v_seller_is_member;
    if not v_seller_is_member then raise exception 'seller owner not active member'; end if;

    select quantity, unit_cost into v_sq, v_sc from public.inventory
    where firm_id = v_seller.id and product_id = v_listing.product_id for update;
    if coalesce(v_sq, 0) < p_quantity then raise exception 'insufficient inventory'; end if;
  end if;

  select * into v_listing from public.listings where id = p_listing_id for update;
  if v_listing.status <> 'active' or v_listing.quantity_available < p_quantity then
    raise exception 'listing unavailable';
  end if;

  v_total := round(p_quantity * v_listing.unit_price, 2);
  if v_total <= 0 or v_buyer.cash_balance < v_total then raise exception 'invalid amount or insufficient cash'; end if;

  insert into public.trades (
    class_id, seller_type, seller_firm_id, buyer_type, buyer_firm_id,
    product_id, quantity, unit_price, total_amount, trade_type, idempotency_key
  ) values (
    v_class_id, v_listing.seller_type,
    case when v_listing.seller_type = 'firm' then v_listing.firm_id else null end,
    'firm', p_buyer_firm_id, v_listing.product_id, p_quantity, v_listing.unit_price, v_total,
    case when v_listing.seller_type = 'system' then 'system_supply' else 'peer' end,
    p_idempotency_key
  ) returning id into v_trade_id;

  update public.firms set cash_balance = cash_balance - v_total where id = p_buyer_firm_id;
  insert into public.financial_transactions (firm_id, amount, type, related_trade_id, description)
  values (p_buyer_firm_id, v_total, 'purchase_cash', v_trade_id, 'Nákup');

  select quantity, unit_cost into v_oq, v_oc from public.inventory
  where firm_id = p_buyer_firm_id and product_id = v_listing.product_id for update;

  if v_oq is null then
    insert into public.inventory (firm_id, product_id, quantity, unit_cost)
    values (p_buyer_firm_id, v_listing.product_id, p_quantity, round(v_total / p_quantity, 6));
  else
    v_new_value := (v_oq * coalesce(v_oc, 0)) + v_total;
    v_nc := round(v_new_value / (v_oq + p_quantity), 6);
    update public.inventory
    set quantity = quantity + p_quantity, unit_cost = v_nc, updated_at = now()
    where firm_id = p_buyer_firm_id and product_id = v_listing.product_id;
  end if;

  insert into public.inventory_movements (firm_id, product_id, quantity_change, unit_cost, related_trade_id)
  values (p_buyer_firm_id, v_listing.product_id, p_quantity, round(v_total / p_quantity, 6), v_trade_id);

  if v_listing.seller_type = 'firm' then
    update public.firms set cash_balance = cash_balance + v_total where id = v_seller.id;
    insert into public.financial_transactions (firm_id, amount, type, related_trade_id, description)
    values (v_seller.id, v_total, 'sale_revenue', v_trade_id, 'Predaj');
    v_cogs := round(p_quantity * coalesce(v_sc, 0), 2);
    if v_cogs > 0 then
      insert into public.financial_transactions (firm_id, amount, type, related_trade_id, description)
      values (v_seller.id, v_cogs, 'cogs', v_trade_id, 'COGS');
    end if;
    update public.inventory set quantity = quantity - p_quantity, updated_at = now()
    where firm_id = v_seller.id and product_id = v_listing.product_id;
    insert into public.inventory_movements (firm_id, product_id, quantity_change, unit_cost, related_trade_id)
    values (v_seller.id, v_listing.product_id, -p_quantity, coalesce(v_sc, 0), v_trade_id);
  end if;

  update public.listings
  set quantity_available = quantity_available - p_quantity,
      status = case when quantity_available - p_quantity <= 0 then 'closed' else status end
  where id = p_listing_id;

  return v_trade_id;
end; $$;
revoke all on function public.execute_trade(uuid, numeric, uuid, uuid) from public;
grant execute on function public.execute_trade(uuid, numeric, uuid, uuid) to authenticated;

create or replace function public.update_own_profile(p_full_name text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_full_name is null or length(trim(p_full_name)) < 1 or length(p_full_name) > 200 then raise exception 'invalid name'; end if;
  update public.profiles set full_name = trim(p_full_name) where id = auth.uid();
end; $$;
revoke all on function public.update_own_profile(text) from public;
grant execute on function public.update_own_profile(text) to authenticated;

create or replace function public.get_class_member_names(p_class_id uuid)
returns table (user_id uuid, full_name text)
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_class_teacher(p_class_id) then raise exception 'not allowed'; end if;
  return query
  select p.id, p.full_name
  from public.class_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.class_id = p_class_id and cm.status = 'active';
end; $$;
revoke all on function public.get_class_member_names(uuid) from public;
grant execute on function public.get_class_member_names(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.class_members enable row level security;
alter table public.firms enable row level security;
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.listings enable row level security;
alter table public.trades enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.idempotency_keys enable row level security;

create policy "profiles_select_own" on public.profiles for select using (id = auth.uid());
create policy "classes_select" on public.classes for select using (
  teacher_id = auth.uid() or public.is_active_member(id)
);
create policy "members_select" on public.class_members for select using (
  user_id = auth.uid() or public.is_class_teacher(class_id)
);
create policy "firms_select" on public.firms for select using (
  public.is_active_member(class_id) or public.is_class_teacher(class_id)
);
create policy "firms_no_write" on public.firms for all using (false) with check (false);
create policy "products_select" on public.products for select using (
  public.is_active_member(class_id) or public.is_class_teacher(class_id)
);
create policy "products_no_write" on public.products for all using (false) with check (false);
create policy "inventory_select" on public.inventory for select using (
  exists (select 1 from public.firms f where f.id = inventory.firm_id
    and (public.is_active_member(f.class_id) or public.is_class_teacher(f.class_id)))
);
create policy "inventory_no_write" on public.inventory for all using (false) with check (false);
create policy "listings_select" on public.listings for select using (
  exists (select 1 from public.products p where p.id = listings.product_id
    and (public.is_active_member(p.class_id) or public.is_class_teacher(p.class_id)))
);
create policy "listings_no_write" on public.listings for all using (false) with check (false);
create policy "trades_select" on public.trades for select using (
  public.is_active_member(class_id) or public.is_class_teacher(class_id)
);
create policy "trades_no_write" on public.trades for all using (false) with check (false);
create policy "financial_select" on public.financial_transactions for select using (
  exists (select 1 from public.firms f where f.id = financial_transactions.firm_id
    and (public.is_active_member(f.class_id) or public.is_class_teacher(f.class_id)))
);
create policy "financial_no_write" on public.financial_transactions for all using (false) with check (false);
create policy "movements_select" on public.inventory_movements for select using (
  exists (select 1 from public.firms f where f.id = inventory_movements.firm_id
    and (public.is_active_member(f.class_id) or public.is_class_teacher(f.class_id)))
);
create policy "movements_no_write" on public.inventory_movements for all using (false) with check (false);
create policy "idempotency_select" on public.idempotency_keys for select using (user_id = auth.uid());
create policy "idempotency_no_write" on public.idempotency_keys for all using (false) with check (false);

revoke all on all tables in schema public from public, authenticated, anon;
grant usage on schema public to authenticated;
grant select on public.profiles, public.classes, public.class_members, public.firms,
  public.products, public.inventory, public.listings, public.trades,
  public.financial_transactions, public.inventory_movements, public.idempotency_keys
  to authenticated;
