-- Switching a shop to the snack / pizzeria sector also switches it to points.
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
  -- A pizzeria / snack counts points by amount (new shop, or sector changed).
  if new.industry = 'snack' and new.loyalty_mode = 'visits'
     and (tg_op = 'INSERT' or new.industry is distinct from old.industry) then
    new.loyalty_mode := 'points';
    if new.loyalty_goal <= 10 then new.loyalty_goal := 50; end if;
  end if;
  return new;
end $$;
