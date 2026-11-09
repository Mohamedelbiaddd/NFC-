-- Sector logic.
--   Restaurants / pizzerias: points by amount. The owner types the bill on his
--   dashboard; the next scan of his QR (within 3 minutes) adds
--   floor(amount / points_per) points. The reward comes at `loyalty_goal` points
--   and only the goal is spent, the rest stays.
--   Car wash: vehicle type per customer; "last wash" is the last visit.
--   Gym: monthly subscription (expiry_date) renewed by the owner; a scan with an
--   expired subscription is refused. Each scan is an attendance.
--   Everyone: optional date of birth; on the birthday the Wallet card shows the
--   shop's birthday gift and Google sends a notification (daily job).

alter table public.nfc_businesses
  add column if not exists loyalty_mode text not null default 'visits',
  add column if not exists points_per integer not null default 10,
  add column if not exists menu_url text,
  add column if not exists birthday_reward text,
  add column if not exists pending_points integer,
  add column if not exists pending_amount numeric(10,2),
  add column if not exists pending_until timestamptz;

alter table public.nfc_businesses drop constraint if exists nfc_businesses_loyalty_mode_check;
alter table public.nfc_businesses add constraint nfc_businesses_loyalty_mode_check
  check (loyalty_mode in ('visits', 'points') and points_per between 1 and 1000
         and (menu_url is null or (menu_url ~ '^https://' and length(menu_url) <= 500))
         and (birthday_reward is null or length(birthday_reward) <= 80));

alter table public.nfc_customers
  add column if not exists vehicle_type text,
  add column if not exists dob date,
  add column if not exists expiry_date date,
  add column if not exists wallet_lang text,
  add column if not exists birthday_year integer;

alter table public.nfc_customers drop constraint if exists nfc_customers_sector_check;
alter table public.nfc_customers add constraint nfc_customers_sector_check
  check ((vehicle_type is null or vehicle_type in ('small', 'suv', '4x4'))
         and (dob is null or dob between date '1900-01-01' and current_date)
         and (wallet_lang is null or wallet_lang in ('ar', 'fr', 'en')));

-- A new pizzeria / snack counts points by amount.
create or replace function nfc_private.apply_sector_theme()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.theme is null or new.theme = 'navy' then
      new.theme := nfc_private.sector_theme(new.industry);
    end if;
    if new.industry = 'snack' and new.loyalty_mode = 'visits' then
      new.loyalty_mode := 'points';
      if new.loyalty_goal <= 10 then new.loyalty_goal := 50; end if;
    end if;
  elsif new.industry is distinct from old.industry
        and new.theme = old.theme
        and old.theme = nfc_private.sector_theme(old.industry) then
    new.theme := nfc_private.sector_theme(new.industry);
  end if;
  return new;
end $$;

-- Is today the customer's birthday (in the shop's time zone)?
create or replace function nfc_private.is_birthday(c public.nfc_customers, tz text)
returns boolean language sql stable set search_path = '' as $$
  select c.dob is not null
     and to_char(c.dob, 'MM-DD') = to_char((now() at time zone coalesce(tz, 'Africa/Casablanca'))::date, 'MM-DD');
$$;

create or replace function nfc_private.customer_json(c public.nfc_customers, goal integer)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'phone', c.phone, 'stamps', c.stamps,
    'goal', coalesce(c.goal, goal), 'reward', c.reward,
    'next_free', c.stamps >= coalesce(c.goal, goal),
    'old_rule', c.goal is not null and c.goal <> goal,
    'total_visits', c.total_visits, 'rewards', c.rewards,
    'last_visit_at', c.last_visit_at, 'coming_at', c.coming_at, 'arrived_at', c.arrived_at,
    'coming', c.coming_at is not null and c.coming_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.coming_at),
    'arrived', c.arrived_at is not null and c.arrived_at > now() - interval '3 hours'
               and (c.last_visit_at is null or c.last_visit_at < c.arrived_at),
    'vehicle_type', c.vehicle_type, 'dob', c.dob, 'expiry_date', c.expiry_date,
    'expired', c.expiry_date is not null and c.expiry_date < current_date,
    'birthday', nfc_private.is_birthday(c, null),
    'created_at', c.created_at);
