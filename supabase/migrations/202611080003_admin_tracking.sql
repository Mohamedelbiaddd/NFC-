-- Primary administrator, field-worker accounts and full activity tracking.
-- Apply after 202611080002_profile_image_storage.sql.
--
-- 1) public.nfc_super_admins: accounts with absolute permissions.
-- 2) nfc_profiles.created_by / updated_by are stamped by trigger (never by the client).
-- 3) public.nfc_activity: append-only audit trail written by triggers/RPCs only.
-- 4) public.nfc_workers: usernames for field staff, created through the
--    admin-workers Edge Function (service role) because passwords live in auth.

-- 1. Super administrators -----------------------------------------------------
create table if not exists public.nfc_super_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);
alter table public.nfc_super_admins enable row level security;
revoke all on public.nfc_super_admins from public, anon, authenticated;

create or replace function nfc_private.is_super_admin(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path='' as $$
  select uid is not null and exists (
    select 1 from public.nfc_super_admins s where s.user_id = uid
  );
$$;
revoke all on function nfc_private.is_super_admin(uuid) from public;
grant execute on function nfc_private.is_super_admin(uuid) to authenticated;

-- Super administrators pass every has_role() check, in every workspace.
create or replace function nfc_private.has_role(
  t uuid,
  roles text[] default array['owner','admin','editor','viewer']
) returns boolean language sql stable security definer set search_path='' as $$
  select nfc_private.is_super_admin(auth.uid())
    or exists (
      select 1 from public.nfc_memberships
      where tenant_id = t and user_id = auth.uid() and role = any(roles)
    );
$$;
revoke all on function nfc_private.has_role(uuid,text[]) from public;
grant execute on function nfc_private.has_role(uuid,text[]) to authenticated;

-- The workspace owner is the primary administrator (idempotent).
insert into public.nfc_super_admins (user_id, note)
select id, 'Primary administrator' from auth.users
where email = 'mohamed.elbiad.2025@gmail.com'
on conflict (user_id) do nothing;

create or replace function public.nfc_am_super_admin() returns boolean
language sql stable security definer set search_path='' as $$
  select nfc_private.is_super_admin(auth.uid());
$$;
revoke all on function public.nfc_am_super_admin() from public;
grant execute on function public.nfc_am_super_admin() to authenticated;

-- 2. Authorship on profiles ---------------------------------------------------
alter table public.nfc_profiles
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

update public.nfc_profiles p
set created_by = t.owner_id
from public.nfc_tenants t
where t.id = p.tenant_id and p.created_by is null;

create or replace function nfc_private.stamp_profile_actor() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    new.created_by := old.created_by;
  end if;
  new.updated_by := auth.uid();
  return new;
end; $$;
revoke all on function nfc_private.stamp_profile_actor() from public;
drop trigger if exists nfc_profile_actor on public.nfc_profiles;
create trigger nfc_profile_actor before insert or update on public.nfc_profiles
  for each row execute function nfc_private.stamp_profile_actor();

-- 3. Field workers ------------------------------------------------------------
create table if not exists public.nfc_workers (
  id uuid primary key references auth.users(id) on delete cascade,
  tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
  username text not null,
  display_name text not null,
  created_by uuid references auth.users(id) on delete set null,
  disabled boolean not null default false,
  created_at timestamptz not null default now(),
  constraint nfc_workers_username_format
    check (username ~ '^[a-z0-9][a-z0-9_.-]{2,31}$'),
  constraint nfc_workers_display_name_len
    check (length(display_name) between 2 and 80)
);
create unique index if not exists nfc_workers_username_key
  on public.nfc_workers (lower(username));
create index if not exists nfc_workers_tenant_idx
  on public.nfc_workers (tenant_id);
alter table public.nfc_workers enable row level security;
revoke all on public.nfc_workers from public, anon, authenticated;
grant select on public.nfc_workers to authenticated;
drop policy if exists worker_read on public.nfc_workers;
create policy worker_read on public.nfc_workers for select to authenticated
  using (nfc_private.has_role(tenant_id));

-- 4. Activity trail -----------------------------------------------------------
create table if not exists public.nfc_activity (
  id bigserial primary key,
  tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  subject text,
  subject_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint nfc_activity_action_check check (action in (
    'profile_created','profile_updated','profile_deleted','business_created',
    'worker_created','worker_updated','worker_password_reset','worker_disabled',
    'worker_deleted','card_written','card_verified','card_locked','qr_saved',
    'login')),
  constraint nfc_activity_details_size check (octet_length(details::text) <= 4000),
  constraint nfc_activity_subject_len check (subject is null or length(subject) <= 200)
);
create index if not exists nfc_activity_tenant_time_idx
  on public.nfc_activity (tenant_id, created_at desc);
create index if not exists nfc_activity_actor_idx
  on public.nfc_activity (actor_id, created_at desc);
alter table public.nfc_activity enable row level security;
revoke all on public.nfc_activity from public, anon, authenticated;
grant select on public.nfc_activity to authenticated;
drop policy if exists activity_read on public.nfc_activity;
create policy activity_read on public.nfc_activity for select to authenticated
  using (nfc_private.has_role(tenant_id));

create or replace function nfc_private.log_profile_change() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op = 'DELETE' then
    insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id,details)
    values (old.tenant_id, auth.uid(), 'profile_deleted', old.title, old.id,
      jsonb_build_object('kind', old.kind, 'slug', old.custom_slug));
    return null;
  end if;
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id,details)
  values (new.tenant_id, auth.uid(),
    case tg_op when 'INSERT' then 'profile_created' else 'profile_updated' end,
    new.title, new.id,
    jsonb_build_object('kind', new.kind, 'slug', new.custom_slug,
      'published', new.published, 'has_image', new.image_url is not null));
  return null;
