-- Staff accounts: invitations (24 h link, no password shared), one phone per
-- account, and the protected app download.
--
-- * staff_invites: the admin enters a name and an e-mail; the person gets a
--   link valid 24 hours. It downloads the app and activates the account; the
--   person chooses their own password. Used, expired or replaced links die.
-- * staff_devices: the first phone that activates/logs in is the account's
--   phone. Another phone becomes "pending" until the first phone (or a
--   manager) approves it; approving blocks the old phone and ends its session.
-- * nfc_check_request: runs before every API request (PostgREST pre-request):
--   a staff session that is not the account's active phone can only say hello.
-- * app_release: what CI published (private bucket app-releases).

create table if not exists nfc_private.staff_invites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  lang text not null default 'ar',
  token_hash text not null unique,
  code_hash text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  downloads int not null default 0,
  first_download_at timestamptz,
  activated_at timestamptz,
  attempts int not null default 0,
  revoked boolean not null default false,
  email_status text
);
create index if not exists staff_invites_user on nfc_private.staff_invites(user_id, created_at desc);
create index if not exists staff_invites_email on nfc_private.staff_invites(lower(email), created_at desc);

create table if not exists nfc_private.staff_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  model text,
  platform text,
  os text,
  app_build text,
  status text not null check (status in ('active', 'pending', 'revoked')),
  session_id uuid,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid,
  unique (user_id, device_id)
);
create index if not exists staff_devices_user on nfc_private.staff_devices(user_id, status);

create table if not exists nfc_private.app_release (
  id int primary key default 1 check (id = 1),
  manifest jsonb not null,
  updated_at timestamptz not null default now()
);

revoke all on nfc_private.staff_invites, nfc_private.staff_devices, nfc_private.app_release from public, anon, authenticated;
alter table nfc_private.staff_invites enable row level security;
alter table nfc_private.staff_devices enable row level security;
alter table nfc_private.app_release enable row level security;

-- Private bucket for the APKs (service role only; downloads use signed URLs).
insert into storage.buckets (id, name, public, file_size_limit)
values ('app-releases', 'app-releases', false, 52428800)
on conflict (id) do update set public = false;

-- ---------------------------------------------------------------- helpers

create or replace function nfc_private.jwt_session()
returns uuid language sql stable set search_path = '' as $$
  select case when coalesce(auth.jwt() ->> 'session_id', '') ~* '^[0-9a-f-]{36}$'
              then (auth.jwt() ->> 'session_id')::uuid end;
$$;

-- true when the caller is not restricted (not staff, super admin) or this
-- session is the account's approved phone.
create or replace function nfc_private.session_ok()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is null
    or not exists (select 1 from public.nfc_staff s where s.user_id = auth.uid())
    or nfc_private.is_super_admin(auth.uid())
    or exists (select 1 from nfc_private.staff_devices d
               where d.user_id = auth.uid() and d.status = 'active'
                 and d.session_id = nfc_private.jwt_session());
$$;

create or replace function nfc_private.has_role(t uuid, roles text[] default array['owner', 'admin', 'editor', 'viewer'])
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.is_super_admin(auth.uid())
    or (exists (select 1 from public.nfc_memberships
                 where tenant_id = t and user_id = auth.uid() and role = any(roles))
        and exists (select 1 from public.nfc_staff s where s.user_id = auth.uid() and s.active)
        and nfc_private.session_ok());
$$;

-- Ends every login of a user except [keep] (refresh tokens die; an access
-- token already issued is refused by nfc_check_request).
create or replace function nfc_private.end_sessions(target uuid, keep uuid default null)
returns void language sql security definer set search_path = '' as $$
  delete from auth.sessions where user_id = target and id is distinct from keep;
$$;

-- ------------------------------------------------------------ pre-request

create or replace function public.nfc_check_request()
returns void language plpgsql stable security definer set search_path = '' as $$
declare
  path text;
begin
  if auth.uid() is null then return; end if;
  path := coalesce(current_setting('request.path', true), '');
  if path in ('/rpc/nfc_device_hello', '/rpc/nfc_my_account', '/rpc/nfc_check_request') then
    return;
  end if;
  if not nfc_private.session_ok() then
    raise sqlstate 'PT403' using message = 'device_not_approved',
      hint = 'This phone is not the approved device for this account.';
  end if;
end;
$$;
grant execute on function public.nfc_check_request() to anon, authenticated;

-- ------------------------------------------------------------- devices

