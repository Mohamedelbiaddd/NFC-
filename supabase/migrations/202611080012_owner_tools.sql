-- Owner tools: loyalty card background, "closed today" announcement,
-- arrived status, owner password change and forgot-password requests routed
-- to the agent who registered the shop (no e-mail involved).

alter table public.nfc_businesses
  add column if not exists card_background text,
  add column if not exists closed_until date,
  add column if not exists closed_message text,
  add column if not exists reset_requested_at timestamptz;
alter table public.nfc_businesses drop constraint if exists nfc_businesses_owner_tools_check;
alter table public.nfc_businesses add constraint nfc_businesses_owner_tools_check check (
  (card_background is null or card_background ~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$')
  and (closed_message is null or length(closed_message) <= 300));

alter table public.nfc_customers add column if not exists arrived_at timestamptz;

create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'industry', b.industry, 'hours', b.hours, 'banners', b.banners,
    'latitude', b.latitude, 'longitude', b.longitude, 'radius_m', b.geofence_radius_m,
    'card_background', b.card_background,
    'closed', b.closed_until is not null and b.closed_until >= current_date,
    'closed_until', case when b.closed_until >= current_date then b.closed_until end,
    'closed_message', case when b.closed_until >= current_date then b.closed_message end);
$$;

create or replace function nfc_private.customer_json(c public.nfc_customers, goal int)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'phone', c.phone, 'stamps', c.stamps,
    'goal', coalesce(c.goal, goal), 'reward', c.reward,
    'next_free', c.stamps >= coalesce(c.goal, goal),
    'old_rule', c.goal is not null and c.goal <> goal,
    'total_visits', c.total_visits, 'rewards', c.rewards,
    'last_visit_at', c.last_visit_at, 'coming_at', c.coming_at, 'arrived_at', c.arrived_at,
    'coming', c.coming_at is not null and c.coming_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.coming_at),
    'arrived', c.arrived_at is not null and c.arrived_at > now() - interval '3 hours'
               and (c.last_visit_at is null or c.last_visit_at < c.arrived_at),
    'created_at', c.created_at);
$$;

-- "I've arrived / my turn" from the customer's card.
create or replace function public.nfc_customer_arrived(target_slug text, token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false); end if;
  update public.nfc_customers set arrived_at = now(), coming_at = coalesce(coming_at, now())
   where business_id = b.id and token_hash = nfc_private.sha(token)
     and (arrived_at is null or arrived_at < now() - interval '2 minutes')
   returning * into c;
  if c.id is null then
    select * into c from public.nfc_customers
     where business_id = b.id and token_hash = nfc_private.sha(token);
  end if;
  if c.id is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end; $$;