$$;

-- Visits mode: +1 stamp (unchanged). Points mode: + the pending amount's points.
create or replace function nfc_private.add_visit(b public.nfc_businesses, c public.nfc_customers)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare is_free boolean; updated public.nfc_customers; g integer; pts integer := 1; amount numeric;
begin
  g := coalesce(c.goal, b.loyalty_goal);
  is_free := c.stamps >= g;
  if b.loyalty_mode = 'points' then
    if b.pending_until is not null and b.pending_until > now() then
      pts := coalesce(b.pending_points, 0);
      amount := b.pending_amount;
    else
      pts := 0;
    end if;
    update public.nfc_businesses set pending_points = null, pending_amount = null, pending_until = null
     where id = b.id;
  end if;
  insert into public.nfc_visits(tenant_id, business_id, customer_id, free)
  values (b.tenant_id, b.id, c.id, is_free);
  update public.nfc_customers
     set stamps = case
           when b.loyalty_mode = 'points' then (case when is_free then stamps - g else stamps end) + pts
           when is_free then 0 else stamps + 1 end,
         rewards = rewards + case when is_free then 1 else 0 end,
         goal = case when is_free then b.loyalty_goal else coalesce(goal, b.loyalty_goal) end,
         reward = case when is_free then b.loyalty_reward else coalesce(reward, b.loyalty_reward) end,
         total_visits = total_visits + 1,
         last_visit_at = now()
   where id = c.id
   returning * into updated;
  return jsonb_build_object('free', is_free, 'points', case when b.loyalty_mode = 'points' then pts end,
    'amount', amount, 'customer', nfc_private.customer_json(updated, b.loyalty_goal));
end $$;

