-- 202611080004_security_scans_users.sql
--
-- 1. A single, e-mail based super administrator allowlist.
-- 2. Automatic provisioning of a private workspace for every new signup, so
--    each account lands in the normal working UI and shows up for monitoring.
-- 3. Anonymous scan (tap / QR / link) counting per profile.
-- 4. Super-admin reporting: every account + what it produced, plus ban/unban.
-- 5. Hardening: no anon table access, RLS everywhere, safe definer functions.

-- 1. Super administrator allowlist -------------------------------------------
create schema if not exists nfc_private;

create table if not exists nfc_private.admin_emails (
  email text primary key check (email = lower(email) and email like '%@%'),
  note text,
  created_at timestamptz not null default now()
);
revoke all on nfc_private.admin_emails from public, anon, authenticated;

insert into nfc_private.admin_emails (email, note)
values ('mohamed.elbiad.2025@gmail.com', 'Primary administrator')
on conflict (email) do nothing;

-- Promote the allowlisted address the moment that account exists.
create or replace function nfc_private.promote_admin_email() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.email is null then return new; end if;
  if exists (
    select 1 from nfc_private.admin_emails e where e.email = lower(new.email)
  ) then
    insert into public.nfc_super_admins (user_id, note)
    values (new.id, 'allowlisted e-mail')
    on conflict (user_id) do nothing;
  end if;
  return new;
end; $$;
revoke all on function nfc_private.promote_admin_email() from public;

drop trigger if exists nfc_promote_admin on auth.users;
create trigger nfc_promote_admin after insert or update of email on auth.users
  for each row execute function nfc_private.promote_admin_email();

-- Existing accounts that already match the allowlist.
insert into public.nfc_super_admins (user_id, note)
select u.id, 'allowlisted e-mail'
from auth.users u
join nfc_private.admin_emails e on e.email = lower(u.email)
on conflict (user_id) do nothing;

-- is_super_admin() also honours the allowlist, so a freshly confirmed account
-- is an administrator even before the trigger has run on a replica.
create or replace function nfc_private.is_super_admin(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path='' as $$
  select uid is not null and (
    exists (select 1 from public.nfc_super_admins s where s.user_id = uid)
    or exists (
      select 1
      from auth.users u
      join nfc_private.admin_emails e on e.email = lower(u.email)
      where u.id = uid
    )
  );
$$;
revoke all on function nfc_private.is_super_admin(uuid) from public;
grant execute on function nfc_private.is_super_admin(uuid) to authenticated;

-- 2. Every new account gets its own workspace + default identity --------------
create or replace function nfc_private.log_business_created() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then
    return null;
  end if;
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id,details)
  values (new.tenant_id, auth.uid(), 'business_created', new.name, new.id,
    jsonb_build_object('primary_color', new.primary_color,
      'accent_color', new.accent_color));
  return null;
end; $$;
revoke all on function nfc_private.log_business_created() from public;

create or replace function nfc_private.provision_user() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  ws uuid;
  label text;
begin
  if exists (select 1 from public.nfc_super_admins s where s.user_id = new.id) then
    return new;
  end if;
  if exists (
    select 1 from public.nfc_memberships m
    where m.user_id = new.id and m.role = 'owner'
  ) then
    return new;
  end if;
  label := left(
    coalesce(nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'nfc'),
    100
  );
  insert into public.nfc_tenants (name, owner_id)
  values (label || ' · مساحة عمل', new.id)
  returning id into ws;
  insert into public.nfc_memberships (tenant_id, user_id, role)
  values (ws, new.id, 'owner');
  insert into public.nfc_businesses (tenant_id, name)
  values (ws, 'هويتي');
  insert into public.nfc_activity (tenant_id, actor_id, action, subject)
  values (ws, new.id, 'user_joined', left(coalesce(new.email, ''), 200));
  return new;
end; $$;
revoke all on function nfc_private.provision_user() from public;

drop trigger if exists nfc_provision_user on auth.users;
create trigger nfc_provision_user after insert on auth.users
  for each row execute function nfc_private.provision_user();

