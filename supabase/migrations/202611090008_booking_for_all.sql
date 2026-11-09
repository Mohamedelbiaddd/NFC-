-- Booking is on for every shop by default. A shop that has not listed any
-- services still takes appointments: one plain "موعد" (appointment) of the
-- shop's slot length.
create or replace function nfc_private.shop_services(b public.nfc_businesses)
returns jsonb language sql immutable set search_path = '' as $$
  select case when jsonb_array_length(coalesce(b.services, '[]'::jsonb)) > 0 then b.services
    else jsonb_build_array(jsonb_build_object('id', 'visit', 'name', 'موعد', 'minutes', coalesce(b.slot_minutes, 30))) end;
$$;

alter table public.nfc_businesses alter column booking_enabled set default true;
update public.nfc_businesses set booking_enabled = true where not booking_enabled;

do $$
declare f text; d text;
begin
  foreach f in array array['public.nfc_booking_slots(text,text,date)', 'public.nfc_booking_create(text,text,text,date,text)'] loop
    d := pg_get_functiondef(f::regprocedure);
    d := replace(d, 'jsonb_array_elements(b.services)', 'jsonb_array_elements(nfc_private.shop_services(b))');
    execute d;
  end loop;
  d := pg_get_functiondef('nfc_private.shop_public_json(public.nfc_businesses)'::regprocedure);
  d := replace(d, ' and jsonb_array_length(b.services) > 0', '');
  d := replace(d, '''services'', b.services,', '''services'', b.services, ''book_services'', nfc_private.shop_services(b),');
  execute d;
end $$;
