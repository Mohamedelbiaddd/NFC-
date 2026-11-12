-- Admin view of people who signed up on the website (tapmaroc.com/start):
-- list, activity log (card edits, scans, sign-ins) and actions (block,
-- hide card, new password, delete). Super admin only; staff accounts are
-- never touched by these functions.

create or replace function nfc_private.is_site_user(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select uid is not null
     and not nfc_private.is_super_admin(uid)
     and not exists (select 1 from public.nfc_staff s where s.user_id = uid)
     and not exists (select 1 from public.nfc_tenants t where t.owner_id = uid)
     and not exists (select 1 from public.nfc_memberships m where m.user_id = uid);
$$;

create or replace function public.nfc_site_users(term text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.created_at desc) from (
      select u.id, u.email, u.created_at, u.email_confirmed_at as confirmed_at, u.last_sign_in_at,
             (u.banned_until is not null and u.banned_until > now()) as banned,
             p.custom_slug as slug, p.title, p.published, p.updated_at as card_updated_at,
             (select count(*) from public.nfc_activity a where a.subject_id = p.id and a.action in ('owner_edited', 'profile_updated')) as edits,
             (select count(*) from public.nfc_scans sc where sc.profile_id = p.id) as scans
      from auth.users u
      left join public.nfc_profiles p on p.self_owner = u.id
      where nfc_private.is_site_user(u.id)
        and (term is null or term = '' or u.email ilike '%' || term || '%' or p.title ilike '%' || term || '%')
      limit 500
    ) x), '[]'::jsonb);
end; $$;

create or replace function public.nfc_site_user_log(target uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare pid uuid;
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  if not nfc_private.is_site_user(target) then raise exception 'Not a site user'; end if;
  select id into pid from public.nfc_profiles where self_owner = target;
  return coalesce((select jsonb_agg(e order by e->>'at' desc) from (
    select jsonb_build_object('at', a.created_at, 'kind', a.action, 'detail', coalesce(a.subject, '')) e
      from public.nfc_activity a where pid is not null and a.subject_id = pid
    union all
    select jsonb_build_object('at', l.created_at, 'kind', 'auth_' || coalesce(l.payload->>'action', ''), 'detail', coalesce(l.ip_address, ''))
      from auth.audit_log_entries l where l.payload->>'actor_id' = target::text
    union all
    select jsonb_build_object('at', max(s.created_at), 'kind', 'scans', 'detail', count(*)::text || ' · ' || s.source)
      from public.nfc_scans s where pid is not null and s.profile_id = pid group by s.source
    order by 1 desc limit 200
  ) q), '[]'::jsonb);
end; $$;

create or replace function public.nfc_site_user_action(target uuid, what text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare pw text;
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  if not nfc_private.is_site_user(target) then raise exception 'Not a site user'; end if;
  if what = 'block' then
    update auth.users set banned_until = '2999-01-01'::timestamptz where id = target;
    delete from auth.sessions where user_id = target;
    update public.nfc_profiles set published = false where self_owner = target;
  elsif what = 'unblock' then
    update auth.users set banned_until = null where id = target;
    update public.nfc_profiles set published = true where self_owner = target;
  elsif what = 'hide_card' then
    update public.nfc_profiles set published = false where self_owner = target;
  elsif what = 'show_card' then
    update public.nfc_profiles set published = true where self_owner = target;
  elsif what = 'reset_password' then
    pw := substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
    update auth.users set encrypted_password = extensions.crypt(pw, extensions.gen_salt('bf')), updated_at = now() where id = target;
    delete from auth.sessions where user_id = target;
    return jsonb_build_object('ok', true, 'password', pw);
  elsif what = 'delete' then
    delete from public.nfc_profiles where self_owner = target;
    delete from auth.users where id = target;
  else
    raise exception 'Unknown action';
  end if;
  return jsonb_build_object('ok', true);
end; $$;

revoke all on function public.nfc_site_users(text) from public, anon;
revoke all on function public.nfc_site_user_log(uuid) from public, anon;
revoke all on function public.nfc_site_user_action(uuid, text) from public, anon;
grant execute on function public.nfc_site_users(text) to authenticated;
grant execute on function public.nfc_site_user_log(uuid) to authenticated;
grant execute on function public.nfc_site_user_action(uuid, text) to authenticated;
