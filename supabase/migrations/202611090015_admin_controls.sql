-- Admin controls over the network.
--   * Per-agent permissions set by the super admin: may add people under him
--     (can_add_members) and may manage them: passwords, suspend, delete
--     (can_manage_members).
--   * Delete one shop (with its customers, visits, bookings and cards), one
--     card, or every card an account created.
--   * Purge an account with everything it created (shops, cards, workspaces)
--     and optionally everyone under it; the edge function then deletes the
--     login(s). The super admin can never be purged.

alter table public.nfc_staff
  add column if not exists can_add_members boolean not null default true,
  add column if not exists can_manage_members boolean not null default true;

create or replace function public.nfc_can_create_staff(new_role text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when nfc_private.is_super_admin(auth.uid()) then new_role in ('agent', 'worker')
    else new_role = 'worker' and exists (
      select 1 from public.nfc_staff s
      where s.user_id = auth.uid() and s.role = 'agent' and s.active and s.can_add_members)
  end;
$$;

-- Managing someone below you needs the "manage" permission (super admin: always).
create or replace function nfc_private.manages(target uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.is_super_admin(auth.uid())
      or (target is distinct from auth.uid()
          and nfc_private.in_subtree(auth.uid(), target)
          and coalesce((select s.can_manage_members and s.active from public.nfc_staff s
                         where s.user_id = auth.uid()), false));
$$;

create or replace function public.nfc_admin_set_staff_perms(target uuid, can_add boolean, can_manage boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not nfc_private.is_super_admin(auth.uid()) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  update public.nfc_staff
     set can_add_members = coalesce(can_add, can_add_members),
         can_manage_members = coalesce(can_manage, can_manage_members)
   where user_id = target;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  return jsonb_build_object('ok', true);
end $$;

-- Who may delete things created by `owner`: the super admin, the creator, or
-- someone above the creator with the manage permission.
create or replace function nfc_private.may_delete_for(owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
     and (nfc_private.is_super_admin(auth.uid()) or owner = auth.uid() or nfc_private.manages(owner));
$$;

create or replace function public.nfc_admin_delete_shop(target uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target;
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not nfc_private.may_delete_for(b.created_by) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  -- Cards (/p/...) that pointed to this shop page go too.
  delete from public.nfc_profiles
   where kind = 'loyalty' and b.shop_slug is not null
     and data ->> 'loyalty_url' ~ ('/c/' || b.shop_slug || '/?$');
  delete from public.nfc_businesses where id = b.id;
  insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
  values (auth.uid(), 'shop_deleted', 'shop', null, b.name);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.nfc_admin_delete_profile(target uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles;
begin
  select * into p from public.nfc_profiles where id = target;
  if p.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not (nfc_private.may_delete_for(p.created_by) or nfc_private.has_role(p.tenant_id, array['owner', 'admin'])) then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  delete from public.nfc_profiles where id = p.id;
  return jsonb_build_object('ok', true);
end $$;

-- Every card an account created (not its shops).
create or replace function public.nfc_admin_delete_profiles_of(owner uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  if not nfc_private.may_delete_for(owner) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  delete from public.nfc_profiles where created_by = owner;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'deleted', n);
end $$;

-- Removes everything the account(s) created and returns the user ids whose
-- logins the edge function must delete. with_children: the whole subtree;
-- otherwise people under the account move up to its parent.
create or replace function public.nfc_admin_purge_user(target uuid, with_children boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare ids uuid[]; parent uuid;
begin
  if auth.uid() is null or target = auth.uid() then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if nfc_private.is_super_admin(target) then return jsonb_build_object('ok', false, 'error', 'super'); end if;
  if not nfc_private.manages(target) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if with_children then
    with recursive tree(id) as (
      select target
      union
      select s.user_id from public.nfc_staff s join tree on s.parent_id = tree.id
    ) select array_agg(id) into ids from tree;
  else
    ids := array[target];
    select s.parent_id into parent from public.nfc_staff s where s.user_id = target;
    update public.nfc_staff set parent_id = parent where parent_id = target;
  end if;
  if exists (select 1 from unnest(ids) i where nfc_private.is_super_admin(i)) then
    return jsonb_build_object('ok', false, 'error', 'super');
  end if;

  delete from public.nfc_businesses where created_by = any(ids);          -- shops + customers, visits, bookings, cards
  delete from public.nfc_profiles where created_by = any(ids);
  delete from public.nfc_tenants where owner_id = any(ids);               -- their workspaces with everything inside
  update public.nfc_activity set actor_id = null where actor_id = any(ids);
  update public.nfc_network_events set actor_id = null where actor_id = any(ids);
  update public.nfc_payments set paid_by = null where paid_by = any(ids);
  update public.nfc_profiles set updated_by = null where updated_by = any(ids);
  update public.nfc_workers set created_by = null where created_by = any(ids);
  update public.nfc_staff set parent_id = null where parent_id = any(ids) and not (user_id = any(ids));
  insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
  values (auth.uid(), 'staff_purged', 'staff', null,
          coalesce((select display_name from public.nfc_staff where user_id = target), ''));
  return jsonb_build_object('ok', true, 'users', to_jsonb(ids));
end $$;

-- Account detail for the super admin now also lists its shops and people.
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
    'shops', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'name', b.name, 'slug', b.shop_slug, 'industry', b.industry,
        'suspended', b.suspended, 'created_at', b.created_at,
        'customers', (select count(*) from public.nfc_customers c where c.business_id = b.id))
        order by b.created_at desc)
      from public.nfc_businesses b
      where b.created_by = target_id and b.shop_slug is not null), '[]'::jsonb),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', s.user_id, 'name', s.display_name, 'email', s.email,
        'role', s.role, 'active', s.active) order by s.created_at)
      from public.nfc_staff s where s.parent_id = target_id), '[]'::jsonb),
    'staff', (select jsonb_build_object('role', s.role, 'active', s.active,
        'can_add_members', s.can_add_members, 'can_manage_members', s.can_manage_members,
        'parent', (select p.email from public.nfc_staff p where p.user_id = s.parent_id))
      from public.nfc_staff s where s.user_id = target_id),
    'activity', coalesce((
      select jsonb_agg(x order by (x->>'created_at') desc) from (
        select jsonb_build_object('action', a.action, 'subject', a.subject,
          'details', a.details, 'created_at', a.created_at, 'workspace', t.name) x
        from public.nfc_activity a
        join public.nfc_tenants t on t.id = a.tenant_id
        where a.actor_id = target_id
        order by a.created_at desc limit 300) q), '[]'::jsonb),
    'workspaces', coalesce((
      select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'role', m.role))
      from public.nfc_memberships m join public.nfc_tenants t on t.id = m.tenant_id
      where m.user_id = target_id), '[]'::jsonb));
end $$;

revoke all on function public.nfc_admin_set_staff_perms(uuid, boolean, boolean) from public, anon;
revoke all on function public.nfc_admin_delete_shop(uuid) from public, anon;
revoke all on function public.nfc_admin_delete_profile(uuid) from public, anon;
revoke all on function public.nfc_admin_delete_profiles_of(uuid) from public, anon;
revoke all on function public.nfc_admin_purge_user(uuid, boolean) from public, anon;
grant execute on function public.nfc_admin_set_staff_perms(uuid, boolean, boolean) to authenticated;
grant execute on function public.nfc_admin_delete_shop(uuid) to authenticated;
grant execute on function public.nfc_admin_delete_profile(uuid) to authenticated;
grant execute on function public.nfc_admin_delete_profiles_of(uuid) to authenticated;
grant execute on function public.nfc_admin_purge_user(uuid, boolean) to authenticated;
