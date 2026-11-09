-- Professional shop page (logo, cover, e-mail, social links, up to 6 photos)
-- and a QR that changes every 5 seconds.

-- 1. Shop page fields edited by the owner.
alter table public.nfc_businesses
  add column if not exists logo_url text,
  add column if not exists cover_url text,
  add column if not exists email text,
  add column if not exists socials jsonb not null default '[]'::jsonb;

create or replace function nfc_private.valid_socials(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb;
begin
  if jsonb_typeof(value) <> 'array' or jsonb_array_length(value) > 12 then return false; end if;
  for item in select * from jsonb_array_elements(value) loop
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'type', '') not in
          ('instagram', 'whatsapp', 'tiktok', 'facebook', 'snapchat', 'youtube', 'website', 'maps', 'phone', 'email')
       or length(coalesce(item ->> 'value', '')) not between 1 and 300
       or (item ->> 'value') ~ '[[:cntrl:]]' then
      return false;
    end if;
  end loop;
  return true;
end; $$;

alter table public.nfc_businesses drop constraint if exists nfc_businesses_socials_check;
alter table public.nfc_businesses
  add constraint nfc_businesses_socials_check check (nfc_private.valid_socials(socials));

create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'industry', b.industry, 'hours', b.hours, 'week_hours', b.week_hours, 'banners', b.banners,
    'logo_url', b.logo_url, 'cover_url', b.cover_url, 'email', b.email, 'socials', b.socials,
    'latitude', b.latitude, 'longitude', b.longitude, 'radius_m', b.geofence_radius_m,
    'card_background', b.card_background,
    'closed', b.closed_until is not null and b.closed_until >= current_date,
    'closed_until', case when b.closed_until >= current_date then b.closed_until end,
    'closed_message', case when b.closed_until >= current_date then b.closed_message end);
$$;

create or replace function nfc_private.valid_image_url(value text)
returns boolean language sql immutable set search_path = '' as $$
  select value is null
      or value ~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$';
$$;

create or replace function public.nfc_shop_update(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; new_banners jsonb; item jsonb; bg text; wh jsonb;
        logo text; cover text; mail text; links jsonb;
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

-- 2. QR every 5 seconds. A shown code stays valid for 2 minutes so a new
--    customer has time to type their name; one visit per min_hours still applies.
create or replace function nfc_private.current_window()
returns bigint language sql stable set search_path = '' as $$
  select floor(extract(epoch from now()) / 5)::bigint;
$$;

create or replace function nfc_private.code_valid(business uuid, code text)
returns boolean language plpgsql stable set search_path = '' as $$
declare w bigint := nfc_private.current_window(); i int;
begin
  if code is null or code !~ '^[0-9a-fA-F]{8}$' then return false; end if;
  for i in 0..24 loop
    if lower(code) = nfc_private.shop_code(business, w - i) then return true; end if;
  end loop;
  return false;
end; $$;

-- Patch the live join / visit / QR functions in place (keeps every other
-- change made to them by earlier migrations).
do $$
declare def text; patched text; fn text;
begin
  foreach fn in array array['public.nfc_customer_join(text,text,text,text)', 'public.nfc_customer_visit(text,text,text)'] loop
    def := pg_get_functiondef(fn::regprocedure);
    patched := replace(def,
      'lower(code) in (nfc_private.shop_code(b.id, w), nfc_private.shop_code(b.id, w - 1))',
      'nfc_private.code_valid(b.id, code)');
    patched := replace(patched,
      'lower(code) not in (nfc_private.shop_code(b.id, w), nfc_private.shop_code(b.id, w - 1))',
      'not nfc_private.code_valid(b.id, code)');
    if patched = def and position('code_valid' in def) = 0 then
      raise exception 'could not patch %', fn;
    end if;
    execute patched;
  end loop;
  def := pg_get_functiondef('public.nfc_shop_qr(text,text)'::regprocedure);
  patched := replace(def, '30 - (floor(extract(epoch from now()))::bigint % 30)',
                          '5 - (floor(extract(epoch from now()))::bigint % 5)');
  if patched = def and position('% 5)' in def) = 0 then
    raise exception 'could not patch nfc_shop_qr';
  end if;
  execute patched;
end $$;
