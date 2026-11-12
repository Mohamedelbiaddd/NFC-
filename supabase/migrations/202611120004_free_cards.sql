-- Free self-service business cards: anyone signs up on tapmaroc.com, confirms
-- the e-mail, and creates ONE digital business card (link + QR) for free.
-- The cards live in a dedicated "free" space owned by the admin, so they show
-- up as leads in the app. NFC cards, loyalty and Wallet stay paid.

alter table public.nfc_profiles add column if not exists self_owner uuid references auth.users(id) on delete set null;
create unique index if not exists nfc_profiles_one_free_card on public.nfc_profiles(self_owner) where self_owner is not null;

create table if not exists nfc_private.free_space (
  id int primary key default 1 check (id = 1),
  tenant_id uuid not null references public.nfc_tenants(id),
  business_id uuid not null references public.nfc_businesses(id)
);
revoke all on nfc_private.free_space from public, anon, authenticated;

do $$ declare t uuid; b uuid; owner uuid; begin
  if exists (select 1 from nfc_private.free_space) then return; end if;
  select u.id into owner from auth.users u where lower(u.email) = 'mohamed.elbiad.2024@gmail.com';
  if owner is null then
    select u.id into owner from auth.users u where nfc_private.is_super_admin(u.id) order by u.created_at limit 1;
  end if;
  insert into public.nfc_tenants (name, owner_id) values ('TapMaroc · بطاقات مجانية', owner) returning id into t;
  insert into public.nfc_businesses (tenant_id, name, created_by, industry) values (t, 'TapMaroc', owner, 'other') returning id into b;
  insert into nfc_private.free_space (tenant_id, business_id) values (t, b);
end $$;

-- The signed-in user's own free card (or null).
create or replace function public.nfc_my_card()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('slug', p.custom_slug, 'title', p.title, 'data', p.data,
    'image_url', p.image_url, 'created_at', p.created_at)
  from public.nfc_profiles p where p.self_owner = auth.uid() and auth.uid() is not null;
$$;

create or replace function public.nfc_free_card_create(full_name text, job_title text default '', phone text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); fs nfc_private.free_space; s text; d jsonb; n text; j text; ph text;
begin
  if uid is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from auth.users u where u.id = uid and u.email_confirmed_at is not null) then
    raise exception 'Email not confirmed';
  end if;
  if exists (select 1 from public.nfc_profiles where self_owner = uid) then
    return public.nfc_my_card() || jsonb_build_object('existing', true);
  end if;
  -- Brake against mass sign-ups: at most 100 new free cards per hour overall.
  if (select count(*) from public.nfc_profiles where self_owner is not null and created_at > now() - interval '1 hour') >= 100 then
    raise exception 'Busy, try again later';
  end if;
  n := left(trim(regexp_replace(coalesce(full_name, ''), '[[:cntrl:]]', '', 'g')), 80);
  j := left(trim(regexp_replace(coalesce(job_title, ''), '[[:cntrl:]]', '', 'g')), 80);
  ph := left(regexp_replace(coalesce(phone, ''), '[^0-9+ ]', '', 'g'), 20);
  if length(n) < 2 then raise exception 'Name required'; end if;
  select * into fs from nfc_private.free_space where id = 1;
  d := jsonb_strip_nulls(jsonb_build_object('full_name', n, 'job_title', j, 'phone', ph,
    'whatsapp', case when length(regexp_replace(ph, '[^0-9]', '', 'g')) >= 6 then regexp_replace(ph, '[^0-9]', '', 'g') end,
    'email', coalesce((select email from auth.users where id = uid), '')));
  loop
    s := 'card-' || substr(md5(gen_random_uuid()::text), 1, 12);
    exit when not exists (select 1 from nfc_private.slug_reservations where slug = s);
  end loop;
  insert into public.nfc_profiles (tenant_id, business_id, kind, title, data, published, custom_slug, self_owner)
  values (fs.tenant_id, fs.business_id, 'vcard', n, d, true, s, uid);
  return public.nfc_my_card();
end; $$;

-- Opens the card editor for the owner: issues a fresh one-time edit code
-- (the existing editor and photo upload work with it), so the user never
-- has to remember a PIN — the account is the key.
create or replace function public.nfc_my_card_edit_code()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles; code text;
begin
  select * into p from public.nfc_profiles where self_owner = auth.uid() and auth.uid() is not null;
  if p.id is null then raise exception 'No card'; end if;
  code := lpad((floor(random() * 1e12))::bigint::text, 12, '0');
  insert into nfc_private.profile_pins (profile_id, pin_hash, failed_attempts, locked_until, updated_at)
  values (p.id, extensions.crypt(code, extensions.gen_salt('bf')), 0, null, now())
  on conflict (profile_id) do update set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();
  return jsonb_build_object('slug', p.custom_slug, 'code', code);
end; $$;

revoke all on function public.nfc_my_card() from public, anon;
revoke all on function public.nfc_free_card_create(text, text, text) from public, anon;
revoke all on function public.nfc_my_card_edit_code() from public, anon;
grant execute on function public.nfc_my_card() to authenticated;
grant execute on function public.nfc_free_card_create(text, text, text) to authenticated;
grant execute on function public.nfc_my_card_edit_code() to authenticated;

-- Public card JSON tells the page whether it is a free card (for the
-- "Create yours free" footer).
create or replace function public.nfc_public_profile_by_slug(slug text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'custom_slug', p.custom_slug, 'title', p.title, 'kind', p.kind,
    'image_url', p.image_url, 'data', p.data, 'catalog', p.catalog,
    'updated_at', p.updated_at,
    'editable', exists (select 1 from nfc_private.profile_pins pin where pin.profile_id = p.id),
    'free', p.self_owner is not null,
    'business', jsonb_build_object(
      'name', b.name, 'primary_color', b.primary_color,
      'accent_color', b.accent_color, 'logo_url', b.logo_url,
      'cover_url', b.cover_url, 'theme', b.theme))
  from public.nfc_profiles p
  join public.nfc_businesses b
    on b.id = p.business_id and b.tenant_id = p.tenant_id
  where p.custom_slug = lower(trim(slug))
    and p.published = true
    and not b.suspended
    and length(coalesce(slug, '')) between 3 and 63;
$$;
