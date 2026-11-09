-- Loyalty programme: shops (businesses with loyalty enabled), customers,
-- visits, a rotating QR code and a browser dashboard for the shop owner.
--
-- Anti-fraud: the shop screen shows a QR whose code is an HMAC of the current
-- 30-second window with a per-shop secret. A visit is only accepted with the
-- current or previous window's code, and one customer can collect at most one
-- visit per shop every `min_hours` hours.

-- 1. Shop settings on nfc_businesses ---------------------------------------
alter table public.nfc_businesses
  add column if not exists shop_slug text,
  add column if not exists loyalty_enabled boolean not null default false,
  add column if not exists loyalty_goal int not null default 5,
  add column if not exists loyalty_reward text not null default 'زيارة مجانية',
  add column if not exists loyalty_min_hours int not null default 4,
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists banners jsonb not null default '[]'::jsonb,
  add column if not exists created_by uuid references auth.users(id) on delete set null;

do $$ begin
  alter table public.nfc_businesses add constraint nfc_businesses_shop_slug_key unique (shop_slug);
exception when duplicate_object or duplicate_table then null; end $$;
alter table public.nfc_businesses drop constraint if exists nfc_businesses_shop_rules;
alter table public.nfc_businesses add constraint nfc_businesses_shop_rules check (
  (shop_slug is null or (length(shop_slug) between 3 and 63
     and shop_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'))
  and loyalty_goal between 1 and 50
  and loyalty_min_hours between 0 and 72
  and length(loyalty_reward) between 1 and 120
  and (phone is null or length(phone) <= 40)
  and (address is null or length(address) <= 200)
  and jsonb_typeof(banners) = 'array' and jsonb_array_length(banners) <= 5
);

-- Who created a business (agents only see their own shops in the app list).
create or replace function nfc_private.stamp_business_creator()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then new.created_by := coalesce(auth.uid(), new.created_by);
  else new.created_by := old.created_by; end if;
  return new;
end; $$;
drop trigger if exists nfc_business_creator on public.nfc_businesses;
create trigger nfc_business_creator before insert or update on public.nfc_businesses
  for each row execute function nfc_private.stamp_business_creator();

-- Secrets never leave the private schema.
create table if not exists nfc_private.shop_secrets (
  business_id uuid primary key references public.nfc_businesses(id) on delete cascade,
  qr_secret bytea not null default extensions.gen_random_bytes(32),
  owner_pass_hash text,
  failed_attempts int not null default 0,
  locked_until timestamptz
);
create table if not exists nfc_private.shop_sessions (
  token_hash text primary key,
  business_id uuid not null references public.nfc_businesses(id) on delete cascade,
  expires_at timestamptz not null default now() + interval '30 days',
  created_at timestamptz not null default now()
);
revoke all on nfc_private.shop_secrets, nfc_private.shop_sessions from public, anon, authenticated;

-- 2. Customers and visits --------------------------------------------------
create table if not exists public.nfc_customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
  business_id uuid not null references public.nfc_businesses(id) on delete cascade,
  name text not null check (length(name) between 1 and 80),
  phone text not null check (phone ~ '^\+?[0-9]{6,20}$'),
  token_hash text,
  stamps int not null default 0,
  total_visits int not null default 0,
  rewards int not null default 0,
  last_visit_at timestamptz,
  coming_at timestamptz,
  created_at timestamptz not null default now(),
  unique (business_id, phone)
);
create index if not exists nfc_customers_business on public.nfc_customers(business_id);
create unique index if not exists nfc_customers_token on public.nfc_customers(token_hash);

create table if not exists public.nfc_visits (
  id bigint generated always as identity primary key,
  tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
  business_id uuid not null references public.nfc_businesses(id) on delete cascade,
  customer_id uuid not null references public.nfc_customers(id) on delete cascade,
  free boolean not null default false,
  voided boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists nfc_visits_business on public.nfc_visits(business_id, created_at desc);

alter table public.nfc_customers enable row level security;
alter table public.nfc_visits enable row level security;
revoke all on public.nfc_customers, public.nfc_visits from anon;
grant select on public.nfc_customers, public.nfc_visits to authenticated;
drop policy if exists customer_read on public.nfc_customers;
create policy customer_read on public.nfc_customers for select to authenticated
  using (nfc_private.has_role(tenant_id) or nfc_private.is_super_admin(auth.uid()));
drop policy if exists visit_read on public.nfc_visits;
create policy visit_read on public.nfc_visits for select to authenticated
  using (nfc_private.has_role(tenant_id) or nfc_private.is_super_admin(auth.uid()));

-- 3. Helpers ---------------------------------------------------------------
create or replace function nfc_private.shop_by_slug(target_slug text)
returns public.nfc_businesses language sql stable security definer set search_path = '' as $$
  select * from public.nfc_businesses
  where shop_slug = lower(trim(target_slug)) and loyalty_enabled = true;
$$;

create or replace function nfc_private.random_token()
returns text language sql volatile set search_path = '' as $$
  select encode(extensions.gen_random_bytes(24), 'hex');
$$;

create or replace function nfc_private.sha(value text)
returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(value, 'sha256'), 'hex');
$$;

-- Code for a 30-second window: 8 hex chars of HMAC-SHA256.
create or replace function nfc_private.shop_code(business uuid, window_no bigint)
returns text language sql stable security definer set search_path = '' as $$
  select left(encode(extensions.hmac(window_no::text::bytea, s.qr_secret, 'sha256'), 'hex'), 8)
  from nfc_private.shop_secrets s where s.business_id = business;
$$;

create or replace function nfc_private.current_window()
returns bigint language sql stable set search_path = '' as $$
  select floor(extract(epoch from now()) / 30)::bigint;
$$;

create or replace function nfc_private.normalize_phone(raw text)
returns text language sql immutable set search_path = '' as $$
  select case
    when left(trim(coalesce(raw, '')), 1) = '+'
      then '+' || regexp_replace(raw, '[^0-9]', '', 'g')
    when left(regexp_replace(coalesce(raw, ''), '[^0-9]', '', 'g'), 2) = '00'
      then '+' || substr(regexp_replace(raw, '[^0-9]', '', 'g'), 3)
    else regexp_replace(coalesce(raw, ''), '[^0-9]', '', 'g')
  end;
$$;

create or replace function nfc_private.shop_session(target_slug text, session text)
returns public.nfc_businesses language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or session is null then return null; end if;
  if not exists (select 1 from nfc_private.shop_sessions s
                 where s.token_hash = nfc_private.sha(session)
                   and s.business_id = b.id and s.expires_at > now()) then
    return null;
  end if;
  return b;
end; $$;

create or replace function nfc_private.customer_json(c public.nfc_customers, goal int)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'phone', c.phone, 'stamps', c.stamps,
    'goal', goal, 'next_free', c.stamps >= goal,
    'total_visits', c.total_visits, 'rewards', c.rewards,
    'last_visit_at', c.last_visit_at, 'coming_at', c.coming_at,
    'coming', c.coming_at is not null and c.coming_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.coming_at),
    'created_at', c.created_at);
