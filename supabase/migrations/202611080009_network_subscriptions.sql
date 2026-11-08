-- Staff networks, strict isolation and monthly subscriptions.
--
-- * nfc_staff is a tree: the super admin creates agents (and workers); an agent
--   creates workers under them. Every account still gets its own personal
--   workspace (nfc_private.provision_user), so its shops live there.
-- * A member sees only their own subtree (people they created, people those
--   created, ...) and the shops created inside it. Siblings never see each
--   other. Super admins see everything.
-- * Shops and staff carry paid_until: marking a payment extends it by one
--   month; green while paid_until >= today, red afterwards.
-- * Shops can be suspended: public card, loyalty pages and owner dashboard stop.

create table if not exists public.nfc_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  parent_id uuid references auth.users(id) on delete set null,
  role text not null check (role in ('agent', 'worker')),
  display_name text not null check (length(display_name) between 1 and 80),
  email text not null,
  active boolean not null default true,
  paid_until date,
  created_at timestamptz not null default now()
);
create index if not exists nfc_staff_parent on public.nfc_staff(parent_id);
alter table public.nfc_staff enable row level security;
revoke all on public.nfc_staff from public, anon, authenticated;

alter table public.nfc_businesses
  add column if not exists suspended boolean not null default false,
  add column if not exists paid_until date;

