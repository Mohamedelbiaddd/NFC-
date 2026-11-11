-- Ready-made card designs (web_profiles/card-themes.json) have ids like
-- "ivory-director": allow lowercase words joined by "-" for data.theme.
do $$
declare d text;
begin
  d := pg_get_functiondef('nfc_private.valid_payload'::regproc);
  d := replace(d, $q$if key in ('theme', 'layout') and v !~ '^[a-z]{2,12}$'$q$,
                  $q$if key in ('theme', 'layout') and v !~ '^[a-z][a-z-]{1,23}$'$q$);
  if d not like '%[a-z-]{1,23}%' then raise exception 'valid_payload patch failed'; end if;
  execute d;
end $$;
