-- Owner dashboard protection: after 3 wrong passwords the shop owner is locked
-- out until the agent who created the shop sets a new password (nfc_shop_setup
-- clears the lock). The lock also files a "new password requested" event.
do $$
declare def text; patched text;
begin
  def := pg_get_functiondef('public.nfc_shop_login(text,text)'::regprocedure);
  patched := replace(def,
$old$    update nfc_private.shop_secrets
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end
     where business_id = b.id;
    return jsonb_build_object('ok', false, 'error', 'invalid');$old$,
$new$    update nfc_private.shop_secrets
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 3 then 'infinity'::timestamptz end
     where business_id = b.id
     returning * into s;
    if s.locked_until is not null then
      update public.nfc_businesses set reset_requested_at = now() where id = b.id;
      insert into public.nfc_network_events(actor_id, action, subject_type, subject_id, subject_name)
      values (b.created_by, 'owner_locked', 'shop', b.id, b.name);
      return jsonb_build_object('ok', false, 'error', 'locked');
    end if;
    return jsonb_build_object('ok', false, 'error', 'invalid', 'left', 3 - s.failed_attempts);$new$);
  if patched = def then
    if position('>= 3' in def) > 0 then return; end if;
    raise exception 'could not patch nfc_shop_login';
  end if;
  execute patched;
end $$;
