-- Safer loyalty cards.
--   * Phone number per sector: required (barber, beauty, gym), not asked
--     (cafe, bakery) or optional (others); the owner can change it.
--   * Name + phone never open a card any more: they are not a secret. A lost
--     card becomes a request the owner approves face to face; the new phone
--     gets the card and the old one loses it.
--   * One phone number = one card per shop (no duplicate cards).
--   * A free reward is no longer taken automatically: the scan asks, the
--     owner confirms (or refuses) on his screen.

alter table public.nfc_customers alter column phone drop not null;
-- Points shops have goals above 50 (the shop's own check allows up to 10000).
alter table public.nfc_customers drop constraint if exists nfc_customers_goal_check;
alter table public.nfc_customers add constraint nfc_customers_goal_check
  check (goal is null or goal between 1 and 10000);
alter table public.nfc_customers add column if not exists claim_at timestamptz;

alter table public.nfc_businesses add column if not exists phone_policy text;
alter table public.nfc_businesses drop constraint if exists nfc_businesses_phone_policy_check;
alter table public.nfc_businesses add constraint nfc_businesses_phone_policy_check
  check (phone_policy is null or phone_policy in ('required', 'optional', 'none'));

create or replace function nfc_private.phone_policy(b public.nfc_businesses)
returns text language sql stable set search_path = '' as $$
  select coalesce(b.phone_policy,
    case when b.industry in ('barber', 'beauty', 'gym') then 'required'
         when b.industry in ('cafe', 'bakery') then 'none'
         else 'optional' end);
$$;

create table if not exists public.nfc_recoveries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.nfc_businesses(id) on delete cascade,
  customer_id uuid not null references public.nfc_customers(id) on delete cascade,
  token_hash text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index if not exists nfc_recoveries_shop on public.nfc_recoveries(business_id, status, created_at desc);
create index if not exists nfc_recoveries_customer on public.nfc_recoveries(customer_id, created_at desc);
alter table public.nfc_recoveries enable row level security;
revoke all on public.nfc_recoveries from anon, authenticated;

create or replace function nfc_private.customer_json(c public.nfc_customers, goal integer)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'phone', c.phone, 'stamps', c.stamps,
    'goal', coalesce(c.goal, goal), 'reward', c.reward,
    'next_free', c.stamps >= coalesce(c.goal, goal),
    'old_rule', c.goal is not null and c.goal <> goal,
    'total_visits', c.total_visits, 'rewards', c.rewards,
    'last_visit_at', c.last_visit_at, 'coming_at', c.coming_at, 'arrived_at', c.arrived_at,
    'called_at', c.called_at,
    'called', c.called_at is not null and c.called_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.called_at),
    'coming', c.coming_at is not null and c.coming_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.coming_at)
              and (c.called_at is null or c.coming_at >= c.called_at or c.called_at < now() - interval '3 hours'),
    'arrived', c.arrived_at is not null and c.arrived_at > now() - interval '3 hours'
               and (c.last_visit_at is null or c.last_visit_at < c.arrived_at),
    -- Waiting for the owner to confirm the free reward (30 minutes).
    'claim', c.claim_at is not null and c.claim_at > now() - interval '30 minutes'
             and c.stamps >= coalesce(c.goal, goal),
    'claim_at', c.claim_at,
    'booking', (select jsonb_build_object('id', k.id, 'starts_at', k.starts_at, 'service', k.service_name)
                  from public.nfc_bookings k
                 where k.customer_id = c.id and k.status = 'booked' and k.starts_at > now() - interval '2 hours'
                 order by k.starts_at limit 1),
    'vehicle_type', c.vehicle_type, 'dob', c.dob, 'expiry_date', c.expiry_date,
    'expired', c.expiry_date is not null and c.expiry_date < current_date,
    'birthday', nfc_private.is_birthday(c, null),
    'created_at', c.created_at);
$$;