end; $$;
revoke all on function nfc_private.log_profile_change() from public;
drop trigger if exists nfc_profile_activity on public.nfc_profiles;
create trigger nfc_profile_activity after insert or update or delete
  on public.nfc_profiles for each row
  execute function nfc_private.log_profile_change();

create or replace function nfc_private.log_business_created() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id,details)
  values (new.tenant_id, auth.uid(), 'business_created', new.name, new.id,
    jsonb_build_object('primary_color', new.primary_color,
      'accent_color', new.accent_color));
  return null;
end; $$;
revoke all on function nfc_private.log_business_created() from public;
drop trigger if exists nfc_business_activity on public.nfc_businesses;
create trigger nfc_business_activity after insert on public.nfc_businesses
  for each row execute function nfc_private.log_business_created();

create or replace function nfc_private.log_write_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare mapped text;
begin
  mapped := case new.action
    when 'written_verified' then 'card_written'
    when 'formatted_unverified' then 'card_written'
    when 'verified' then 'card_verified'
    when 'locked' then 'card_locked'
    else null end;
  if mapped is null then return null; end if;
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id,details)
  values (new.tenant_id, new.actor_id, mapped,
    (select p.title from public.nfc_profiles p where p.id = new.profile_id),
    new.profile_id, jsonb_build_object('write_event', new.action));
  return null;
end; $$;
revoke all on function nfc_private.log_write_event() from public;
drop trigger if exists nfc_write_event_activity on public.nfc_write_events;
create trigger nfc_write_event_activity after insert on public.nfc_write_events
  for each row execute function nfc_private.log_write_event();

-- Client-side events the app reports itself (the actor is always auth.uid()).
create or replace function public.nfc_log_event(
  workspace_id uuid,
  event_action text,
  event_subject text default null,
  event_details jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if event_action not in ('qr_saved','login','worker_created','worker_updated',
      'worker_password_reset','worker_disabled','worker_deleted') then
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
revoke all on function public.nfc_log_event(uuid,text,text,jsonb) from public;
grant execute on function public.nfc_log_event(uuid,text,text,jsonb)
  to authenticated;

-- 5. Admin reporting ----------------------------------------------------------
create or replace function public.nfc_team_overview(workspace_id uuid)
returns table(
  user_id uuid, email text, display_name text, role text, username text,
  profiles_created bigint, cards_written bigint, cards_locked bigint,
  actions bigint, last_active timestamptz
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
         s.last_active
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
  where m.tenant_id = workspace_id
    and nfc_private.has_role(workspace_id, array['owner','admin'])
  order by (m.role = 'owner') desc, coalesce(s.last_active, u.created_at) desc;
$$;
revoke all on function public.nfc_team_overview(uuid) from public;
grant execute on function public.nfc_team_overview(uuid) to authenticated;

create or replace function public.nfc_activity_feed(
  workspace_id uuid,
  max_rows int default 100
) returns table(
  id bigint, actor_id uuid, actor text, action text, subject text,
  subject_id uuid, details jsonb, created_at timestamptz
) language sql stable security definer set search_path='' as $$
  select a.id, a.actor_id,
         coalesce(w.display_name, split_part(u.email, '@', 1), 'النظام') as actor,
         a.action, a.subject, a.subject_id, a.details, a.created_at
  from public.nfc_activity a
  left join auth.users u on u.id = a.actor_id
  left join public.nfc_workers w on w.id = a.actor_id
  where a.tenant_id = workspace_id and nfc_private.has_role(workspace_id)
  order by a.created_at desc
  limit least(greatest(max_rows, 1), 500);
$$;
revoke all on function public.nfc_activity_feed(uuid,int) from public;
grant execute on function public.nfc_activity_feed(uuid,int) to authenticated;
