-- Points shops need bigger goals (e.g. 100 points); visit shops stay at 50.
-- The page allows 6 promo photos: the old rule stopped at 5.
alter table public.nfc_businesses drop constraint if exists nfc_businesses_shop_rules;
alter table public.nfc_businesses add constraint nfc_businesses_shop_rules check (
  (shop_slug is null or (length(shop_slug) between 3 and 63 and shop_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'))
  and loyalty_goal >= 1
  and loyalty_goal <= case when loyalty_mode = 'points' then 10000 else 50 end
  and loyalty_min_hours between 0 and 72
  and length(loyalty_reward) between 1 and 120
  and (phone is null or length(phone) <= 40)
  and (address is null or length(address) <= 200)
  and jsonb_typeof(banners) = 'array' and jsonb_array_length(banners) <= 6);

-- Back to visits mode: a points-sized goal falls back to 5 visits.
do $$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_shop_sector_settings(text,text,jsonb)'::regprocedure);
  d := replace(d, 'set loyalty_mode = m, points_per = per,', 'set loyalty_mode = m, points_per = per, loyalty_goal = case when m = ''visits'' and loyalty_goal > 50 then 5 else loyalty_goal end,');
  if d not like '%loyalty_goal > 50%' then raise exception 'patch'; end if;
  execute d;
end $$;

-- The owner's dashboard shows the amount waiting for a scan (cleared by it).
do $$
declare d text;
begin
  d := pg_get_functiondef('public.nfc_shop_dashboard(text,text)'::regprocedure);
  d := replace(d, 'jsonb_build_object(''min_hours'', b.loyalty_min_hours)', 'jsonb_build_object(''min_hours'', b.loyalty_min_hours, ''pending'', case when b.pending_until > now() then jsonb_build_object(''points'', b.pending_points, ''amount'', b.pending_amount, ''until'', b.pending_until) end)');
  if d not like '%''pending''%' then raise exception 'patch'; end if;
  execute d;
end $$;