-- Accounts created before this migration that still have no workspace.
do $$
declare u record; ws uuid; label text;
begin
  for u in
    select au.id, au.email from auth.users au
    where not exists (
      select 1 from public.nfc_memberships m where m.user_id = au.id
    )
    and not exists (select 1 from public.nfc_super_admins s where s.user_id = au.id)
  loop
    label := left(
      coalesce(nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'nfc'),
      100
    );
    insert into public.nfc_tenants (name, owner_id)
    values (label || ' · مساحة عمل', u.id)
    returning id into ws;
    insert into public.nfc_memberships (tenant_id, user_id, role)
    values (ws, u.id, 'owner')
    on conflict do nothing;
    insert into public.nfc_businesses (tenant_id, name) values (ws, 'هويتي');
  end loop;
end $$;

-- 3. Scan counting (public, anonymous, cheap) --------------------------------
create table if not exists public.nfc_scans (
  id bigserial primary key,
  tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
  profile_id uuid not null references public.nfc_profiles(id) on delete cascade,
  source text not null default 'link'
    check (source in ('link','qr','nfc')),
  user_agent text,
  created_at timestamptz not null default now()
);
create index if not exists nfc_scans_tenant_time_idx
  on public.nfc_scans (tenant_id, created_at desc);
create index if not exists nfc_scans_profile_time_idx
  on public.nfc_scans (profile_id, created_at desc);

alter table public.nfc_scans enable row level security;
revoke all on public.nfc_scans from public, anon, authenticated;
grant select on public.nfc_scans to authenticated;
drop policy if exists scan_read on public.nfc_scans;
create policy scan_read on public.nfc_scans for select to authenticated
  using (nfc_private.has_role(tenant_id));

-- Only published profiles are reachable and countable. Slugs are validated by
-- the check constraint on nfc_profiles, so no enumeration is possible here.
create or replace function public.nfc_track_scan(
  target_slug text,
  scan_source text default 'link',
  agent text default null
) returns void language plpgsql security definer set search_path='' as $$
declare
  target public.nfc_profiles;
  clean text;
begin
  if target_slug is null then return; end if;
  clean := lower(trim(target_slug));
  if length(clean) < 3 or length(clean) > 63 then return; end if;
  select * into target from public.nfc_profiles p
   where p.custom_slug = clean and p.published = true
   limit 1;
  if target.id is null then return; end if;
  -- Ignore duplicate hits from the same browser within five seconds.
  if exists (
    select 1 from public.nfc_scans s
    where s.profile_id = target.id
      and coalesce(s.user_agent, '') = left(coalesce(agent, ''), 300)
      and s.created_at > now() - interval '5 seconds'
  ) then
    return;
  end if;
  insert into public.nfc_scans (tenant_id, profile_id, source, user_agent)
  values (
    target.tenant_id,
    target.id,
    case when scan_source in ('link','qr','nfc') then scan_source else 'link' end,
    left(coalesce(agent, ''), 300)
  );
end; $$;
revoke all on function public.nfc_track_scan(text,text,text) from public;
grant execute on function public.nfc_track_scan(text,text,text) to anon, authenticated;

create or replace function public.nfc_scan_overview(workspace_id uuid)
returns table(
  profile_id uuid, title text, custom_slug text,
  scans bigint, last_scan timestamptz, scans_7d bigint
) language sql stable security definer set search_path='' as $$
  select p.id, p.title, p.custom_slug,
         coalesce(s.total, 0),
         s.last_scan,
         coalesce(s.recent, 0)
  from public.nfc_profiles p
  left join lateral (
    select count(*) as total,
           max(sc.created_at) as last_scan,
           count(*) filter (where sc.created_at > now() - interval '7 days') as recent
    from public.nfc_scans sc
    where sc.profile_id = p.id
  ) s on true
  where p.tenant_id = workspace_id
    and nfc_private.has_role(workspace_id)
  order by coalesce(s.total, 0) desc, p.title;
