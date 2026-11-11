-- Payments can be recorded for any period from 1 month up to 3 years
-- (the app offers 1 / 3 / 6 months, 1 year, or a custom number of months).
do $$ declare d text; begin
  d := pg_get_functiondef('public.nfc_mark_paid'::regproc);
  if position('months not between 1 and 12' in d) > 0 then
    execute replace(d, 'months not between 1 and 12', 'months not between 1 and 36');
  end if;
end $$;
