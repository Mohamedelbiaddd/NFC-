-- The app's shop form picks the loyalty card design too.
do $mig$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_shop_edit(uuid,jsonb)'::regprocedure);
  d := replace(d, $q$    industry = coalesce(nullif(settings ->> 'industry', ''), industry),$q$,
                  $q$    industry = coalesce(nullif(settings ->> 'industry', ''), industry),
    theme = case when coalesce(settings ->> 'theme', '') = any (nfc_private.shop_themes()) then settings ->> 'theme' else theme end,$q$);
  if position('shop_themes()' in d) = 0 then raise exception 'edit not patched'; end if;
  execute d;
end $mig$;

-- Current design of a shop, for whoever may edit it.
create or replace function public.nfc_shop_theme(target uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  select * into b from public.nfc_businesses where id = target;
  if b.id is null or not (nfc_private.can_manage_shop(b)
     or nfc_private.has_role(b.tenant_id, array['owner','admin','editor'])) then
    return null;
  end if;
  return b.theme;
end $$;
revoke all on function public.nfc_shop_theme(uuid) from public, anon;
grant execute on function public.nfc_shop_theme(uuid) to authenticated;
