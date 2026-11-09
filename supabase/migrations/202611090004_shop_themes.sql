-- Shop page themes (10 looks chosen by the owner), a short title under the
-- name, and a booking link type.
alter table public.nfc_businesses
  add column if not exists theme text not null default 'navy',
  add column if not exists tagline text;
alter table public.nfc_businesses drop constraint if exists nfc_businesses_theme_check;
alter table public.nfc_businesses add constraint nfc_businesses_theme_check
  check (theme in ('navy', 'black', 'emerald', 'royal', 'rose', 'ocean', 'sunset', 'crimson', 'ivory', 'mint'));

create or replace function nfc_private.valid_socials(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb;
begin
  if jsonb_typeof(value) <> 'array' or jsonb_array_length(value) > 12 then return false; end if;
  for item in select * from jsonb_array_elements(value) loop
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'type', '') not in
          ('instagram', 'whatsapp', 'tiktok', 'facebook', 'snapchat', 'youtube', 'website', 'maps', 'phone', 'email', 'booking')
       or length(coalesce(item ->> 'value', '')) not between 1 and 300
       or (item ->> 'value') ~ '[[:cntrl:]]' then
      return false;
    end if;
  end loop;
  return true;
end; $$;

create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'industry', b.industry, 'hours', b.hours, 'week_hours', b.week_hours, 'banners', b.banners,
    'theme', b.theme, 'tagline', b.tagline, 'logo_url', b.logo_url, 'cover_url', b.cover_url, 'email', b.email, 'socials', b.socials,
    'latitude', b.latitude, 'longitude', b.longitude, 'radius_m', b.geofence_radius_m,
    'card_background', b.card_background,
    'closed', b.closed_until is not null and b.closed_until >= current_date,
    'closed_until', case when b.closed_until >= current_date then b.closed_until end,
    'closed_message', case when b.closed_until >= current_date then b.closed_message end);
$$;

create or replace function public.nfc_shop_update(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; new_banners jsonb; item jsonb; bg text; wh jsonb;
        logo text; cover text; mail text; links jsonb; th text; tag text;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  if b.suspended then return jsonb_build_object('ok', false, 'error', 'suspended'); end if;
  new_banners := coalesce(settings -> 'banners', b.banners);
  if jsonb_typeof(new_banners) <> 'array' or jsonb_array_length(new_banners) > 6 then
    return jsonb_build_object('ok', false, 'error', 'banners');
  end if;
  for item in select * from jsonb_array_elements(new_banners) loop
    if jsonb_typeof(item) <> 'string' or not nfc_private.valid_image_url(item #>> '{}') then
      return jsonb_build_object('ok', false, 'error', 'banners');
    end if;
  end loop;
  wh := case when settings ? 'week_hours' then nullif(settings -> 'week_hours', 'null'::jsonb) else b.week_hours end;
  if not nfc_private.valid_week_hours(wh) then
    return jsonb_build_object('ok', false, 'error', 'hours');
  end if;
  bg := case when settings ? 'card_background' then nullif(settings ->> 'card_background', '') else b.card_background end;
  logo := case when settings ? 'logo_url' then nullif(settings ->> 'logo_url', '') else b.logo_url end;
  cover := case when settings ? 'cover_url' then nullif(settings ->> 'cover_url', '') else b.cover_url end;
  if not nfc_private.valid_image_url(logo) or not nfc_private.valid_image_url(cover) then
    return jsonb_build_object('ok', false, 'error', 'image');
  end if;
  mail := case when settings ? 'email' then nullif(lower(trim(settings ->> 'email')), '') else b.email end;
  if mail is not null and mail !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'error', 'email');
  end if;
  links := coalesce(settings -> 'socials', b.socials);
  if not nfc_private.valid_socials(links) then
    return jsonb_build_object('ok', false, 'error', 'socials');
  end if;
  th := coalesce(nullif(settings ->> 'theme', ''), b.theme);
  if th not in ('navy', 'black', 'emerald', 'royal', 'rose', 'ocean', 'sunset', 'crimson', 'ivory', 'mint') then
    return jsonb_build_object('ok', false, 'error', 'theme');
  end if;
  tag := case when settings ? 'tagline' then nullif(trim(settings ->> 'tagline'), '') else b.tagline end;
  if length(tag) > 80 then return jsonb_build_object('ok', false, 'error', 'tagline'); end if;
  update public.nfc_businesses set
    theme = th,
    tagline = tag,
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
    logo_url = logo,
    cover_url = cover,
    email = mail,
    socials = links,
    banners = new_banners
  where id = b.id;
  return jsonb_build_object('ok', true);
exception when check_violation or invalid_text_representation then
  return jsonb_build_object('ok', false, 'error', 'invalid');
end; $$;

