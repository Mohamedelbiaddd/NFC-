-- "Your turn" fixes:
--   * "I'm coming" right after being called always counts (the 2-minute
--     anti-spam pause only applies when the shop has not called since).
--   * "Done" in the owner's list also clears the call.
create or replace function public.nfc_customer_coming(target_slug text, token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_by_slug(target_slug);
  if b.id is null or token is null then return jsonb_build_object('ok', false); end if;
  update public.nfc_customers set coming_at = now()
   where business_id = b.id and token_hash = nfc_private.sha(token)
     and (coming_at is null or coming_at < now() - interval '2 minutes'
          or (called_at is not null and coming_at < called_at))
   returning * into c;
  if c.id is null then
    select * into c from public.nfc_customers
     where business_id = b.id and token_hash = nfc_private.sha(token);
  end if;
  if c.id is null then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end $$;

create or replace function public.nfc_shop_clear_queue(target_slug text, session text, customer uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null or b.suspended then return jsonb_build_object('ok', false); end if;
  update public.nfc_customers set coming_at = null, arrived_at = null, called_at = null
   where id = customer and business_id = b.id;
  return jsonb_build_object('ok', true);
end $$;
