-- Opening hours with a lunch break: each day may have a second period
-- {"o": "09:00", "c": "13:00", "o2": "15:00", "c2": "21:00"}. Booking slots
-- are generated for both periods.
create or replace function nfc_private.valid_week_hours(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb; re text := '^([01][0-9]|2[0-3]):[0-5][0-9]$';
begin
  if value is null then return true; end if;
  if jsonb_typeof(value) <> 'array' or jsonb_array_length(value) <> 7 then return false; end if;
  for item in select * from jsonb_array_elements(value) loop
    if jsonb_typeof(item) = 'null' then continue; end if;
    if jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'o', '') !~ re or coalesce(item ->> 'c', '') !~ re then
      return false;
    end if;
    if (item ? 'o2' or item ? 'c2')
       and (coalesce(item ->> 'o2', '') !~ re or coalesce(item ->> 'c2', '') !~ re
            or (item ->> 'o2') <= (item ->> 'c')) then
      return false;
    end if;
  end loop;
  return true;
end; $$;

create or replace function nfc_private.free_slots(b public.nfc_businesses, service jsonb, day date)
returns text[] language plpgsql stable security definer set search_path = '' as $$
declare idx int; hours jsonb; open_ts timestamp; close_ts timestamp; p int;
        dur interval; step interval; t timestamp; s timestamptz; out text[] := '{}';
begin
  if b.week_hours is null or day < (now() at time zone b.timezone)::date
     or day > (now() at time zone b.timezone)::date + 30 then
    return out;
  end if;
  if b.closed_until is not null and day <= b.closed_until then return out; end if;
  idx := extract(isodow from day)::int - 1;
  hours := b.week_hours -> idx;
  if hours is null or jsonb_typeof(hours) <> 'object' then return out; end if;
  dur := make_interval(mins => (service ->> 'minutes')::int);
  step := make_interval(mins => b.slot_minutes);
  for p in 1..2 loop
    if p = 1 then
      open_ts := day + (hours ->> 'o')::time;
      close_ts := day + (hours ->> 'c')::time;
    elsif hours ? 'o2' then
      open_ts := day + (hours ->> 'o2')::time;
      close_ts := day + (hours ->> 'c2')::time;
    else
      exit;
    end if;
    if close_ts <= open_ts then close_ts := close_ts + interval '1 day'; end if;
    t := open_ts;
    while t + dur <= close_ts loop
      s := t at time zone b.timezone;
      if s > now() + interval '10 minutes'
         and (select count(*) from public.nfc_bookings k
               where k.business_id = b.id and k.status = 'booked'
                 and k.starts_at < s + dur and k.ends_at > s) < b.booking_capacity then
        out := out || to_char(t, 'HH24:MI');
      end if;
      t := t + step;
    end loop;
  end loop;
  return out;
end; $$;
