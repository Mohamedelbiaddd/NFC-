-- Twenty premium looks for the loyalty card page (web_profiles/themes.mjs).
create or replace function nfc_private.shop_themes() returns text[]
language sql immutable set search_path = '' as $$
  select array['navy','black','emerald','royal','rose','ocean','sunset','crimson','ivory','mint',
               'coffee','aqua','pizza','neon',
               'onyx','imperial','amber','espresso','velvet','midnight','drive','pulse','district','redline',
               'sahara','terra','atelier','candy','coral','street','jade','nordic','platinum','mono'];
$$;

alter table public.nfc_businesses drop constraint if exists nfc_businesses_theme_check;
alter table public.nfc_businesses add constraint nfc_businesses_theme_check
  check (theme = any (nfc_private.shop_themes()));

do $mig$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_shop_update(text,text,jsonb)'::regprocedure);
  d := replace(d, $q$if th not in ('navy', 'black', 'emerald', 'royal', 'rose', 'ocean', 'sunset', 'crimson', 'ivory', 'mint', 'coffee', 'aqua', 'pizza', 'neon') then$q$,
                  $q$if not (th = any (nfc_private.shop_themes())) then$q$);
  if position('nfc_private.shop_themes()' in d) = 0 then raise exception 'theme check not found'; end if;
  execute d;
end $mig$;