-- Joining: the phone follows the shop's rule; a number already used here never
-- gives its card away ('exists' -> the customer asks the owner instead).
create or replace function public.nfc_customer_join(target_slug text, customer_name text, customer_phone text, code text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; token text; norm_phone text; policy text;
        visit jsonb := null;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'shop'); end if;
  policy := nfc_private.phone_policy(b);
  if length(trim(coalesce(customer_name, ''))) not between 2 and 80 then
    return jsonb_build_object('ok', false, 'error', 'name');
  end if;
  norm_phone := nullif(nfc_private.normalize_phone(coalesce(customer_phone, '')), '');
  if norm_phone is not null and norm_phone !~ '^\+?[0-9]{6,20}$' then
    return jsonb_build_object('ok', false, 'error', 'phone');
  end if;
  if policy = 'required' and norm_phone is null then
    return jsonb_build_object('ok', false, 'error', 'phone');
  end if;
  if norm_phone is not null and exists (
       select 1 from public.nfc_customers where business_id = b.id and phone = norm_phone) then
    return jsonb_build_object('ok', false, 'error', 'exists');
  end if;
  token := nfc_private.random_token();
  begin
    insert into public.nfc_customers(tenant_id, business_id, name, phone, token_hash, goal, reward)
    values (b.tenant_id, b.id, trim(customer_name), norm_phone, nfc_private.sha(token),
            b.loyalty_goal, b.loyalty_reward)
    returning * into c;
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'exists');
  end;
  if code is not null and code <> '' and nfc_private.code_valid(b.id, code) then
    visit := nfc_private.add_visit(b, c);
    select * into c from public.nfc_customers where id = c.id;
  end if;
  return jsonb_build_object('ok', true, 'token', token,
    'customer', nfc_private.customer_json(c, b.loyalty_goal), 'visit', visit);
end $$;

-- Lost card: asks the owner. Returns a request id and the token this phone
-- will use once the owner approves (until then the token opens nothing).
create or replace function public.nfc_customer_recover(target_slug text, customer_name text, customer_phone text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; token text; norm_phone text; rid uuid;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'shop'); end if;
  norm_phone := nfc_private.normalize_phone(coalesce(customer_phone, ''));
  select * into c from public.nfc_customers
   where business_id = b.id and phone = norm_phone
     and nfc_private.name_key(name) = nfc_private.name_key(customer_name);
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if (select count(*) from public.nfc_recoveries
       where customer_id = c.id and created_at > now() - interval '1 hour') >= 3 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  token := nfc_private.random_token();
  insert into public.nfc_recoveries(business_id, customer_id, token_hash)
  values (b.id, c.id, nfc_private.sha(token)) returning id into rid;
  return jsonb_build_object('ok', true, 'request', rid, 'token', token);
end $$;