-- Owner marks the queue entry as handled (clears coming / arrived).
create or replace function public.nfc_shop_clear_queue(target_slug text, session text, customer uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null or b.suspended then return jsonb_build_object('ok', false); end if;
  update public.nfc_customers set coming_at = null, arrived_at = null
   where id = customer and business_id = b.id;
  return jsonb_build_object('ok', true);
end; $$;

-- "Closed today / until …" announcement shown on every customer's card.
create or replace function public.nfc_shop_set_closed(target_slug text, session text,
                                                     until_date date, message text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null or b.suspended then return jsonb_build_object('ok', false); end if;
  if until_date is not null and (until_date < current_date or until_date > current_date + 60) then
    return jsonb_build_object('ok', false, 'error', 'date');
  end if;
  update public.nfc_businesses
     set closed_until = until_date,
         closed_message = case when until_date is null then null
                               else nullif(left(trim(coalesce(message, '')), 300), '') end
   where id = b.id;
  return jsonb_build_object('ok', true);
end; $$;

create or replace function public.nfc_shop_change_password(target_slug text, session text,
                                                          old_password text, new_password text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; s nfc_private.shop_secrets;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  select * into s from nfc_private.shop_secrets where business_id = b.id for update;
  if s.owner_pass_hash is null or old_password is null
     or s.owner_pass_hash <> extensions.crypt(old_password, s.owner_pass_hash) then
    return jsonb_build_object('ok', false, 'error', 'old');
  end if;
  if new_password is null or length(new_password) not between 6 and 72 then
    return jsonb_build_object('ok', false, 'error', 'weak');
  end if;
  update nfc_private.shop_secrets
     set owner_pass_hash = extensions.crypt(new_password, extensions.gen_salt('bf', 8)),
         failed_attempts = 0, locked_until = null
   where business_id = b.id;
  -- Other devices are signed out; this one keeps its session.
  delete from nfc_private.shop_sessions
   where business_id = b.id and token_hash <> nfc_private.sha(session);
  insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
  values (null, 'owner_password_changed', 'shop', b.id, b.name);
  return jsonb_build_object('ok', true);
end; $$;

-- "Request a new password": the request reaches the responsible agent
-- (network feed and a flag on the shop). The answer is always the same.
create or replace function public.nfc_shop_forgot(target_slug text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_by_slug_owner(target_slug);
  if b.id is not null and (b.reset_requested_at is null or b.reset_requested_at < now() - interval '10 minutes') then
    update public.nfc_businesses set reset_requested_at = now() where id = b.id;
    insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
    values (b.created_by, 'owner_reset_requested', 'shop', b.id, b.name);
  end if;
  return jsonb_build_object('ok', true);
end; $$;

-- Dashboard: adds owner e-mail, closed state and card background.
create or replace function public.nfc_shop_dashboard(target_slug text, session text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true,
    'suspended', b.suspended,
    'notice', b.notice, 'notice_at', b.notice_at,
    'paid_until', b.paid_until, 'status', nfc_private.pay_status(b.paid_until),
    'shop', nfc_private.shop_public_json(b) || jsonb_build_object('min_hours', b.loyalty_min_hours),
    'customers', case when b.suspended then '[]'::jsonb else coalesce((
      select jsonb_agg(nfc_private.customer_json(c, b.loyalty_goal)
        order by (c.arrived_at is not null and c.arrived_at > now() - interval '3 hours'
                  and (c.last_visit_at is null or c.last_visit_at < c.arrived_at)) desc,
                 (c.coming_at is not null and c.coming_at > now() - interval '3 hours'
                  and (c.last_visit_at is null or c.last_visit_at < c.coming_at)) desc,
                 c.last_visit_at desc nulls last, c.created_at desc)
      from public.nfc_customers c where c.business_id = b.id), '[]'::jsonb) end,
    'visits', case when b.suspended then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('id', v.id, 'customer', c.name,
        'free', v.free, 'voided', v.voided, 'created_at', v.created_at)
        order by v.created_at desc)
      from (select * from public.nfc_visits where business_id = b.id
            order by created_at desc limit 50) v
      join public.nfc_customers c on c.id = v.customer_id), '[]'::jsonb) end,
    'stats', jsonb_build_object(
      'customers', (select count(*) from public.nfc_customers where business_id = b.id),
      'visits_today', (select count(*) from public.nfc_visits
                        where business_id = b.id and not voided
                          and created_at > date_trunc('day', now())),
      'visits_week', (select count(*) from public.nfc_visits
                       where business_id = b.id and not voided
                         and created_at > now() - interval '7 days'),
      'rewards', (select count(*) from public.nfc_visits
                   where business_id = b.id and free and not voided)));
end; $$;

-- Owner settings also accept the card background.
create or replace function public.nfc_shop_update(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; new_banners jsonb; item jsonb; bg text;
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
  bg := case when settings ? 'card_background' then nullif(settings ->> 'card_background', '') else b.card_background end;
  update public.nfc_businesses set
    name = coalesce(nullif(trim(settings ->> 'name'), ''), name),
    phone = case when settings ? 'phone' then nullif(trim(settings ->> 'phone'), '') else phone end,
    address = case when settings ? 'address' then nullif(trim(settings ->> 'address'), '') else address end,
    hours = case when settings ? 'hours' then nullif(trim(settings ->> 'hours'), '') else hours end,
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

-- Agents see reset requests on their shops.
drop function if exists public.nfc_network_shops();
create or replace function public.nfc_network_shops()
returns table(id uuid, tenant_id uuid, name text, shop_slug text, loyalty_enabled boolean,
              suspended boolean, paid_until date, status text, notice text,
              goal int, reward text, phone text, address text, hours text, industry text,
              latitude double precision, longitude double precision, radius_m int,
              reset_requested boolean,
              created_by uuid, creator text, customers bigint, visits bigint, visits_7d bigint,
              has_password boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.id, b.tenant_id, b.name, b.shop_slug, b.loyalty_enabled, b.suspended, b.paid_until,
         nfc_private.pay_status(b.paid_until), b.notice,
         b.loyalty_goal, b.loyalty_reward, b.phone, b.address, b.hours, b.industry,
         b.latitude, b.longitude, b.geofence_radius_m,
         b.reset_requested_at is not null and b.reset_requested_at > now() - interval '7 days',
         b.created_by,
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

-- A new password set by the agent clears the reset request.
create or replace function nfc_private.clear_reset_request()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.owner_pass_hash is distinct from old.owner_pass_hash then
    update public.nfc_businesses set reset_requested_at = null where id = new.business_id;
  end if;
  return null;
end; $$;
drop trigger if exists nfc_shop_secret_reset on nfc_private.shop_secrets;
create trigger nfc_shop_secret_reset after update of owner_pass_hash on nfc_private.shop_secrets
  for each row execute function nfc_private.clear_reset_request();

revoke all on function
  public.nfc_customer_arrived(text, text), public.nfc_shop_clear_queue(text, text, uuid),
  public.nfc_shop_set_closed(text, text, date, text),
  public.nfc_shop_change_password(text, text, text, text),
  public.nfc_shop_forgot(text), public.nfc_network_shops()
from public;
grant execute on function
  public.nfc_customer_arrived(text, text), public.nfc_shop_clear_queue(text, text, uuid),
  public.nfc_shop_set_closed(text, text, date, text),
  public.nfc_shop_change_password(text, text, text, text),
  public.nfc_shop_forgot(text)
to anon, authenticated;
grant execute on function public.nfc_network_shops() to authenticated;
