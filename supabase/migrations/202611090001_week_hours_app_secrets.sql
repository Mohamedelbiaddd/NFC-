-- Weekly opening hours set by the shop owner (Monday .. Sunday) and a private
-- store for server-only secrets read by edge functions.

-- 1. Weekly hours: 7 entries, Monday first; each is null (closed) or
--    {"o": "HH:MM", "c": "HH:MM"}.
alter table public.nfc_businesses add column if not exists week_hours jsonb;

create or replace function nfc_private.valid_week_hours(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb;
begin
  if value is null then return true; end if;
  if jsonb_typeof(value) <> 'array' or jsonb_array_length(value) <> 7 then return false; end if;
  for item in select * from jsonb_array_elements(value) loop
    if jsonb_typeof(item) = 'null' then continue; end if;
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'o', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or coalesce(item ->> 'c', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      return false;
    end if;
  end loop;
  return true;
end; $$;

alter table public.nfc_businesses drop constraint if exists nfc_businesses_week_hours_check;
alter table public.nfc_businesses
  add constraint nfc_businesses_week_hours_check check (nfc_private.valid_week_hours(week_hours));

create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'industry', b.industry, 'hours', b.hours, 'week_hours', b.week_hours, 'banners', b.banners,
    'latitude', b.latitude, 'longitude', b.longitude, 'radius_m', b.geofence_radius_m,
    'card_background', b.card_background,
    'closed', b.closed_until is not null and b.closed_until >= current_date,
    'closed_until', case when b.closed_until >= current_date then b.closed_until end,
    'closed_message', case when b.closed_until >= current_date then b.closed_message end);
$$;

create or replace function public.nfc_shop_update(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; new_banners jsonb; item jsonb; bg text; wh jsonb;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  if b.suspended then return jsonb_build_object('ok', false, 'error', 'suspended'); end if;
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
  wh := case when settings ? 'week_hours' then nullif(settings -> 'week_hours', 'null'::jsonb) else b.week_hours end;
  if not nfc_private.valid_week_hours(wh) then
    return jsonb_build_object('ok', false, 'error', 'hours');
  end if;
  bg := case when settings ? 'card_background' then nullif(settings ->> 'card_background', '') else b.card_background end;
  update public.nfc_businesses set
    name = coalesce(nullif(trim(settings ->> 'name'), ''), name),
    phone = case when settings ? 'phone' then nullif(trim(settings ->> 'phone'), '') else phone end,
    address = case when settings ? 'address' then nullif(trim(settings ->> 'address'), '') else address end,
    hours = case when settings ? 'hours' then nullif(trim(settings ->> 'hours'), '') else hours end,
    week_hours = wh,
    loyalty_goal = coalesce((settings ->> 'goal')::int, loyalty_goal),
    loyalty_reward = coalesce(nullif(trim(settings ->> 'reward'), ''), loyalty_reward),
    latitude = case when settings ? 'latitude' then (settings ->> 'latitude')::double precision else latitude end,
    longitude = case when settings ? 'longitude' then (settings ->> 'longitude')::double precision else longitude end,
    geofence_radius_m = coalesce((settings ->> 'radius_m')::int, geofence_radius_m),
    card_background = bg,
    banners = new_banners
  where id = b.id;
  return jsonb_build_object('ok', true);
exception when check_violation or invalid_text_representation then
  return jsonb_build_object('ok', false, 'error', 'invalid');
end; $$;

-- 2. Server-only secrets (e.g. the Google Wallet service-account key) that
--    edge functions read with the service role. Never exposed to clients.
create table if not exists nfc_private.app_secrets (
  name text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);
revoke all on nfc_private.app_secrets from public, anon, authenticated;

create or replace function public.nfc_app_secret(secret_name text)
returns text language sql stable security definer set search_path = '' as $$
  select value from nfc_private.app_secrets where name = secret_name;
$$;
revoke all on function public.nfc_app_secret(text) from public, anon, authenticated;
grant execute on function public.nfc_app_secret(text) to service_role;
