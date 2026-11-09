-- Appointments: the shop owner lists his services and turns booking on; a
-- customer picks a service, a day and a free time (from the weekly hours),
-- sees "my booking" and can cancel it. The owner sees and manages bookings
-- on his dashboard. Everything goes through security-definer RPCs.

alter table public.nfc_businesses
  add column if not exists booking_enabled boolean not null default false,
  add column if not exists services jsonb not null default '[]'::jsonb,
  add column if not exists slot_minutes int not null default 30,
  add column if not exists booking_capacity int not null default 1,
  add column if not exists timezone text not null default 'Africa/Casablanca';

alter table public.nfc_businesses drop constraint if exists nfc_businesses_slot_minutes_check;
alter table public.nfc_businesses add constraint nfc_businesses_slot_minutes_check check (slot_minutes in (10, 15, 20, 30, 45, 60));
alter table public.nfc_businesses drop constraint if exists nfc_businesses_booking_capacity_check;
alter table public.nfc_businesses add constraint nfc_businesses_booking_capacity_check check (booking_capacity between 1 and 20);

-- services: [{"id": "s1", "name": "حلاقة", "minutes": 30, "price": "50 درهم"}]
create or replace function nfc_private.valid_services(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb;
begin
  if jsonb_typeof(value) <> 'array' or jsonb_array_length(value) > 30 then return false; end if;
  for item in select * from jsonb_array_elements(value) loop
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'id', '') !~ '^[a-z0-9]{1,12}$'
       or length(trim(coalesce(item ->> 'name', ''))) not between 1 and 60
       or coalesce(item ->> 'minutes', '') !~ '^[0-9]{1,3}$'
       or (item ->> 'minutes')::int not between 5 and 480
       or length(coalesce(item ->> 'price', '')) > 30 then
      return false;
    end if;
  end loop;
  return true;
end; $$;

alter table public.nfc_businesses drop constraint if exists nfc_businesses_services_check;
alter table public.nfc_businesses add constraint nfc_businesses_services_check check (nfc_private.valid_services(services));

