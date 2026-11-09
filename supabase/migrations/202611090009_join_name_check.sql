-- A returning customer gets his own card back by typing the same name and
-- phone as the first time. The phone alone is not enough: if the name does
-- not match the one on file the card is not handed over.
create or replace function nfc_private.name_key(value text)
returns text language sql immutable set search_path = '' as $$
  select regexp_replace(
           translate(lower(trim(coalesce(value, ''))), 'أإآىةـ', 'اااىه'),
           '[\sً-ْ]+', '', 'g');
$$;

do $$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_customer_join(text,text,text,text)'::regprocedure);
  d := replace(d, '  token := nfc_private.random_token();',
'  select * into c from public.nfc_customers where business_id = b.id and phone = norm_phone;
  if c.id is not null and nfc_private.name_key(c.name) <> nfc_private.name_key(customer_name) then
    return jsonb_build_object(''ok'', false, ''error'', ''name_mismatch'');
  end if;
  token := nfc_private.random_token();');
  if d not like '%name_mismatch%' then raise exception 'patch failed'; end if;
  execute d;
end $$;
