-- Delete a workspace (and its cards and businesses) from the app. Allowed for
-- the workspace owner or the super admin; refused while one of its loyalty
-- shops still has customers, so nobody's points disappear by mistake.
create or replace function public.nfc_delete_workspace(target uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t public.nfc_tenants;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  select * into t from public.nfc_tenants where id = target;
  if t.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not (nfc_private.is_super_admin() or nfc_private.has_role(t.id, array['owner'])) then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;
  if exists (select 1 from public.nfc_customers c where c.tenant_id = t.id) then
    return jsonb_build_object('ok', false, 'error', 'has_customers');
  end if;
  delete from public.nfc_tenants where id = t.id;
  return jsonb_build_object('ok', true);
end; $$;
revoke all on function public.nfc_delete_workspace(uuid) from public, anon;
grant execute on function public.nfc_delete_workspace(uuid) to authenticated;