$$;
revoke all on function public.nfc_scan_overview(uuid) from public;
grant execute on function public.nfc_scan_overview(uuid) to authenticated;

-- 4. Extended activity vocabulary -------------------------------------------
alter table public.nfc_activity drop constraint if exists nfc_activity_action_check;
alter table public.nfc_activity add constraint nfc_activity_action_check
  check (action in (
    'profile_created','profile_updated','profile_deleted','business_created',
    'worker_created','worker_updated','worker_password_reset','worker_disabled',
    'worker_deleted','card_written','card_verified','card_locked','qr_saved',
    'login','user_joined','user_banned','user_unbanned'));

-- Team reporting now also reports the scans a member's profiles generated.
drop function if exists public.nfc_team_overview(uuid);
create or replace function public.nfc_team_overview(workspace_id uuid)
returns table(
  user_id uuid, email text, display_name text, role text, username text,
  profiles_created bigint, cards_written bigint, cards_locked bigint,
  actions bigint, last_active timestamptz, scans bigint, banned_until timestamptz
) language sql stable security definer set search_path='' as $$
  select m.user_id,
         u.email::text as email,
         coalesce(w.display_name, split_part(u.email, '@', 1)) as display_name,
         m.role,
         w.username,
         coalesce(s.profiles_created, 0),
         coalesce(s.cards_written, 0),
         coalesce(s.cards_locked, 0),
         coalesce(s.actions, 0),
         s.last_active,
         coalesce(sc.total, 0),
         u.banned_until
  from public.nfc_memberships m
  join auth.users u on u.id = m.user_id
  left join public.nfc_workers w on w.id = m.user_id
  left join lateral (
    select count(*) filter (where a.action = 'profile_created') as profiles_created,
           count(*) filter (where a.action = 'card_written') as cards_written,
           count(*) filter (where a.action = 'card_locked') as cards_locked,
           count(*) as actions,
           max(a.created_at) as last_active
    from public.nfc_activity a
    where a.tenant_id = m.tenant_id and a.actor_id = m.user_id
  ) s on true
  left join lateral (
    select count(*) as total
    from public.nfc_scans n
    join public.nfc_profiles p on p.id = n.profile_id
    where n.tenant_id = m.tenant_id and p.created_by = m.user_id
  ) sc on true
  where m.tenant_id = workspace_id
    and nfc_private.has_role(workspace_id, array['owner','admin'])
  order by (m.role = 'owner') desc, coalesce(s.last_active, u.created_at) desc;
$$;
revoke all on function public.nfc_team_overview(uuid) from public;
grant execute on function public.nfc_team_overview(uuid) to authenticated;

-- 5. Super-admin control panel ------------------------------------------------
create or replace function public.nfc_all_users(term text default null)
returns table(
  user_id uuid, email text, display_name text, signed_up timestamptz,
  last_sign_in timestamptz, banned_until timestamptz, workspaces bigint,
  profiles_created bigint, cards_written bigint, scans bigint,
  actions bigint, last_active timestamptz, is_admin boolean
) language plpgsql stable security definer set search_path='' as $$
begin
  if not nfc_private.is_super_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  return query
  select u.id,
         u.email::text,
         coalesce(w.display_name, split_part(u.email, '@', 1)),
         u.created_at,
         u.last_sign_in_at,
         u.banned_until,
         (select count(*) from public.nfc_memberships m where m.user_id = u.id),
         (select count(*) from public.nfc_profiles p where p.created_by = u.id),
         (select count(*) from public.nfc_activity a
           where a.actor_id = u.id and a.action = 'card_written'),
         (select count(*) from public.nfc_scans s
           join public.nfc_profiles p on p.id = s.profile_id
           where p.created_by = u.id),
         (select count(*) from public.nfc_activity a where a.actor_id = u.id),
         (select max(a.created_at) from public.nfc_activity a where a.actor_id = u.id),
         exists (select 1 from public.nfc_super_admins sa where sa.user_id = u.id)
  from auth.users u
  left join public.nfc_workers w on w.id = u.id
  where u.deleted_at is null
    and coalesce(u.is_anonymous, false) = false
    and (term is null or term = '' or u.email ilike '%' || term || '%')
  order by (exists (select 1 from public.nfc_super_admins sa where sa.user_id = u.id)) desc,
           u.created_at desc;