-- Scans: a points shop needs an amount first (unless the reward is due);
-- a gym member with an expired subscription is refused.
do $$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_customer_visit(text,text,text)'::regprocedure);
  d := replace(d, '  return jsonb_build_object(''ok'', true) || nfc_private.add_visit(b, c);',
'  if c.expiry_date is not null and c.expiry_date < (now() at time zone b.timezone)::date then
    return jsonb_build_object(''ok'', false, ''error'', ''expired'',
      ''customer'', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  if b.loyalty_mode = ''points'' and c.stamps < coalesce(c.goal, b.loyalty_goal)
     and (b.pending_until is null or b.pending_until <= now()) then
    return jsonb_build_object(''ok'', false, ''error'', ''no_amount'',
      ''customer'', nfc_private.customer_json(c, b.loyalty_goal));
  end if;
  return jsonb_build_object(''ok'', true) || nfc_private.add_visit(b, c);');
  if d not like '%no_amount%' then raise exception 'visit patch failed'; end if;
  execute d;

  d := pg_get_functiondef('nfc_private.shop_public_json(public.nfc_businesses)'::regprocedure);
  d := replace(d, '''theme'', b.theme,', '''theme'', b.theme, ''loyalty_mode'', b.loyalty_mode, ''points_per'', b.points_per, ''menu_url'', b.menu_url, ''birthday_reward'', b.birthday_reward,');
  if d not like '%points_per%' then raise exception 'public json patch failed'; end if;
  execute d;
end $$;

-- Owner: the bill of the customer in front of him. The next scan gets it.
create or replace function public.nfc_shop_amount(target_slug text, session text, amount numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; pts integer;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  if b.loyalty_mode <> 'points' then return jsonb_build_object('ok', false, 'error', 'mode'); end if;
  if amount is null then
    update public.nfc_businesses set pending_points = null, pending_amount = null, pending_until = null where id = b.id;
    return jsonb_build_object('ok', true, 'cleared', true);
  end if;
  if amount <= 0 or amount > 100000 then return jsonb_build_object('ok', false, 'error', 'amount'); end if;
  pts := floor(amount / b.points_per);
  update public.nfc_businesses
     set pending_amount = round(amount, 2), pending_points = pts, pending_until = now() + interval '3 minutes'
   where id = b.id;
  return jsonb_build_object('ok', true, 'points', pts, 'amount', round(amount, 2),
    'until', now() + interval '3 minutes');
end $$;

-- Owner: per-customer sector data (vehicle, subscription renewal / expiry).
create or replace function public.nfc_shop_customer_set(target_slug text, session text, customer uuid, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; months integer; v text; today date;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  select * into c from public.nfc_customers where id = customer and business_id = b.id for update;
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'customer'); end if;
  today := (now() at time zone b.timezone)::date;
  if settings ? 'vehicle_type' then
    v := nullif(settings ->> 'vehicle_type', '');
    if v is not null and v not in ('small', 'suv', '4x4') then return jsonb_build_object('ok', false, 'error', 'vehicle'); end if;
    update public.nfc_customers set vehicle_type = v where id = c.id;
  end if;
  if settings ? 'renew_months' then
    months := (settings ->> 'renew_months')::integer;
    if months not between 1 and 24 then return jsonb_build_object('ok', false, 'error', 'months'); end if;
    update public.nfc_customers
       set expiry_date = greatest(today, coalesce(expiry_date, today)) + make_interval(months => months)
     where id = c.id;
  end if;
  if settings ? 'expiry_date' then
    update public.nfc_customers set expiry_date = nullif(settings ->> 'expiry_date', '')::date where id = c.id;
  end if;
  select * into c from public.nfc_customers where id = c.id;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end $$;

-- Owner: sector settings (mode, MAD per point, menu link, birthday gift).
create or replace function public.nfc_shop_sector_settings(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; m text; per integer; menu text; gift text;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  m := coalesce(nullif(settings ->> 'loyalty_mode', ''), b.loyalty_mode);
  per := coalesce((settings ->> 'points_per')::integer, b.points_per);
  menu := case when settings ? 'menu_url' then nullif(trim(settings ->> 'menu_url'), '') else b.menu_url end;
  gift := case when settings ? 'birthday_reward' then nullif(trim(settings ->> 'birthday_reward'), '') else b.birthday_reward end;
  if m not in ('visits', 'points') then return jsonb_build_object('ok', false, 'error', 'mode'); end if;
  if per not between 1 and 1000 then return jsonb_build_object('ok', false, 'error', 'points_per'); end if;
  if menu is not null and (menu !~ '^https://' or length(menu) > 500) then return jsonb_build_object('ok', false, 'error', 'menu'); end if;
  if length(gift) > 80 then return jsonb_build_object('ok', false, 'error', 'gift'); end if;
  update public.nfc_businesses set loyalty_mode = m, points_per = per, menu_url = menu, birthday_reward = gift
   where id = b.id;
  return jsonb_build_object('ok', true);
end $$;

-- Customer: optional date of birth and vehicle (own card only).
create or replace function public.nfc_customer_profile(target_slug text, token text, birth_date date, vehicle text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'shop'); end if;
  c := nfc_private.customer_by_token(b.id, token);
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  if birth_date is not null and (birth_date < date '1900-01-01' or birth_date > current_date) then
    return jsonb_build_object('ok', false, 'error', 'dob');
  end if;
  if vehicle is not null and vehicle not in ('small', 'suv', '4x4') then
    return jsonb_build_object('ok', false, 'error', 'vehicle');
  end if;
  update public.nfc_customers
     set dob = coalesce(public.nfc_customers.dob, birth_date),
         vehicle_type = coalesce(vehicle, public.nfc_customers.vehicle_type)
   where id = c.id
   returning * into c;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end $$;

revoke all on function public.nfc_shop_amount(text, text, numeric) from public;
revoke all on function public.nfc_shop_customer_set(text, text, uuid, jsonb) from public;
revoke all on function public.nfc_shop_sector_settings(text, text, jsonb) from public;
revoke all on function public.nfc_customer_profile(text, text, date, text) from public;
grant execute on function public.nfc_shop_amount(text, text, numeric) to anon, authenticated;
grant execute on function public.nfc_shop_customer_set(text, text, uuid, jsonb) to anon, authenticated;
grant execute on function public.nfc_shop_sector_settings(text, text, jsonb) to anon, authenticated;
grant execute on function public.nfc_customer_profile(text, text, date, text) to anon, authenticated;
