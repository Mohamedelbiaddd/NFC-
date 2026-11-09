-- Catalog items on every profile, owner self-editing with a PIN, and a
-- per-user detail view for super administrators.

-- 0. PIN storage (hashed with bcrypt) ---
create table if not exists nfc_private.profile_pins (
  profile_id uuid primary key references public.nfc_profiles(id) on delete cascade,
  pin_hash text not null,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);
revoke all on nfc_private.profile_pins from public, anon, authenticated;

-- 1. Catalog ---------------------------------------------------------------
-- Each item: {name, price, description, image_url}. An item needs a name or an
-- image. Images must live in this project's public profile-images bucket.
create or replace function nfc_private.valid_catalog(c jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb; key text;
begin
  if c is null then return true; end if;
  if jsonb_typeof(c) <> 'array' or jsonb_array_length(c) > 60
     or octet_length(c::text) > 60000 then
    return false;
  end if;
  for item in select * from jsonb_array_elements(c) loop
    if jsonb_typeof(item) <> 'object' then return false; end if;
    for key in select jsonb_object_keys(item) loop
      if key not in ('name', 'price', 'description', 'image_url') then return false; end if;
      if jsonb_typeof(item -> key) <> 'string' then return false; end if;
    end loop;
    if length(coalesce(item ->> 'name', '')) > 120
       or length(coalesce(item ->> 'price', '')) > 40
       or length(coalesce(item ->> 'description', '')) > 1000 then
      return false;
    end if;
    if length(coalesce(item ->> 'image_url', '')) > 0 and (
         length(item ->> 'image_url') > 2000
         or (item ->> 'image_url') !~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$') then
      return false;
    end if;
    if length(trim(coalesce(item ->> 'name', ''))) = 0
       and length(coalesce(item ->> 'image_url', '')) = 0 then
      return false;
    end if;
  end loop;
  return true;
end; $$;

alter table public.nfc_profiles
  add column if not exists catalog jsonb not null default '[]'::jsonb;
alter table public.nfc_profiles
  drop constraint if exists nfc_profiles_catalog_valid;
alter table public.nfc_profiles
  add constraint nfc_profiles_catalog_valid check (nfc_private.valid_catalog(catalog));
grant update (catalog) on public.nfc_profiles to authenticated;
grant insert (catalog) on public.nfc_profiles to authenticated;

-- Public page payload now includes the catalog.
create or replace function public.nfc_public_profile_by_slug(slug text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'custom_slug', p.custom_slug, 'title', p.title, 'kind', p.kind,
    'image_url', p.image_url, 'data', p.data, 'catalog', p.catalog,
    'updated_at', p.updated_at,
    'editable', exists (select 1 from nfc_private.profile_pins pin where pin.profile_id = p.id),
    'business', jsonb_build_object(
      'name', b.name, 'primary_color', b.primary_color,
      'accent_color', b.accent_color))
  from public.nfc_profiles p
  join public.nfc_businesses b
    on b.id = p.business_id and b.tenant_id = p.tenant_id
  where p.custom_slug = lower(trim(slug))
    and p.published = true
    and length(coalesce(slug, '')) between 3 and 63;
$$;

-- 2. Owner PIN -------------------------------------------------------------

alter table public.nfc_activity drop constraint if exists nfc_activity_action_check;
alter table public.nfc_activity add constraint nfc_activity_action_check check (action = any (array[
  'profile_created','profile_updated','profile_deleted','business_created',
  'worker_created','worker_updated','worker_password_reset','worker_disabled','worker_deleted',
  'card_written','card_verified','card_locked','qr_saved','login','user_joined',
  'user_banned','user_unbanned','pin_set','pin_removed','owner_edited','link_written']));

-- The app's log RPC may record direct-link NFC writes too.
create or replace function public.nfc_log_event(workspace_id uuid, event_action text, event_subject text default null, event_details jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if event_action not in ('qr_saved','login','worker_created','worker_updated',
      'worker_password_reset','worker_disabled','worker_deleted','link_written') then
    raise exception 'Invalid action';
  end if;
  if not nfc_private.has_role(workspace_id, array['owner','admin','editor']) then
    raise exception 'Not authorized';
  end if;
  if octet_length(coalesce(event_details,'{}'::jsonb)::text) > 4000 then
    raise exception 'Details too large';
  end if;
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,details)
  values (workspace_id, auth.uid(), event_action,
    left(coalesce(event_subject,''),200), coalesce(event_details,'{}'::jsonb));
end; $$;

-- Staff set (or clear with null/'') the 6-12 digit PIN for a profile.
create or replace function public.nfc_set_profile_pin(target_profile uuid, pin text)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles;
begin
  select * into p from public.nfc_profiles where id = target_profile;
  if p.id is null then raise exception 'Profile not found'; end if;
  if not (nfc_private.has_role(p.tenant_id, array['owner','admin','editor'])
          or nfc_private.is_super_admin(auth.uid())) then
    raise exception 'Not authorized';
  end if;
  if pin is null or pin = '' then
    delete from nfc_private.profile_pins where profile_id = p.id;
    insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id)
    values (p.tenant_id, auth.uid(), 'pin_removed', p.title, p.id);
    return;
  end if;
  if pin !~ '^[0-9]{6,12}$' then raise exception 'PIN must be 6-12 digits'; end if;
  insert into nfc_private.profile_pins(profile_id, pin_hash)
  values (p.id, extensions.crypt(pin, extensions.gen_salt('bf', 8)))
  on conflict (profile_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0,
        locked_until = null, updated_at = now();
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id)
  values (p.tenant_id, auth.uid(), 'pin_set', p.title, p.id);
end; $$;

-- Which of the given profiles have a PIN (for the app's form).
create or replace function public.nfc_profile_pin_status(profile_ids uuid[])
returns table(profile_id uuid) language sql stable security definer set search_path = '' as $$
  select pin.profile_id from nfc_private.profile_pins pin
  join public.nfc_profiles p on p.id = pin.profile_id
  where pin.profile_id = any(profile_ids)
    and (nfc_private.has_role(p.tenant_id) or nfc_private.is_super_admin(auth.uid()));
$$;

-- Verifies slug + PIN with lockout (5 wrong tries -> 15 minutes).
-- Returns the profile row or raises.
create or replace function nfc_private.owner_check(target_slug text, pin text)
returns public.nfc_profiles language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles; rec nfc_private.profile_pins;
begin
  select * into p from public.nfc_profiles
   where custom_slug = lower(trim(target_slug)) and published = true;
  if p.id is null then raise exception 'Invalid code' using errcode = '28000'; end if;
  select * into rec from nfc_private.profile_pins where profile_id = p.id for update;
  if rec.profile_id is null then raise exception 'Invalid code' using errcode = '28000'; end if;
  if rec.locked_until is not null and rec.locked_until > now() then
    raise exception 'Too many attempts, try later' using errcode = '28000';
  end if;
  if pin is null or rec.pin_hash <> extensions.crypt(pin, rec.pin_hash) then
    update nfc_private.profile_pins
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5
                               then now() + interval '15 minutes' end
     where profile_id = p.id;
    return null;
  end if;
  update nfc_private.profile_pins set failed_attempts = 0, locked_until = null
   where profile_id = p.id;
  return p;
end; $$;
revoke all on function nfc_private.owner_check(text, text) from public, anon, authenticated;
grant execute on function nfc_private.owner_check(text, text) to service_role;

-- A failed check must not raise, otherwise the attempt counter would be rolled
-- back with the transaction; the RPCs return {ok:false} instead.
create or replace function public.nfc_owner_login(target_slug text, pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles;
begin
  begin
    p := nfc_private.owner_check(target_slug, pin);
  exception when sqlstate '28000' then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
  end;
  if p.id is null then return jsonb_build_object('ok', false, 'error', 'Invalid code'); end if;
  return jsonb_build_object('ok', true, 'profile', jsonb_build_object(
    'title', p.title, 'kind', p.kind, 'data', p.data, 'catalog', p.catalog,
    'image_url', p.image_url, 'custom_slug', p.custom_slug));
end; $$;

create or replace function public.nfc_owner_update(
  target_slug text, pin text, new_title text, new_data jsonb,
  new_catalog jsonb, new_image_url text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles;
begin
  begin
    p := nfc_private.owner_check(target_slug, pin);
  exception when sqlstate '28000' then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
  end;
  if p.id is null then return jsonb_build_object('ok', false, 'error', 'Invalid code'); end if;
  if new_image_url is not null and new_image_url <> '' and
     new_image_url !~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$' then
    raise exception 'Invalid image';
  end if;
  update public.nfc_profiles
     set title = left(trim(coalesce(nullif(trim(new_title), ''), p.title)), 120),
         data = coalesce(new_data, p.data),
         catalog = coalesce(new_catalog, p.catalog),
         image_url = case when new_image_url is null then p.image_url
                          when new_image_url = '' then null
                          else new_image_url end
   where id = p.id;
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id)
  values (p.tenant_id, null, 'owner_edited', p.title, p.id);
  return jsonb_build_object('ok', true);
end; $$;

revoke all on function public.nfc_set_profile_pin(uuid, text),
  public.nfc_profile_pin_status(uuid[]),
  public.nfc_owner_login(text, text),
  public.nfc_owner_update(text, text, text, jsonb, jsonb, text) from public;
grant execute on function public.nfc_set_profile_pin(uuid, text),
  public.nfc_profile_pin_status(uuid[]) to authenticated;
grant execute on function public.nfc_owner_login(text, text),
  public.nfc_owner_update(text, text, text, jsonb, jsonb, text) to anon, authenticated;

-- 3. Admin per-user detail -------------------------------------------------
create or replace function public.nfc_admin_user_detail(target_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not nfc_private.is_super_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  return jsonb_build_object(
    'profiles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'title', p.title, 'kind', p.kind, 'slug', p.custom_slug,
        'published', p.published, 'created_at', p.created_at,
        'business', b.name, 'workspace', t.name,
        'scans', (select count(*) from public.nfc_scans s where s.profile_id = p.id))
        order by p.created_at desc)
      from public.nfc_profiles p
      join public.nfc_businesses b on b.id = p.business_id
      join public.nfc_tenants t on t.id = p.tenant_id
      where p.created_by = target_id), '[]'::jsonb),
    'activity', coalesce((
      select jsonb_agg(x order by (x->>'created_at') desc) from (
        select jsonb_build_object('action', a.action, 'subject', a.subject,
          'details', a.details, 'created_at', a.created_at, 'workspace', t.name) x
        from public.nfc_activity a
        join public.nfc_tenants t on t.id = a.tenant_id
        where a.actor_id = target_id
        order by a.created_at desc limit 300) q), '[]'::jsonb),
    'workspaces', coalesce((
      select jsonb_agg(jsonb_build_object('name', t.name, 'role', m.role))
      from public.nfc_memberships m join public.nfc_tenants t on t.id = m.tenant_id
      where m.user_id = target_id), '[]'::jsonb));
end; $$;
revoke all on function public.nfc_admin_user_detail(uuid) from public, anon;
grant execute on function public.nfc_admin_user_detail(uuid) to authenticated;

grant execute on function public.nfc_owner_login(text, text) to service_role;