create or replace function public.nfc_device_hello(
  p_device text, p_model text default null, p_platform text default null,
  p_os text default null, p_app text default null, p_cert text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  sid uuid := nfc_private.jwt_session();
  expected text;
  mine nfc_private.staff_devices;
  current_dev nfc_private.staff_devices;
begin
  if uid is null then return jsonb_build_object('status', 'none'); end if;
  if p_device is null or length(p_device) not between 16 and 100 then
    return jsonb_build_object('status', 'error', 'error', 'bad_device');
  end if;
  if nfc_private.is_super_admin(uid)
     or not exists (select 1 from public.nfc_staff s where s.user_id = uid) then
    return jsonb_build_object('status', 'active', 'exempt', true);
  end if;
  -- This login was ended (another phone was approved, or the manager reset it).
  if sid is null or not exists (select 1 from auth.sessions a where a.id = sid) then
    return jsonb_build_object('status', 'ended');
  end if;
  -- A rebuilt / re-signed APK reports another certificate.
  select r.manifest ->> 'cert_sha256' into expected from nfc_private.app_release r where r.id = 1;
  if coalesce(p_platform, '') = 'android' and coalesce(expected, '') <> ''
     and lower(coalesce(p_cert, '')) <> lower(expected) then
    return jsonb_build_object('status', 'blocked', 'reason', 'integrity');
  end if;

  select * into mine from nfc_private.staff_devices where user_id = uid and device_id = p_device;
  if found and mine.status = 'active' then
    update nfc_private.staff_devices
       set session_id = sid, last_seen = now(), model = coalesce(left(p_model, 120), model),
           platform = coalesce(left(p_platform, 20), platform), os = coalesce(left(p_os, 60), os),
           app_build = coalesce(left(p_app, 20), app_build)
     where id = mine.id;
    return jsonb_build_object('status', 'active');
  end if;

  select * into current_dev from nfc_private.staff_devices
   where user_id = uid and status = 'active' order by last_seen desc limit 1;
  if not found then
    -- First phone (or the manager allowed a new one): it becomes the phone.
    insert into nfc_private.staff_devices as d (user_id, device_id, model, platform, os, app_build, status, session_id, approved_at)
    values (uid, p_device, left(p_model, 120), left(p_platform, 20), left(p_os, 60), left(p_app, 20), 'active', sid, now())
    on conflict (user_id, device_id) do update
      set status = 'active', session_id = sid, last_seen = now(), approved_at = now(),
          model = excluded.model, platform = excluded.platform, os = excluded.os, app_build = excluded.app_build;
    perform nfc_private.end_sessions(uid, sid);
    return jsonb_build_object('status', 'active', 'first', true);
  end if;

  insert into nfc_private.staff_devices as d (user_id, device_id, model, platform, os, app_build, status, session_id)
  values (uid, p_device, left(p_model, 120), left(p_platform, 20), left(p_os, 60), left(p_app, 20), 'pending', sid)
  on conflict (user_id, device_id) do update
    set status = 'pending', session_id = sid, last_seen = now(),
        model = excluded.model, platform = excluded.platform, os = excluded.os, app_build = excluded.app_build;
  return jsonb_build_object('status', 'pending', 'active_model', current_dev.model);
end;
$$;

-- Pending phones of my own account (only the approved phone may ask).
create or replace function public.nfc_device_requests()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id, 'model', d.model, 'platform', d.platform, 'os', d.os, 'last_seen', d.last_seen)
           order by d.last_seen desc), '[]'::jsonb)
  from nfc_private.staff_devices d
  where d.user_id = auth.uid() and d.status = 'pending'
    and d.last_seen > now() - interval '2 days'
    and exists (select 1 from nfc_private.staff_devices a
                where a.user_id = auth.uid() and a.status = 'active'
                  and a.session_id = nfc_private.jwt_session());
$$;