end; $$;
revoke all on function public.nfc_all_users(text) from public;
grant execute on function public.nfc_all_users(text) to authenticated;

create or replace function public.nfc_admin_set_user_state(
  target_id uuid,
  banned boolean
) returns void language plpgsql security definer set search_path='' as $$
declare
  mail text;
  ws uuid;
begin
  if not nfc_private.is_super_admin(auth.uid()) then
    raise exception 'Not authorized';
  end if;
  if target_id = auth.uid() then
    raise exception 'Cannot change your own account';
  end if;
  select u.email::text into mail from auth.users u where u.id = target_id;
  if mail is null then
    raise exception 'User not found';
  end if;
  update auth.users
     set banned_until = case
           when banned then now() + interval '876000 hours'
           else null
         end,
         updated_at = now()
   where id = target_id;
  select m.tenant_id into ws
  from public.nfc_memberships m
  where m.user_id = target_id
  order by m.tenant_id
  limit 1;
  if ws is not null then
    insert into public.nfc_activity (tenant_id, actor_id, action, subject, details)
    values (ws, auth.uid(),
            case when banned then 'user_banned' else 'user_unbanned' end,
            left(mail, 200), jsonb_build_object('banned', banned));
  end if;
end; $$;
revoke all on function public.nfc_admin_set_user_state(uuid,boolean) from public;
grant execute on function public.nfc_admin_set_user_state(uuid,boolean) to authenticated;

-- 6. Hardening ---------------------------------------------------------------
-- Anonymous visitors only ever touch the two public profile readers and the
-- scan counter; everything else is closed.
revoke all on public.nfc_tenants, public.nfc_memberships, public.nfc_businesses,
  public.nfc_profiles, public.nfc_write_events, public.nfc_workers,
  public.nfc_activity, public.nfc_super_admins, public.nfc_scans from anon;
revoke insert, update, delete on public.nfc_activity from authenticated;
revoke insert on public.nfc_super_admins from authenticated;
revoke update, delete on public.nfc_workers from authenticated;

-- Re-assert the authenticated read grants the app relies on.
grant select on public.nfc_tenants, public.nfc_memberships, public.nfc_businesses,
  public.nfc_profiles, public.nfc_write_events, public.nfc_workers,
  public.nfc_activity, public.nfc_scans to authenticated;

-- A member may only ever read their own membership rows; the admin policies
-- above already scope everything else by workspace.
drop policy if exists membership_self on public.nfc_memberships;
create policy membership_self on public.nfc_memberships for select to authenticated
  using (user_id = auth.uid() or nfc_private.has_role(tenant_id));

-- The public profile readers must never expose unpublished or deleted rows and
-- must return a stable, minimal payload.
create or replace function public.nfc_public_profile_by_slug(slug text)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'custom_slug', p.custom_slug, 'title', p.title, 'kind', p.kind,
    'image_url', p.image_url, 'data', p.data, 'updated_at', p.updated_at,
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
revoke all on function public.nfc_public_profile_by_slug(text) from public;
grant execute on function public.nfc_public_profile_by_slug(text) to anon, authenticated;

-- 7. Verification helpers ----------------------------------------------------
create or replace function public.nfc_security_self_check()
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'is_super_admin', nfc_private.is_super_admin(auth.uid()),
    'tables_without_rls', (
      select coalesce(jsonb_agg(c.relname), '[]'::jsonb)
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
    ),
    'anon_table_grants', (
      select count(*) from information_schema.role_table_grants g
      where g.grantee = 'anon' and g.table_schema = 'public'
    )
  );
$$;
revoke all on function public.nfc_security_self_check() from public;
grant execute on function public.nfc_security_self_check() to authenticated;
