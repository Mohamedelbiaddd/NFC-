-- Sector templates: picking the sector gives the shop its look automatically.
--   barber -> navy, cafe/bakery -> coffee, carwash -> aqua, snack -> pizza,
--   gym -> neon, beauty -> rose. The owner can still pick another theme.
alter table public.nfc_businesses drop constraint if exists nfc_businesses_industry_check;
alter table public.nfc_businesses add constraint nfc_businesses_industry_check
  check (industry in ('barber','beauty','carwash','bakery','cafe','snack','gym','other')
         and (hours is null or length(hours) <= 300));

alter table public.nfc_businesses drop constraint if exists nfc_businesses_theme_check;
alter table public.nfc_businesses add constraint nfc_businesses_theme_check
  check (theme in ('navy','black','emerald','royal','rose','ocean','sunset','crimson','ivory','mint',
                   'coffee','aqua','pizza','neon'));

create or replace function nfc_private.sector_theme(sector text)
returns text language sql immutable set search_path = '' as $$
  select case sector
    when 'cafe' then 'coffee' when 'bakery' then 'coffee' when 'carwash' then 'aqua'
    when 'snack' then 'pizza' when 'gym' then 'neon' when 'beauty' then 'rose'
    else 'navy' end;
$$;

-- New shop: the sector's theme. Sector changed and the theme was still the
-- old sector's default (not chosen by hand): follow the new sector.
create or replace function nfc_private.apply_sector_theme()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.theme is null or new.theme = 'navy' then
      new.theme := nfc_private.sector_theme(new.industry);
    end if;
  elsif new.industry is distinct from old.industry
        and new.theme = old.theme
        and old.theme = nfc_private.sector_theme(old.industry) then
    new.theme := nfc_private.sector_theme(new.industry);
  end if;
  return new;
end $$;

drop trigger if exists nfc_businesses_sector_theme on public.nfc_businesses;
create trigger nfc_businesses_sector_theme
  before insert or update of industry on public.nfc_businesses
  for each row execute function nfc_private.apply_sector_theme();

do $$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_shop_update(text,text,jsonb)'::regprocedure);
  d := replace(d, '''ivory'', ''mint'')', '''ivory'', ''mint'', ''coffee'', ''aqua'', ''pizza'', ''neon'')');
  if d not like '%''neon''%' then raise exception 'patch failed'; end if;
  execute d;
end $$;