-- Approve (the new phone becomes the only phone) or refuse a pending phone.
create or replace function public.nfc_device_decide(p_id uuid, p_approve boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  dev nfc_private.staff_devices;
  owner_ok boolean;
begin
  select * into dev from nfc_private.staff_devices where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  owner_ok := dev.user_id = auth.uid() and exists (
    select 1 from nfc_private.staff_devices a
     where a.user_id = auth.uid() and a.status = 'active' and a.session_id = nfc_private.jwt_session());
  if not (owner_ok or nfc_private.manages(dev.user_id)) then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if p_approve then
    update nfc_private.staff_devices set status = 'revoked', session_id = null
     where user_id = dev.user_id and id <> dev.id and status <> 'revoked';
    update nfc_private.staff_devices set status = 'active', approved_at = now(), approved_by = auth.uid()
     where id = dev.id;
    perform nfc_private.end_sessions(dev.user_id, dev.session_id);
  else
    update nfc_private.staff_devices set status = 'revoked', session_id = null where id = dev.id;
    if dev.session_id is not null then
      delete from auth.sessions where id = dev.session_id;
    end if;
  end if;
  insert into public.nfc_network_events (actor_id, action, subject_type, subject_id, subject_name, details)
  select auth.uid(), case when p_approve then 'device_approved' else 'device_refused' end, 'staff', dev.user_id,
         coalesce(s.display_name, ''), jsonb_build_object('model', dev.model)
    from public.nfc_staff s where s.user_id = dev.user_id;
  return jsonb_build_object('ok', true);
end;
$$;

-- Manager: forget the account's phone; the next phone that logs in becomes it.
create or replace function public.nfc_device_reset(target uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if target = auth.uid() or not nfc_private.manages(target) or nfc_private.is_super_admin(target) then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  update nfc_private.staff_devices set status = 'revoked', session_id = null
   where user_id = target and status <> 'revoked';
  perform nfc_private.end_sessions(target, null);
  insert into public.nfc_network_events (actor_id, action, subject_type, subject_id, subject_name)
  select auth.uid(), 'device_reset', 'staff', target, coalesce(s.display_name, '')
    from public.nfc_staff s where s.user_id = target;
  return jsonb_build_object('ok', true);
end;
$$;

-- Invitation and phones of one member (managers, or the member).
create or replace function public.nfc_staff_security(target uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when target = auth.uid() or nfc_private.manages(target) then jsonb_build_object(
    'invite', (select jsonb_build_object(
                 'created_at', i.created_at, 'expires_at', i.expires_at, 'downloads', i.downloads,
                 'first_download_at', i.first_download_at, 'activated_at', i.activated_at,
                 'revoked', i.revoked, 'email_status', i.email_status,
                 'state', case when i.activated_at is not null then 'activated'
                               when i.revoked then 'revoked'
                               when i.expires_at < now() then 'expired'
                               else 'sent' end)
                 from nfc_private.staff_invites i where i.user_id = target
                 order by i.created_at desc limit 1),
    'devices', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', d.id, 'model', d.model, 'platform', d.platform, 'os', d.os, 'app_build', d.app_build,
                 'status', d.status, 'created_at', d.created_at, 'last_seen', d.last_seen,
                 'approved_at', d.approved_at) order by (d.status = 'active') desc, d.last_seen desc)
                 from nfc_private.staff_devices d where d.user_id = target), '[]'::jsonb))
  else null end;
$$;

-- One line per member I manage, for the badges in the network list.
create or replace function public.nfc_network_devices()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x), '[]'::jsonb) from (
    select s.user_id,
      (select case when i.activated_at is not null then 'activated'
                   when i.revoked then 'revoked'
                   when i.expires_at < now() then 'expired'
                   else 'sent' end
         from nfc_private.staff_invites i where i.user_id = s.user_id
         order by i.created_at desc limit 1) as invite,
      (select jsonb_build_object('model', d.model, 'platform', d.platform, 'last_seen', d.last_seen)
         from nfc_private.staff_devices d where d.user_id = s.user_id and d.status = 'active'
         order by d.last_seen desc limit 1) as device,
      (select count(*) from nfc_private.staff_devices d
        where d.user_id = s.user_id and d.status = 'pending' and d.last_seen > now() - interval '2 days') as pending
    from public.nfc_staff s
    where s.user_id <> auth.uid() and nfc_private.manages(s.user_id)
  ) x;
$$;

-- ------------------------------------------------- invites (server only)

create or replace function public.nfc_invite_new(
  p_user uuid, p_email text, p_lang text, p_actor uuid, p_token_hash text, p_code_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  inv nfc_private.staff_invites;
begin
  update nfc_private.staff_invites set revoked = true
   where user_id = p_user and activated_at is null and not revoked;
  insert into nfc_private.staff_invites (user_id, email, lang, token_hash, code_hash, created_by)
  values (p_user, lower(p_email), coalesce(nullif(p_lang, ''), 'ar'), p_token_hash, p_code_hash, p_actor)
  returning * into inv;
  return jsonb_build_object('id', inv.id, 'expires_at', inv.expires_at);
end;
$$;

create or replace function nfc_private.invite_json(i nfc_private.staff_invites)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', i.id, 'user_id', i.user_id, 'email', i.email, 'lang', i.lang, 'expires_at', i.expires_at,
    'name', (select s.display_name from public.nfc_staff s where s.user_id = i.user_id),
    'state', case when i.activated_at is not null then 'used'
                  when i.revoked then 'revoked'
                  when i.expires_at < now() then 'expired'
                  when not exists (select 1 from public.nfc_staff s where s.user_id = i.user_id and s.active) then 'revoked'
                  else 'ok' end);
$$;