create or replace function public.nfc_customer_recover_status(target_slug text, request uuid, token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; r public.nfc_recoveries; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false, 'error', 'request'); end if;
  select * into r from public.nfc_recoveries
   where id = request and business_id = b.id and token_hash = nfc_private.sha(token);
  if r.id is null then return jsonb_build_object('ok', false, 'error', 'request'); end if;
  if r.status = 'approved' then
    select * into c from public.nfc_customers where id = r.customer_id and token_hash = r.token_hash;
    if c.id is null then return jsonb_build_object('ok', true, 'status', 'rejected'); end if;
    return jsonb_build_object('ok', true, 'status', 'approved', 'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if r.status = 'pending' and r.created_at < now() - interval '2 hours' then
    return jsonb_build_object('ok', true, 'status', 'expired');
  end if;
  return jsonb_build_object('ok', true, 'status', r.status);
end $$;

-- Owner: approve (the new phone gets the card, the old one loses it) or refuse.
create or replace function public.nfc_shop_recovery_decide(target_slug text, session text, request uuid, approve boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; r public.nfc_recoveries;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  select * into r from public.nfc_recoveries
   where id = request and business_id = b.id and status = 'pending' for update;
  if r.id is null then return jsonb_build_object('ok', false, 'error', 'request'); end if;
  if approve then
    update public.nfc_customers set token_hash = r.token_hash where id = r.customer_id;
    update public.nfc_recoveries set status = 'rejected', decided_at = now()
     where customer_id = r.customer_id and status = 'pending' and id <> r.id;
  end if;
  update public.nfc_recoveries set status = case when approve then 'approved' else 'rejected' end, decided_at = now()
   where id = r.id;
  return jsonb_build_object('ok', true, 'customer_id', r.customer_id);
end $$;

-- Owner: confirm the free reward (counts the visit) or refuse it.
create or replace function public.nfc_shop_reward_decide(target_slug text, session text, customer uuid, approve boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; v jsonb;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  select * into c from public.nfc_customers where id = customer and business_id = b.id for update;
  if c.id is null or c.claim_at is null then return jsonb_build_object('ok', false, 'error', 'claim'); end if;
  update public.nfc_customers set claim_at = null where id = c.id returning * into c;
  if not approve then return jsonb_build_object('ok', true); end if;
  if c.stamps < coalesce(c.goal, b.loyalty_goal) then return jsonb_build_object('ok', false, 'error', 'claim'); end if;
  v := nfc_private.add_visit(b, c);
  return jsonb_build_object('ok', true) || v;
end $$;

-- A scan with a reward due asks the owner instead of taking it.
create or replace function public.nfc_customer_visit(target_slug text, token text, code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  select * into c from public.nfc_customers
   where business_id = b.id and token_hash = nfc_private.sha(token) for update;
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  if code is null or not nfc_private.code_valid(b.id, code) then
    return jsonb_build_object('ok', false, 'error', 'code',
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if c.last_visit_at is not null
     and c.last_visit_at > now() - make_interval(hours => b.loyalty_min_hours) then
    return jsonb_build_object('ok', false, 'error', 'too_soon',
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if c.expiry_date is not null and c.expiry_date < (now() at time zone b.timezone)::date then
    return jsonb_build_object('ok', false, 'error', 'expired',
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if c.stamps >= coalesce(c.goal, b.loyalty_goal) then
    update public.nfc_customers set claim_at = now() where id = c.id returning * into c;
    return jsonb_build_object('ok', true, 'claim', true,
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if b.loyalty_mode = 'points'
     and (b.pending_until is null or b.pending_until <= now()) then
    return jsonb_build_object('ok', false, 'error', 'no_amount',
      'customer', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  return jsonb_build_object('ok', true) || nfc_private.add_visit(b, c);
end $$;

-- Sector settings now also hold the phone rule.
create or replace function public.nfc_shop_sector_settings(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; m text; per integer; menu text; gift text; pp text;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  m := coalesce(nullif(settings ->> 'loyalty_mode', ''), b.loyalty_mode);
  per := coalesce((settings ->> 'points_per')::integer, b.points_per);
  menu := case when settings ? 'menu_url' then nullif(trim(settings ->> 'menu_url'), '') else b.menu_url end;
  gift := case when settings ? 'birthday_reward' then nullif(trim(settings ->> 'birthday_reward'), '') else b.birthday_reward end;
  pp := case when settings ? 'phone_policy' then nullif(settings ->> 'phone_policy', '') else b.phone_policy end;
  if m not in ('visits', 'points') then return jsonb_build_object('ok', false, 'error', 'mode'); end if;
  if per not between 1 and 1000 then return jsonb_build_object('ok', false, 'error', 'points_per'); end if;
  if menu is not null and (menu !~ '^https://' or length(menu) > 500) then return jsonb_build_object('ok', false, 'error', 'menu'); end if;
  if length(gift) > 80 then return jsonb_build_object('ok', false, 'error', 'gift'); end if;
  if pp is not null and pp not in ('required', 'optional', 'none') then return jsonb_build_object('ok', false, 'error', 'phone_policy'); end if;
  update public.nfc_businesses set loyalty_mode = m, points_per = per,
         loyalty_goal = case when m = 'visits' and loyalty_goal > 50 then 5 else loyalty_goal end,
         menu_url = menu, birthday_reward = gift, phone_policy = pp
   where id = b.id;
  return jsonb_build_object('ok', true);
end $$;

-- Public shop json and dashboard: phone rule, pending card requests.
do $$
declare d text;
begin
  d := pg_get_functiondef('nfc_private.shop_public_json(public.nfc_businesses)'::regprocedure);
  d := replace(d, '''card_background'', b.card_background,',
                  '''card_background'', b.card_background, ''phone_policy'', nfc_private.phone_policy(b),');
  if d not like '%phone_policy%' then raise exception 'shop_public_json patch failed'; end if;
  execute d;

  d := pg_get_functiondef('public.nfc_shop_dashboard(text,text)'::regprocedure);
  d := replace(d, '''stats'', jsonb_build_object(',
'''recoveries'', case when b.suspended then ''[]''::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object(''id'', r.id, ''customer_id'', c.id, ''name'', c.name, ''phone'', c.phone,
        ''stamps'', c.stamps, ''goal'', coalesce(c.goal, b.loyalty_goal), ''created_at'', r.created_at) order by r.created_at)
      from public.nfc_recoveries r join public.nfc_customers c on c.id = r.customer_id
      where r.business_id = b.id and r.status = ''pending'' and r.created_at > now() - interval ''2 hours''), ''[]''::jsonb) end,
    ''stats'', jsonb_build_object(');
  if d not like '%recoveries%' then raise exception 'dashboard patch failed'; end if;
  execute d;
end $$;

revoke all on function public.nfc_customer_recover(text, text, text) from public;
revoke all on function public.nfc_customer_recover_status(text, uuid, text) from public;
revoke all on function public.nfc_shop_recovery_decide(text, text, uuid, boolean) from public;
revoke all on function public.nfc_shop_reward_decide(text, text, uuid, boolean) from public;
grant execute on function public.nfc_customer_recover(text, text, text) to anon, authenticated;
grant execute on function public.nfc_customer_recover_status(text, uuid, text) to anon, authenticated;
grant execute on function public.nfc_shop_recovery_decide(text, text, uuid, boolean) to anon, authenticated;
grant execute on function public.nfc_shop_reward_decide(text, text, uuid, boolean) to anon, authenticated;
