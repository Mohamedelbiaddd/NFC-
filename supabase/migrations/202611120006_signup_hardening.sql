-- Public sign-up is now open (free website cards), so a website account must
-- never gain app powers. Before this, every new account got its own workspace
-- (owner membership) and could create shops/cards straight through the API.
-- Now workspace roles only count for super admins and active staff (people
-- created by the admin or an agent), and nobody else can create a workspace.

create or replace function nfc_private.has_role(t uuid, roles text[] default array['owner','admin','editor','viewer'])
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.is_super_admin(auth.uid())
    or (exists (select 1 from public.nfc_memberships
                 where tenant_id = t and user_id = auth.uid() and role = any(roles))
        and exists (select 1 from public.nfc_staff s where s.user_id = auth.uid() and s.active));
$$;

create or replace function public.nfc_create_workspace(workspace_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare t uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not (nfc_private.is_super_admin(auth.uid())
          or exists (select 1 from public.nfc_staff s where s.user_id = auth.uid() and s.active)) then
    raise exception 'Not authorized';
  end if;
  insert into public.nfc_tenants(name, owner_id) values (trim(workspace_name), auth.uid()) returning id into t;
  insert into public.nfc_memberships values (t, auth.uid(), 'owner');
  return t;
end; $$;

-- New accounts no longer get a workspace automatically; staff get theirs
-- from the app on first sign-in (nfc_create_workspace above).
create or replace function nfc_private.provision_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  return new;
end; $$;