$$;

-- Records one visit (free when the customer already has `goal` stamps).
create or replace function nfc_private.add_visit(b public.nfc_businesses, c public.nfc_customers)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare is_free boolean; updated public.nfc_customers;
begin
  is_free := c.stamps >= b.loyalty_goal;
  insert into public.nfc_visits(tenant_id, business_id, customer_id, free)
  values (b.tenant_id, b.id, c.id, is_free);
  update public.nfc_customers
     set stamps = case when is_free then 0 else stamps + 1 end,
         rewards = rewards + case when is_free then 1 else 0 end,
         total_visits = total_visits + 1,
         last_visit_at = now()
   where id = c.id
   returning * into updated;
  return jsonb_build_object('free', is_free,
    'customer', nfc_private.customer_json(updated, b.loyalty_goal));
end; $$;

create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'banners', b.banners);
$$;

-- 4. Public (customer) RPCs ------------------------------------------------
create or replace function public.nfc_shop_public(target_slug text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return null; end if;
  return nfc_private.shop_public_json(b);
end; $$;

-- Join (or re-link this phone on a new device). With a valid code the first
-- visit is recorded at once.
create or replace function public.nfc_customer_join(
  target_slug text, customer_name text, customer_phone text, code text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; token text; norm_phone text;
        w bigint; visit jsonb := null;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'shop'); end if;
  norm_phone := nfc_private.normalize_phone(customer_phone);
  if norm_phone !~ '^\+?[0-9]{6,20}$' then return jsonb_build_object('ok', false, 'error', 'phone'); end if;
  if length(trim(coalesce(customer_name, ''))) not between 1 and 80 then
    return jsonb_build_object('ok', false, 'error', 'name');
  end if;
  token := nfc_private.random_token();
  insert into public.nfc_customers(tenant_id, business_id, name, phone, token_hash)
  values (b.tenant_id, b.id, trim(customer_name), norm_phone, nfc_private.sha(token))
  on conflict (business_id, phone) do update
    set token_hash = excluded.token_hash
  returning * into c;
  if code is not null and code <> '' then
    w := nfc_private.current_window();
    if lower(code) in (nfc_private.shop_code(b.id, w), nfc_private.shop_code(b.id, w - 1))
       and (c.last_visit_at is null
            or c.last_visit_at < now() - make_interval(hours => b.loyalty_min_hours)) then
      visit := nfc_private.add_visit(b, c);
      select * into c from public.nfc_customers where id = c.id;
    end if;
  end if;
  return jsonb_build_object('ok', true, 'token', token,
    'customer', nfc_private.customer_json(c, b.loyalty_goal), 'visit', visit);
end; $$;

create or replace function public.nfc_customer_card(target_slug text, token text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false); end if;
  select * into c from public.nfc_customers
   where business_id = b.id and token_hash = nfc_private.sha(token);
  if c.id is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end; $$;

create or replace function public.nfc_customer_visit(target_slug text, token text, code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; w bigint;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  select * into c from public.nfc_customers
   where business_id = b.id and token_hash = nfc_private.sha(token) for update;
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  w := nfc_private.current_window();
  if code is null or lower(code) not in (nfc_private.shop_code(b.id, w), nfc_private.shop_code(b.id, w - 1)) then
    return jsonb_build_object('ok', false, 'error', 'code',
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if c.last_visit_at is not null
     and c.last_visit_at > now() - make_interval(hours => b.loyalty_min_hours) then
    return jsonb_build_object('ok', false, 'error', 'too_soon',
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  return jsonb_build_object('ok', true) || nfc_private.add_visit(b, c);
end; $$;

create or replace function public.nfc_customer_coming(target_slug text, token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false); end if;
  update public.nfc_customers set coming_at = now()
   where business_id = b.id and token_hash = nfc_private.sha(token)
     and (coming_at is null or coming_at < now() - interval '2 minutes')
   returning * into c;
  if c.id is null then
    select * into c from public.nfc_customers
     where business_id = b.id and token_hash = nfc_private.sha(token);
  end if;
  if c.id is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end; $$;

-- 5. Shop owner RPCs -------------------------------------------------------
create or replace function public.nfc_shop_login(target_slug text, password text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; s nfc_private.shop_secrets; token text;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  select * into s from nfc_private.shop_secrets where business_id = b.id for update;
  if s.business_id is null or s.owner_pass_hash is null then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  if s.locked_until is not null and s.locked_until > now() then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;
  if password is null or s.owner_pass_hash <> extensions.crypt(password, s.owner_pass_hash) then
    update nfc_private.shop_secrets
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end
     where business_id = b.id;
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update nfc_private.shop_secrets set failed_attempts = 0, locked_until = null where business_id = b.id;
  delete from nfc_private.shop_sessions where expires_at < now();
  token := nfc_private.random_token();
  insert into nfc_private.shop_sessions(token_hash, business_id) values (nfc_private.sha(token), b.id);
  return jsonb_build_object('ok', true, 'session', token);
end; $$;

create or replace function public.nfc_shop_logout(target_slug text, session text)
returns void language sql security definer set search_path = '' as $$
  delete from nfc_private.shop_sessions where token_hash = nfc_private.sha(session);
$$;

create or replace function public.nfc_shop_qr(target_slug text, session text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses; w bigint;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false); end if;
  w := nfc_private.current_window();
  return jsonb_build_object('ok', true, 'code', nfc_private.shop_code(b.id, w),
    'expires_in', 30 - (floor(extract(epoch from now()))::bigint % 30));
end; $$;

create or replace function public.nfc_shop_dashboard(target_slug text, session text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true,
    'shop', nfc_private.shop_public_json(b) || jsonb_build_object('min_hours', b.loyalty_min_hours),
    'customers', coalesce((
      select jsonb_agg(nfc_private.customer_json(c, b.loyalty_goal)
        order by (c.coming_at is not null and c.coming_at > now() - interval '3 hours'
                  and (c.last_visit_at is null or c.last_visit_at < c.coming_at)) desc,
                 c.last_visit_at desc nulls last, c.created_at desc)
      from public.nfc_customers c where c.business_id = b.id), '[]'::jsonb),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object('id', v.id, 'customer', c.name,
        'free', v.free, 'voided', v.voided, 'created_at', v.created_at)
        order by v.created_at desc)
      from (select * from public.nfc_visits where business_id = b.id
            order by created_at desc limit 50) v
      join public.nfc_customers c on c.id = v.customer_id), '[]'::jsonb),
    'stats', jsonb_build_object(
      'customers', (select count(*) from public.nfc_customers where business_id = b.id),
      'visits_today', (select count(*) from public.nfc_visits
                        where business_id = b.id and not voided
                          and created_at > date_trunc('day', now())),
      'rewards', (select count(*) from public.nfc_visits
                   where business_id = b.id and free and not voided)));
end; $$;

create or replace function public.nfc_shop_update(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; new_banners jsonb; item jsonb;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  new_banners := coalesce(settings -> 'banners', b.banners);
  if jsonb_typeof(new_banners) <> 'array' or jsonb_array_length(new_banners) > 5 then
    return jsonb_build_object('ok', false, 'error', 'banners');
  end if;
  for item in select * from jsonb_array_elements(new_banners) loop
    if jsonb_typeof(item) <> 'string'
       or (item #>> '{}') !~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$' then
      return jsonb_build_object('ok', false, 'error', 'banners');
    end if;
  end loop;
  update public.nfc_businesses set
    name = coalesce(nullif(trim(settings ->> 'name'), ''), name),
    phone = case when settings ? 'phone' then nullif(trim(settings ->> 'phone'), '') else phone end,
    address = case when settings ? 'address' then nullif(trim(settings ->> 'address'), '') else address end,
    loyalty_goal = coalesce((settings ->> 'goal')::int, loyalty_goal),
    loyalty_reward = coalesce(nullif(trim(settings ->> 'reward'), ''), loyalty_reward),
    banners = new_banners
  where id = b.id;
  return jsonb_build_object('ok', true);
exception when check_violation or invalid_text_representation then
  return jsonb_build_object('ok', false, 'error', 'invalid');
end; $$;

create or replace function public.nfc_shop_void_visit(target_slug text, session text, visit_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; v public.nfc_visits;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false); end if;
  update public.nfc_visits set voided = true
   where id = visit_id and business_id = b.id and not voided
   returning * into v;
  if v.id is null then return jsonb_build_object('ok', false); end if;
  update public.nfc_customers set
    stamps = case when v.free then b.loyalty_goal else greatest(stamps - 1, 0) end,
    rewards = greatest(rewards - case when v.free then 1 else 0 end, 0),
    total_visits = greatest(total_visits - 1, 0)
  where id = v.customer_id;
  return jsonb_build_object('ok', true);
end; $$;

-- Session check for the banner upload edge function (service role only).
create or replace function public.nfc_shop_session_check(target_slug text, session text)
returns uuid language sql stable security definer set search_path = '' as $$
  select (nfc_private.shop_session(target_slug, session)).id;
$$;

-- 6. Staff (app) RPCs ------------------------------------------------------
-- Turns a business into a loyalty shop and/or sets a new owner password.
create or replace function public.nfc_shop_setup(
  target_business uuid, slug text, goal int, reward text, owner_password text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target_business;
  if b.id is null then raise exception 'Business not found'; end if;
  if not (nfc_private.has_role(b.tenant_id, array['owner','admin','editor'])
          or nfc_private.is_super_admin(auth.uid())) then
    raise exception 'Not authorized';
  end if;
  if exists (select 1 from public.nfc_businesses
             where shop_slug = lower(trim(slug)) and id <> b.id) then
    raise exception 'Slug already used' using errcode = '23505';
  end if;
  update public.nfc_businesses
     set shop_slug = lower(trim(slug)), loyalty_enabled = true,
         loyalty_goal = coalesce(goal, loyalty_goal),
         loyalty_reward = coalesce(nullif(trim(reward), ''), loyalty_reward)
   where id = b.id;
  insert into nfc_private.shop_secrets(business_id) values (b.id) on conflict do nothing;
  if owner_password is not null and owner_password <> '' then
    if length(owner_password) not between 6 and 72 then
      raise exception 'Password must be 6-72 characters';
    end if;
    update nfc_private.shop_secrets
       set owner_pass_hash = extensions.crypt(owner_password, extensions.gen_salt('bf', 8)),
           failed_attempts = 0, locked_until = null
     where business_id = b.id;
    delete from nfc_private.shop_sessions where business_id = b.id;
  end if;
end; $$;

create or replace function public.nfc_shop_disable(target_business uuid, disabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target_business;
  if b.id is null then raise exception 'Business not found'; end if;
  if not (nfc_private.has_role(b.tenant_id, array['owner','admin'])
          or nfc_private.is_super_admin(auth.uid())) then
    raise exception 'Not authorized';
  end if;
  update public.nfc_businesses set loyalty_enabled = not disabled where id = b.id;
  if disabled then delete from nfc_private.shop_sessions where business_id = b.id; end if;
end; $$;

-- Shops list for the app with counters (and, for super admins, all shops).
create or replace function public.nfc_shops_overview(workspace_id uuid default null)
returns table(id uuid, tenant_id uuid, name text, shop_slug text, loyalty_enabled boolean,
              goal int, reward text, phone text, created_by uuid, creator text,
              customers bigint, visits bigint, visits_7d bigint, has_password boolean,
              created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.id, b.tenant_id, b.name, b.shop_slug, b.loyalty_enabled, b.loyalty_goal,
         b.loyalty_reward, b.phone, b.created_by,
         coalesce(w.display_name, split_part(u.email, '@', 1)),
         (select count(*) from public.nfc_customers c where c.business_id = b.id),
         (select count(*) from public.nfc_visits v where v.business_id = b.id and not v.voided),
         (select count(*) from public.nfc_visits v where v.business_id = b.id and not v.voided
            and v.created_at > now() - interval '7 days'),
         exists (select 1 from nfc_private.shop_secrets s
                 where s.business_id = b.id and s.owner_pass_hash is not null),
         b.created_at
  from public.nfc_businesses b
  left join auth.users u on u.id = b.created_by
  left join public.nfc_workers w on w.id = b.created_by
  where b.shop_slug is not null
    and ((workspace_id is not null and b.tenant_id = workspace_id
          and nfc_private.has_role(workspace_id))
         or (workspace_id is null and nfc_private.is_super_admin(auth.uid())))
  order by b.created_at desc;
$$;

revoke all on function
  public.nfc_shop_public(text), public.nfc_customer_join(text, text, text, text),
  public.nfc_customer_card(text, text), public.nfc_customer_visit(text, text, text),
  public.nfc_customer_coming(text, text), public.nfc_shop_login(text, text),
  public.nfc_shop_logout(text, text), public.nfc_shop_qr(text, text),
  public.nfc_shop_dashboard(text, text), public.nfc_shop_update(text, text, jsonb),
  public.nfc_shop_void_visit(text, text, bigint), public.nfc_shop_session_check(text, text),
  public.nfc_shop_setup(uuid, text, int, text, text), public.nfc_shop_disable(uuid, boolean),
  public.nfc_shops_overview(uuid)
from public;
grant execute on function
  public.nfc_shop_public(text), public.nfc_customer_join(text, text, text, text),
  public.nfc_customer_card(text, text), public.nfc_customer_visit(text, text, text),
  public.nfc_customer_coming(text, text), public.nfc_shop_login(text, text),
  public.nfc_shop_logout(text, text), public.nfc_shop_qr(text, text),
  public.nfc_shop_dashboard(text, text), public.nfc_shop_update(text, text, jsonb),
  public.nfc_shop_void_visit(text, text, bigint)
to anon, authenticated;
grant execute on function public.nfc_shop_session_check(text, text) to service_role;
grant execute on function
  public.nfc_shop_setup(uuid, text, int, text, text), public.nfc_shop_disable(uuid, boolean),
  public.nfc_shops_overview(uuid)
to authenticated;