create table if not exists public.nfc_payments (
  id bigint generated always as identity primary key,
  subject_type text not null check (subject_type in ('shop', 'staff')),
  subject_id uuid not null,
  months int not null default 1 check (months between 1 and 12),
  amount numeric(10, 2),
  previous_until date,
  new_until date not null,
  paid_by uuid references auth.users(id) on delete set null,
  undone boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists nfc_payments_subject on public.nfc_payments(subject_type, subject_id, created_at desc);
alter table public.nfc_payments enable row level security;
revoke all on public.nfc_payments from public, anon, authenticated;

create table if not exists public.nfc_network_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  subject_type text not null,
  subject_id uuid,
  subject_name text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists nfc_network_events_time on public.nfc_network_events(created_at desc);
alter table public.nfc_network_events enable row level security;
revoke all on public.nfc_network_events from public, anon, authenticated;

-- Helpers ---------------------------------------------------------------------
-- True when `target` is `manager` or somewhere below them in the tree.
create or replace function nfc_private.in_subtree(manager uuid, target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  with recursive up(id, depth) as (
    select target, 0
    union all
    select s.parent_id, up.depth + 1
    from public.nfc_staff s join up on s.user_id = up.id
    where s.parent_id is not null and up.depth < 20
  )
  select manager is not null and target is not null
         and exists (select 1 from up where id = manager);
$$;

-- The caller may manage `target` (a strict descendant, or anyone for admins).
create or replace function nfc_private.manages(target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.is_super_admin(auth.uid())
      or (target is distinct from auth.uid() and nfc_private.in_subtree(auth.uid(), target));
$$;

create or replace function nfc_private.can_manage_shop(b public.nfc_businesses)
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.is_super_admin(auth.uid())
      or b.created_by = auth.uid()
      or nfc_private.in_subtree(auth.uid(), b.created_by)
      or nfc_private.has_role(b.tenant_id, array['owner', 'admin']);
$$;

create or replace function nfc_private.pay_status(paid_until date)
returns text language sql stable set search_path = '' as $$
  select case when paid_until is null then 'never'
              when paid_until >= current_date then 'paid'
              else 'expired' end;
$$;

create or replace function nfc_private.log_network(action text, subject_type text, subject_id uuid,
                                                   subject_name text, details jsonb default '{}'::jsonb)
returns void language sql security definer set search_path = '' as $$
  insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name, details)
  values (auth.uid(), action, subject_type, subject_id, left(subject_name, 200), coalesce(details, '{}'::jsonb));
$$;

-- Suspended shops disappear from every public surface.
create or replace function nfc_private.shop_by_slug(target_slug text)
returns public.nfc_businesses language sql stable security definer set search_path = '' as $$
  select * from public.nfc_businesses
  where shop_slug = lower(trim(target_slug)) and loyalty_enabled = true and not suspended;
$$;

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
    and not b.suspended
    and length(coalesce(slug, '')) between 3 and 63;
$$;

-- Account -----------------------------------------------------------------------
create or replace function public.nfc_my_account()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'is_super_admin', nfc_private.is_super_admin(auth.uid()),
    'staff', (select jsonb_build_object('role', s.role, 'name', s.display_name,
                     'active', s.active, 'paid_until', s.paid_until,
                     'status', nfc_private.pay_status(s.paid_until))
              from public.nfc_staff s where s.user_id = auth.uid()),
    'allowed', nfc_private.is_super_admin(auth.uid())
               or exists (select 1 from public.nfc_staff s where s.user_id = auth.uid() and s.active));
$$;

-- Used by the staff-admin edge function with the caller's JWT.
create or replace function public.nfc_can_create_staff(new_role text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when nfc_private.is_super_admin(auth.uid()) then new_role in ('agent', 'worker')
    else new_role = 'worker' and exists (
      select 1 from public.nfc_staff s
      where s.user_id = auth.uid() and s.role = 'agent' and s.active)
  end;
$$;

create or replace function public.nfc_can_manage_staff(target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.manages(target);
$$;

-- Network views ----------------------------------------------------------------
create or replace function public.nfc_network_members()
returns table(user_id uuid, parent_id uuid, parent_name text, email text, name text, role text,
              active boolean, banned boolean, paid_until date, status text, shops bigint,
              members bigint, last_sign_in timestamptz, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select s.user_id, s.parent_id,
         coalesce(ps.display_name, case when nfc_private.is_super_admin(s.parent_id) then 'الإدارة' end),
         s.email, s.display_name, s.role, s.active,
         coalesce(u.banned_until > now(), false), s.paid_until, nfc_private.pay_status(s.paid_until),
         (select count(*) from public.nfc_businesses b where b.created_by = s.user_id and b.shop_slug is not null),
         (select count(*) from public.nfc_staff c where c.parent_id = s.user_id),
         u.last_sign_in_at, s.created_at
  from public.nfc_staff s
  left join public.nfc_staff ps on ps.user_id = s.parent_id
  left join auth.users u on u.id = s.user_id
  where nfc_private.manages(s.user_id)
  order by s.created_at;
$$;

create or replace function public.nfc_network_shops()
returns table(id uuid, tenant_id uuid, name text, shop_slug text, loyalty_enabled boolean,
              suspended boolean, paid_until date, status text,
              goal int, reward text, phone text, address text, hours text, industry text,
              latitude double precision, longitude double precision, radius_m int,
              created_by uuid, creator text, customers bigint, visits bigint, visits_7d bigint,
              has_password boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.id, b.tenant_id, b.name, b.shop_slug, b.loyalty_enabled, b.suspended, b.paid_until,
         nfc_private.pay_status(b.paid_until),
         b.loyalty_goal, b.loyalty_reward, b.phone, b.address, b.hours, b.industry,
         b.latitude, b.longitude, b.geofence_radius_m, b.created_by,
         coalesce(st.display_name, w.display_name, split_part(u.email, '@', 1)),
         (select count(*) from public.nfc_customers c where c.business_id = b.id),
         (select count(*) from public.nfc_visits v where v.business_id = b.id and not v.voided),
         (select count(*) from public.nfc_visits v where v.business_id = b.id and not v.voided
            and v.created_at > now() - interval '7 days'),
         exists (select 1 from nfc_private.shop_secrets s
                 where s.business_id = b.id and s.owner_pass_hash is not null),
         b.created_at
  from public.nfc_businesses b
  left join auth.users u on u.id = b.created_by
  left join public.nfc_staff st on st.user_id = b.created_by
  left join public.nfc_workers w on w.id = b.created_by
  where b.shop_slug is not null and nfc_private.can_manage_shop(b)
  order by b.created_at desc;
$$;

create or replace function public.nfc_network_events_feed(max_rows int default 100)
returns table(id bigint, actor text, action text, subject_type text, subject_name text,
              details jsonb, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select e.id, coalesce(s.display_name, split_part(u.email, '@', 1), 'النظام'),
         e.action, e.subject_type, e.subject_name, e.details, e.created_at
  from public.nfc_network_events e
  left join public.nfc_staff s on s.user_id = e.actor_id
  left join auth.users u on u.id = e.actor_id
  where nfc_private.is_super_admin(auth.uid())
     or e.actor_id = auth.uid()
     or nfc_private.in_subtree(auth.uid(), e.actor_id)
  order by e.created_at desc
  limit least(greatest(max_rows, 1), 500);
$$;

-- Actions -----------------------------------------------------------------------
-- Marks one (or more) months as paid for a shop or a staff member.
create or replace function public.nfc_mark_paid(subject text, target uuid, months int default 1,
                                               amount numeric default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare prev date; next_until date; label text; b public.nfc_businesses; st public.nfc_staff;
begin
  if months not between 1 and 12 then raise exception 'Invalid months'; end if;
  if subject = 'shop' then
    select * into b from public.nfc_businesses where id = target;
    if b.id is null or not nfc_private.can_manage_shop(b) then raise exception 'Not authorized'; end if;
    prev := b.paid_until; label := b.name;
  elsif subject = 'staff' then
    select * into st from public.nfc_staff where user_id = target;
    if st.user_id is null or not nfc_private.manages(target) then raise exception 'Not authorized'; end if;
    prev := st.paid_until; label := st.display_name;
  else
    raise exception 'Invalid subject';
  end if;
  next_until := (greatest(coalesce(prev, current_date - 1), current_date - 1)
                 + make_interval(months => months))::date;
  if subject = 'shop' then
    update public.nfc_businesses set paid_until = next_until where id = target;
  else
    update public.nfc_staff set paid_until = next_until where user_id = target;
  end if;
  insert into public.nfc_payments(subject_type, subject_id, months, amount, previous_until, new_until, paid_by)
  values (subject, target, months, amount, prev, next_until, auth.uid());
  perform nfc_private.log_network('payment', subject, target, label,
    jsonb_build_object('months', months, 'amount', amount, 'until', next_until));
  return jsonb_build_object('paid_until', next_until, 'status', nfc_private.pay_status(next_until));
end; $$;

-- Undo the latest payment (a checkbox ticked by mistake).
create or replace function public.nfc_undo_payment(subject text, target uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_payments; label text; b public.nfc_businesses;
begin
  if subject = 'shop' then
    select * into b from public.nfc_businesses where id = target;
    if b.id is null or not nfc_private.can_manage_shop(b) then raise exception 'Not authorized'; end if;
    label := b.name;
  elsif subject = 'staff' then
    if not nfc_private.manages(target) then raise exception 'Not authorized'; end if;
    select display_name into label from public.nfc_staff where user_id = target;
  else
    raise exception 'Invalid subject';
  end if;
  select * into p from public.nfc_payments
   where subject_type = subject and subject_id = target and not undone
   order by created_at desc limit 1;
  if p.id is null then return jsonb_build_object('ok', false); end if;
  update public.nfc_payments set undone = true where id = p.id;
  if subject = 'shop' then
    update public.nfc_businesses set paid_until = p.previous_until where id = target;
  else
    update public.nfc_staff set paid_until = p.previous_until where user_id = target;
  end if;
  perform nfc_private.log_network('payment_undone', subject, target, label, '{}'::jsonb);
  return jsonb_build_object('ok', true, 'paid_until', p.previous_until,
                            'status', nfc_private.pay_status(p.previous_until));
end; $$;

create or replace function public.nfc_set_shop_suspended(target uuid, value boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target;
  if b.id is null or not nfc_private.can_manage_shop(b) then raise exception 'Not authorized'; end if;
  update public.nfc_businesses set suspended = value where id = target;
  if value then delete from nfc_private.shop_sessions where business_id = target; end if;
  perform nfc_private.log_network(case when value then 'shop_suspended' else 'shop_resumed' end,
                                  'shop', target, b.name, '{}'::jsonb);
end; $$;

-- Suspends / resumes a staff login (and optionally all shops they created).
create or replace function public.nfc_set_staff_active(target uuid, value boolean, include_shops boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare st public.nfc_staff;
begin
  select * into st from public.nfc_staff where user_id = target;
  if st.user_id is null or not nfc_private.manages(target) then raise exception 'Not authorized'; end if;
  update public.nfc_staff set active = value where user_id = target;
  update auth.users
     set banned_until = case when value then null else now() + interval '876000 hours' end,
         updated_at = now()
   where id = target;
  if include_shops then
    update public.nfc_businesses set suspended = not value where created_by = target;
    if not value then
      delete from nfc_private.shop_sessions s
       using public.nfc_businesses b where b.id = s.business_id and b.created_by = target;
    end if;
  end if;
  perform nfc_private.log_network(case when value then 'staff_resumed' else 'staff_suspended' end,
                                  'staff', target, st.display_name,
                                  jsonb_build_object('shops', include_shops));
end; $$;

-- Called by the staff-admin edge function (service role) after creating the
-- auth user; actor is passed explicitly because the service role has no uid.
create or replace function public.nfc_register_staff(actor uuid, new_user uuid, new_role text,
                                                    new_name text, new_email text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.nfc_staff(user_id, parent_id, role, display_name, email)
  values (new_user, actor, new_role, left(trim(new_name), 80), lower(trim(new_email)));
  insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name, details)
  values (actor, 'staff_created', 'staff', new_user, left(trim(new_name), 200),
          jsonb_build_object('role', new_role, 'email', lower(trim(new_email))));
end; $$;

create or replace function public.nfc_log_staff_password_reset(actor uuid, target uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
  select actor, 'password_reset', 'staff', target, s.display_name
  from public.nfc_staff s where s.user_id = target;
$$;

-- Shop events into the network feed (created by app users).
create or replace function nfc_private.log_shop_created()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.shop_slug is not null and (tg_op = 'INSERT' or old.shop_slug is null) then
    insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
    values (auth.uid(), 'shop_created', 'shop', new.id, new.name);
  end if;
  return null;
end; $$;
drop trigger if exists nfc_business_network_log on public.nfc_businesses;
create trigger nfc_business_network_log after insert or update of shop_slug on public.nfc_businesses
  for each row execute function nfc_private.log_shop_created();

-- Existing staff-side RPCs now follow the network rules too.
create or replace function public.nfc_shop_disable(target_business uuid, disabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.nfc_set_shop_suspended(target_business, disabled);
end; $$;

create or replace function public.nfc_shop_setup(
  target_business uuid, slug text, goal int, reward text, owner_password text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target_business;
  if b.id is null then raise exception 'Business not found'; end if;
  if not (nfc_private.has_role(b.tenant_id, array['owner','admin','editor'])
          or nfc_private.can_manage_shop(b)) then
    raise exception 'Not authorized';
  end if;
  if exists (select 1 from public.nfc_businesses
             where shop_slug = lower(trim(slug)) and id <> b.id) then
    raise exception 'Slug already used' using errcode = '23505';
  end if;
  update public.nfc_businesses
     set shop_slug = lower(trim(slug)), loyalty_enabled = true,
         loyalty_goal = coalesce(goal, loyalty_goal),
         loyalty_reward = coalesce(nullif(trim(reward), ''), loyalty_reward)
   where id = b.id;
  insert into nfc_private.shop_secrets(business_id) values (b.id) on conflict do nothing;
  if owner_password is not null and owner_password <> '' then
    if length(owner_password) not between 6 and 72 then
      raise exception 'Password must be 6-72 characters';
    end if;
    update nfc_private.shop_secrets
       set owner_pass_hash = extensions.crypt(owner_password, extensions.gen_salt('bf', 8)),
           failed_attempts = 0, locked_until = null
     where business_id = b.id;
    delete from nfc_private.shop_sessions where business_id = b.id;
  end if;
end; $$;

-- Shop details edited from the app by a manager in the network.
create or replace function public.nfc_shop_edit(target uuid, settings jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target;
  if b.id is null or not (nfc_private.can_manage_shop(b)
     or nfc_private.has_role(b.tenant_id, array['owner','admin','editor'])) then
    raise exception 'Not authorized';
  end if;
  update public.nfc_businesses set
    name = coalesce(nullif(trim(settings ->> 'name'), ''), name),
    industry = coalesce(nullif(settings ->> 'industry', ''), industry),
    phone = case when settings ? 'phone' then nullif(trim(settings ->> 'phone'), '') else phone end,
    address = case when settings ? 'address' then nullif(trim(settings ->> 'address'), '') else address end,
    hours = case when settings ? 'hours' then nullif(trim(settings ->> 'hours'), '') else hours end,
    latitude = case when settings ? 'latitude' then (settings ->> 'latitude')::double precision else latitude end,
    longitude = case when settings ? 'longitude' then (settings ->> 'longitude')::double precision else longitude end,
    geofence_radius_m = coalesce((settings ->> 'radius_m')::int, geofence_radius_m)
  where id = target;
end; $$;

revoke all on function
  public.nfc_my_account(), public.nfc_can_create_staff(text), public.nfc_can_manage_staff(uuid),
  public.nfc_network_members(), public.nfc_network_shops(), public.nfc_network_events_feed(int),
  public.nfc_mark_paid(text, uuid, int, numeric), public.nfc_undo_payment(text, uuid),
  public.nfc_set_shop_suspended(uuid, boolean), public.nfc_set_staff_active(uuid, boolean, boolean),
  public.nfc_register_staff(uuid, uuid, text, text, text),
  public.nfc_log_staff_password_reset(uuid, uuid), public.nfc_shop_edit(uuid, jsonb)
from public, anon;
grant execute on function
  public.nfc_my_account(), public.nfc_can_create_staff(text), public.nfc_can_manage_staff(uuid),
  public.nfc_network_members(), public.nfc_network_shops(), public.nfc_network_events_feed(int),
  public.nfc_mark_paid(text, uuid, int, numeric), public.nfc_undo_payment(text, uuid),
  public.nfc_set_shop_suspended(uuid, boolean), public.nfc_set_staff_active(uuid, boolean, boolean),
  public.nfc_shop_edit(uuid, jsonb)
to authenticated;
revoke all on function public.nfc_register_staff(uuid, uuid, text, text, text),
  public.nfc_log_staff_password_reset(uuid, uuid) from authenticated;
grant execute on function public.nfc_register_staff(uuid, uuid, text, text, text),
  public.nfc_log_staff_password_reset(uuid, uuid) to service_role;