create table if not exists public.nfc_bookings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  business_id uuid not null references public.nfc_businesses(id) on delete cascade,
  customer_id uuid not null references public.nfc_customers(id) on delete cascade,
  service_id text not null,
  service_name text not null,
  service_minutes int not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'booked' check (status in ('booked', 'cancelled', 'done', 'no_show')),
  cancelled_by text check (cancelled_by in ('customer', 'owner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists nfc_bookings_shop_time on public.nfc_bookings (business_id, starts_at);
create index if not exists nfc_bookings_customer on public.nfc_bookings (customer_id, starts_at);
alter table public.nfc_bookings enable row level security;
revoke all on public.nfc_bookings from anon, authenticated;

create or replace function nfc_private.customer_by_token(business uuid, token text)
returns public.nfc_customers language sql stable security definer set search_path = '' as $$
  select * from public.nfc_customers
   where business_id = business and token is not null and token_hash = nfc_private.sha(token);
$$;

create or replace function nfc_private.booking_json(k public.nfc_bookings, tz text)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', k.id, 'service', k.service_name, 'minutes', k.service_minutes,
    'day', to_char(k.starts_at at time zone tz, 'YYYY-MM-DD'),
    'time', to_char(k.starts_at at time zone tz, 'HH24:MI'),
    'starts_at', k.starts_at, 'status', k.status, 'cancelled_by', k.cancelled_by,
    'upcoming', k.starts_at > now());
$$;

-- Free start times ("HH:MM", shop local time) for one service on one day.
create or replace function nfc_private.free_slots(b public.nfc_businesses, service jsonb, day date)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare idx int; hours jsonb; open_t time; close_t time; open_ts timestamp; close_ts timestamp;
        dur interval; step interval; t timestamp; s timestamptz; out text[] := '{}';
begin
  if b.week_hours is null or day < (now() at time zone b.timezone)::date
     or day > (now() at time zone b.timezone)::date + 30 then
    return out;
  end if;
  if b.closed_until is not null and day <= b.closed_until then return out; end if;
  idx := extract(isodow from day)::int - 1;
  hours := b.week_hours -> idx;
  if hours is null or jsonb_typeof(hours) <> 'object' then return out; end if;
  open_t := (hours ->> 'o')::time;
  close_t := (hours ->> 'c')::time;
  open_ts := day + open_t;
  close_ts := day + close_t;
  if close_ts <= open_ts then close_ts := close_ts + interval '1 day'; end if;
  dur := make_interval(mins => (service ->> 'minutes')::int);
  step := make_interval(mins => b.slot_minutes);
  t := open_ts;
  while t + dur <= close_ts loop
    s := t at time zone b.timezone;
    if s > now() + interval '10 minutes'
       and (select count(*) from public.nfc_bookings k
             where k.business_id = b.id and k.status = 'booked'
               and k.starts_at < s + dur and k.ends_at > s) < b.booking_capacity then
      out := out || to_char(t, 'HH24:MI');
    end if;
    t := t + step;
  end loop;
  return out;
end; $$;

create or replace function public.nfc_booking_slots(target_slug text, service_id text, day date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses; svc jsonb;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or not b.booking_enabled then return jsonb_build_object('ok', false, 'error', 'disabled'); end if;
  if b.week_hours is null then return jsonb_build_object('ok', false, 'error', 'no_hours'); end if;
  select e into svc from jsonb_array_elements(b.services) e where e ->> 'id' = service_id;
  if svc is null then return jsonb_build_object('ok', false, 'error', 'service'); end if;
  return jsonb_build_object('ok', true, 'day', day, 'slots', to_jsonb(nfc_private.free_slots(b, svc, day)));
end; $$;

create or replace function public.nfc_booking_create(target_slug text, token text, service_id text, day date, start_time text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; svc jsonb; s timestamptz; k public.nfc_bookings;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or not b.booking_enabled then return jsonb_build_object('ok', false, 'error', 'disabled'); end if;
  c := nfc_private.customer_by_token(b.id, token);
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  select e into svc from jsonb_array_elements(b.services) e where e ->> 'id' = service_id;
  if svc is null then return jsonb_build_object('ok', false, 'error', 'service'); end if;
  if start_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then return jsonb_build_object('ok', false, 'error', 'slot'); end if;
  -- One booking at a time per shop: serialise concurrent requests.
  perform pg_advisory_xact_lock(hashtext(b.id::text));
  if exists (select 1 from public.nfc_bookings
              where customer_id = c.id and status = 'booked' and starts_at > now()) then
    return jsonb_build_object('ok', false, 'error', 'has_booking');
  end if;
  if not (start_time = any (nfc_private.free_slots(b, svc, day))) then
    return jsonb_build_object('ok', false, 'error', 'taken');
  end if;
  s := (day + start_time::time) at time zone b.timezone;
  insert into public.nfc_bookings(tenant_id, business_id, customer_id, service_id, service_name, service_minutes, starts_at, ends_at)
  values (b.tenant_id, b.id, c.id, svc ->> 'id', svc ->> 'name', (svc ->> 'minutes')::int, s,
          s + make_interval(mins => (svc ->> 'minutes')::int))
  returning * into k;
  return jsonb_build_object('ok', true, 'booking', nfc_private.booking_json(k, b.timezone));
end; $$;

create or replace function public.nfc_booking_mine(target_slug text, token text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; k public.nfc_bookings;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'shop'); end if;
  c := nfc_private.customer_by_token(b.id, token);
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  select * into k from public.nfc_bookings
   where customer_id = c.id and status = 'booked' and starts_at > now() - interval '30 minutes'
   order by starts_at limit 1;
  if k.id is null then
    select * into k from public.nfc_bookings
     where customer_id = c.id and updated_at > now() - interval '2 days'
     order by updated_at desc limit 1;
  end if;
  return jsonb_build_object('ok', true, 'booking',
    case when k.id is null then null else nfc_private.booking_json(k, b.timezone) end);
end; $$;

create or replace function public.nfc_booking_cancel(target_slug text, token text, booking uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers; k public.nfc_bookings;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'shop'); end if;
  c := nfc_private.customer_by_token(b.id, token);
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'card'); end if;
  update public.nfc_bookings set status = 'cancelled', cancelled_by = 'customer', updated_at = now()
   where id = booking and customer_id = c.id and status = 'booked' and starts_at > now()
   returning * into k;
  if k.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  return jsonb_build_object('ok', true, 'booking', nfc_private.booking_json(k, b.timezone));
end; $$;

-- Owner side --------------------------------------------------------------
create or replace function public.nfc_shop_bookings(target_slug text, session text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  return jsonb_build_object('ok', true, 'bookings', coalesce((
    select jsonb_agg(nfc_private.booking_json(k, b.timezone)
             || jsonb_build_object('customer', c.name, 'phone', c.phone) order by k.starts_at)
      from public.nfc_bookings k join public.nfc_customers c on c.id = k.customer_id
     where k.business_id = b.id
       and k.starts_at > now() - interval '12 hours'
       and k.starts_at < now() + interval '31 days'
       and (k.status = 'booked' or k.updated_at > now() - interval '12 hours')), '[]'::jsonb));
end; $$;

create or replace function public.nfc_shop_booking_set(target_slug text, session text, booking uuid, new_status text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; k public.nfc_bookings;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  if new_status not in ('cancelled', 'done', 'no_show') then return jsonb_build_object('ok', false, 'error', 'status'); end if;
  update public.nfc_bookings
     set status = new_status, updated_at = now(),
         cancelled_by = case when new_status = 'cancelled' then 'owner' end
   where id = booking and business_id = b.id and status = 'booked'
   returning * into k;
  if k.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  return jsonb_build_object('ok', true);
end; $$;

create or replace function public.nfc_shop_booking_settings(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  if b.suspended then return jsonb_build_object('ok', false, 'error', 'suspended'); end if;
  if settings ? 'services' and not nfc_private.valid_services(settings -> 'services') then
    return jsonb_build_object('ok', false, 'error', 'services');
  end if;
  update public.nfc_businesses set
    booking_enabled = coalesce((settings ->> 'enabled')::boolean, booking_enabled),
    services = coalesce(settings -> 'services', services),
    slot_minutes = coalesce((settings ->> 'slot_minutes')::int, slot_minutes),
    booking_capacity = coalesce((settings ->> 'capacity')::int, booking_capacity)
  where id = b.id;
  return jsonb_build_object('ok', true);
exception when check_violation or invalid_text_representation then
  return jsonb_build_object('ok', false, 'error', 'invalid');
end; $$;

-- Public JSON: booking switch and services (+ the owner's booking settings
-- through the dashboard, which builds on this JSON).
create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'industry', b.industry, 'hours', b.hours, 'week_hours', b.week_hours, 'banners', b.banners,
    'theme', b.theme, 'tagline', b.tagline, 'logo_url', b.logo_url, 'cover_url', b.cover_url, 'email', b.email, 'socials', b.socials,
    'booking_enabled', b.booking_enabled and b.week_hours is not null and jsonb_array_length(b.services) > 0,
    'services', b.services, 'slot_minutes', b.slot_minutes, 'booking_capacity', b.booking_capacity,
    'latitude', b.latitude, 'longitude', b.longitude, 'radius_m', b.geofence_radius_m,
    'card_background', b.card_background,
    'closed', b.closed_until is not null and b.closed_until >= current_date,
    'closed_until', case when b.closed_until >= current_date then b.closed_until end,
    'closed_message', case when b.closed_until >= current_date then b.closed_message end);
$$;

revoke all on function public.nfc_booking_slots(text, text, date) from public;
revoke all on function public.nfc_booking_create(text, text, text, date, text) from public;
revoke all on function public.nfc_booking_mine(text, text) from public;
revoke all on function public.nfc_booking_cancel(text, text, uuid) from public;
revoke all on function public.nfc_shop_bookings(text, text) from public;
revoke all on function public.nfc_shop_booking_set(text, text, uuid, text) from public;
revoke all on function public.nfc_shop_booking_settings(text, text, jsonb) from public;
grant execute on function public.nfc_booking_slots(text, text, date) to anon, authenticated;
grant execute on function public.nfc_booking_create(text, text, text, date, text) to anon, authenticated;
grant execute on function public.nfc_booking_mine(text, text) to anon, authenticated;
grant execute on function public.nfc_booking_cancel(text, text, uuid) to anon, authenticated;
grant execute on function public.nfc_shop_bookings(text, text) to anon, authenticated;
grant execute on function public.nfc_shop_booking_set(text, text, uuid, text) to anon, authenticated;
grant execute on function public.nfc_shop_booking_settings(text, text, jsonb) to anon, authenticated;