create or replace function public.nfc_invite_get(p_token_hash text, p_count boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  inv nfc_private.staff_invites;
  out jsonb;
begin
  select * into inv from nfc_private.staff_invites where token_hash = p_token_hash;
  if not found then return jsonb_build_object('state', 'not_found'); end if;
  out := nfc_private.invite_json(inv);
  if p_count and out ->> 'state' = 'ok' then
    update nfc_private.staff_invites
       set downloads = downloads + 1, first_download_at = coalesce(first_download_at, now())
     where id = inv.id;
  end if;
  return out;
end;
$$;

create or replace function public.nfc_invite_by_code(p_email text, p_code_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  inv nfc_private.staff_invites;
begin
  select * into inv from nfc_private.staff_invites
   where lower(email) = lower(p_email) and activated_at is null and not revoked
   order by created_at desc limit 1;
  if not found then return jsonb_build_object('state', 'not_found'); end if;
  if inv.code_hash <> p_code_hash then
    update nfc_private.staff_invites
       set attempts = attempts + 1, revoked = attempts + 1 >= 5
     where id = inv.id;
    return jsonb_build_object('state', case when inv.attempts + 1 >= 5 then 'locked' else 'bad_code' end);
  end if;
  return nfc_private.invite_json(inv);
end;
$$;

create or replace function public.nfc_invite_activate(
  p_invite uuid, p_session uuid, p_device text, p_model text, p_platform text, p_os text, p_app text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  inv nfc_private.staff_invites;
begin
  update nfc_private.staff_invites set activated_at = now()
   where id = p_invite and activated_at is null and not revoked and expires_at > now()
  returning * into inv;
  if not found then return jsonb_build_object('ok', false); end if;
  update nfc_private.staff_devices set status = 'revoked', session_id = null
   where user_id = inv.user_id and device_id is distinct from p_device and status <> 'revoked';
  insert into nfc_private.staff_devices (user_id, device_id, model, platform, os, app_build, status, session_id, approved_at)
  values (inv.user_id, p_device, left(p_model, 120), left(p_platform, 20), left(p_os, 60), left(p_app, 20), 'active', p_session, now())
  on conflict (user_id, device_id) do update
    set status = 'active', session_id = p_session, last_seen = now(), approved_at = now(),
        model = excluded.model, platform = excluded.platform, os = excluded.os, app_build = excluded.app_build;
  perform nfc_private.end_sessions(inv.user_id, p_session);
  insert into public.nfc_network_events (actor_id, action, subject_type, subject_id, subject_name, details)
  select inv.user_id, 'staff_activated', 'staff', inv.user_id, coalesce(s.display_name, ''),
         jsonb_build_object('model', p_model)
    from public.nfc_staff s where s.user_id = inv.user_id;
  return jsonb_build_object('ok', true, 'user_id', inv.user_id);
end;
$$;

create or replace function public.nfc_invite_mark(p_invite uuid, p_status text)
returns void language sql security definer set search_path = '' as $$
  update nfc_private.staff_invites set email_status = left(p_status, 40) where id = p_invite;
$$;

-- --------------------------------------------------- releases (server only)

create or replace function public.nfc_app_release_set(p_manifest jsonb)
returns void language sql security definer set search_path = '' as $$
  insert into nfc_private.app_release (id, manifest, updated_at) values (1, p_manifest, now())
  on conflict (id) do update set manifest = excluded.manifest, updated_at = now();
$$;

create or replace function public.nfc_app_release_get()
returns jsonb language sql stable security definer set search_path = '' as $$
  select manifest from nfc_private.app_release where id = 1;
$$;

-- ------------------------------------------------------------ privileges

revoke all on function
  public.nfc_device_hello(text, text, text, text, text, text), public.nfc_device_requests(),
  public.nfc_device_decide(uuid, boolean), public.nfc_device_reset(uuid),
  public.nfc_staff_security(uuid), public.nfc_network_devices(),
  public.nfc_invite_new(uuid, text, text, uuid, text, text), public.nfc_invite_get(text, boolean),
  public.nfc_invite_by_code(text, text),
  public.nfc_invite_activate(uuid, uuid, text, text, text, text, text),
  public.nfc_invite_mark(uuid, text), public.nfc_app_release_set(jsonb), public.nfc_app_release_get()
  from public, anon, authenticated;
grant execute on function
  public.nfc_device_hello(text, text, text, text, text, text), public.nfc_device_requests(),
  public.nfc_device_decide(uuid, boolean), public.nfc_device_reset(uuid),
  public.nfc_staff_security(uuid), public.nfc_network_devices()
  to authenticated;
grant execute on function
  public.nfc_invite_new(uuid, text, text, uuid, text, text), public.nfc_invite_get(text, boolean),
  public.nfc_invite_by_code(text, text),
  public.nfc_invite_activate(uuid, uuid, text, text, text, text, text),
  public.nfc_invite_mark(uuid, text), public.nfc_app_release_set(jsonb), public.nfc_app_release_get()
  to service_role;
revoke all on function nfc_private.end_sessions(uuid, uuid) from public, anon, authenticated;
