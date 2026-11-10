-- "Your turn": the owner calls a customer (usually one with an appointment);
-- the customer's page and Google Wallet card say it is their turn and the
-- customer answers "I'm coming". A scan of the shop QR closes the cycle and
-- marks the appointment as done.

alter table public.nfc_customers add column if not exists called_at timestamptz;

create or replace function nfc_private.customer_json(c public.nfc_customers, goal integer)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'phone', c.phone, 'stamps', c.stamps,
    'goal', coalesce(c.goal, goal), 'reward', c.reward,
    'next_free', c.stamps >= coalesce(c.goal, goal),
    'old_rule', c.goal is not null and c.goal <> goal,
    'total_visits', c.total_visits, 'rewards', c.rewards,
    'last_visit_at', c.last_visit_at, 'coming_at', c.coming_at, 'arrived_at', c.arrived_at,
    'called_at', c.called_at,
    'called', c.called_at is not null and c.called_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.called_at),
    -- "Coming" now means: answered after being called (or on his own, recently).
    'coming', c.coming_at is not null and c.coming_at > now() - interval '3 hours'
              and (c.last_visit_at is null or c.last_visit_at < c.coming_at)
              and (c.called_at is null or c.coming_at >= c.called_at or c.called_at < now() - interval '3 hours'),
    'arrived', c.arrived_at is not null and c.arrived_at > now() - interval '3 hours'
               and (c.last_visit_at is null or c.last_visit_at < c.arrived_at),
    'booking', (select jsonb_build_object('id', k.id, 'starts_at', k.starts_at, 'service', k.service_name)
                  from public.nfc_bookings k
                 where k.customer_id = c.id and k.status = 'booked' and k.starts_at > now() - interval '2 hours'
                 order by k.starts_at limit 1),
    'vehicle_type', c.vehicle_type, 'dob', c.dob, 'expiry_date', c.expiry_date,
    'expired', c.expiry_date is not null and c.expiry_date < current_date,
    'birthday', nfc_private.is_birthday(c, null),
    'created_at', c.created_at);
$$;

-- Owner: "your turn" for one customer.
create or replace function public.nfc_shop_call_customer(target_slug text, session text, customer uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; c public.nfc_customers;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  update public.nfc_customers set called_at = now()
   where id = customer and business_id = b.id
   returning * into c;
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'customer'); end if;
  return jsonb_build_object('ok', true, 'customer', nfc_private.customer_json(c, b.loyalty_goal));
end $$;
revoke all on function public.nfc_shop_call_customer(text, text, uuid) from public;
grant execute on function public.nfc_shop_call_customer(text, text, uuid) to anon, authenticated;

-- A visit closes the appointment it belongs to (booked within -6h..+3h).
do $$
declare d text;
begin
  d := pg_get_functiondef('nfc_private.add_visit(public.nfc_businesses,public.nfc_customers)'::regprocedure);
  d := replace(d, '  insert into public.nfc_visits(tenant_id, business_id, customer_id, free)',
'  update public.nfc_bookings set status = ''done'', updated_at = now()
   where customer_id = c.id and status = ''booked''
     and starts_at between now() - interval ''6 hours'' and now() + interval ''3 hours'';
  insert into public.nfc_visits(tenant_id, business_id, customer_id, free)');
  if d not like '%status = ''done''%' then raise exception 'add_visit patch failed'; end if;
  execute d;

  d := pg_get_functiondef('public.nfc_shop_bookings(text,text)'::regprocedure);
  d := replace(d, 'jsonb_build_object(''customer'', c.name, ''phone'', c.phone)',
                  'jsonb_build_object(''customer'', c.name, ''phone'', c.phone, ''customer_id'', c.id, ''called'', c.called_at > now() - interval ''3 hours'' and (c.last_visit_at is null or c.last_visit_at < c.called_at), ''coming'', c.coming_at > now() - interval ''3 hours'' and c.called_at is not null and c.coming_at >= c.called_at)');
  if d not like '%customer_id%' then raise exception 'bookings patch failed'; end if;
  execute d;
end $$;
