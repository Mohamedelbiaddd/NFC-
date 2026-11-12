-- Lean pictures: a shop keeps only its own photo (logo) and one background
-- (cover). The 6-photo slideshow and the separate card background go away,
-- and every picture that is no longer used is deleted from storage.

-- 1. Keep one picture for shops that only had a slideshow / card background.
update public.nfc_businesses set cover_url = coalesce(nullif(card_background, ''), banners ->> 0)
  where coalesce(cover_url, '') = ''
    and (coalesce(card_background, '') <> '' or jsonb_array_length(banners) > 0);
update public.nfc_businesses set banners = '[]'::jsonb, card_background = null
  where jsonb_array_length(banners) > 0 or card_background is not null;

-- 2. From now on these two stay empty, whatever a client sends.
create or replace function nfc_private.no_extra_pictures() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.banners := '[]'::jsonb;
  new.card_background := null;
  return new;
end; $$;
drop trigger if exists nfc_no_extra_pictures on public.nfc_businesses;
create trigger nfc_no_extra_pictures before insert or update on public.nfc_businesses
  for each row execute function nfc_private.no_extra_pictures();

-- 3. Storage garbage collector.
-- Key shared between the database and the storage-gc function.
create table if not exists nfc_private.gc_key (id int primary key default 1 check (id = 1), key text not null);
revoke all on nfc_private.gc_key from public, anon, authenticated;
insert into nfc_private.gc_key (key) values (replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')) on conflict do nothing;

create or replace function public.nfc_gc_key_ok(k text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from nfc_private.gc_key where key = k);
$$;
revoke all on function public.nfc_gc_key_ok(text) from public, anon, authenticated;
grant execute on function public.nfc_gc_key_ok(text) to service_role;

-- Picture paths mentioned in a piece of text (a row as json).
create or replace function nfc_private.image_paths(t text) returns text[]
language sql immutable set search_path = '' as $$
  select coalesce(array_agg(distinct m[1]), '{}')
  from regexp_matches(coalesce(t, ''), '/storage/v1/object/public/profile-images/([A-Za-z0-9._/-]+)', 'g') as m;
$$;

-- Files nobody uses: not referenced by any shop or card, and either just
-- dropped by an edit (force) or older than the grace period (uploads that
-- were never saved).
create or replace function public.nfc_storage_orphans(grace_minutes int default 120, force text[] default '{}')
returns text[] language sql stable security definer set search_path = '' as $$
  with used as (
    select unnest(nfc_private.image_paths(b::text)) p from public.nfc_businesses b
    union select unnest(nfc_private.image_paths(p::text)) from public.nfc_profiles p
  )
  select coalesce(array_agg(o.name), '{}') from storage.objects o
  where o.bucket_id = 'profile-images'
    and not exists (select 1 from used where used.p = o.name)
    and (o.created_at < now() - make_interval(mins => greatest(grace_minutes, 10)) or o.name = any(force));
$$;
revoke all on function public.nfc_storage_orphans(int, text[]) from public, anon, authenticated;
grant execute on function public.nfc_storage_orphans(int, text[]) to service_role;

create or replace function nfc_private.call_storage_gc(paths text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform net.http_post(
    url := 'https://ikcaingdfybpqrdzucyd.supabase.co/functions/v1/storage-gc',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-gc-key', (select key from nfc_private.gc_key where id = 1)),
    body := jsonb_build_object('paths', to_jsonb(coalesce(paths, '{}'))),
    timeout_milliseconds := 10000);
exception when others then null; -- cleanup must never block a save
end; $$;

-- Right after an edit or a delete, pictures that left the row are removed.
create or replace function nfc_private.drop_unused_pictures() returns trigger
language plpgsql security definer set search_path = '' as $$
declare gone text[];
begin
  select coalesce(array_agg(p), '{}') into gone
  from unnest(nfc_private.image_paths(to_jsonb(old)::text)) p
  where tg_op = 'DELETE' or not (p = any(nfc_private.image_paths(to_jsonb(new)::text)));
  if cardinality(gone) > 0 then perform nfc_private.call_storage_gc(gone); end if;
  return null;
end; $$;
drop trigger if exists nfc_drop_unused_pictures on public.nfc_businesses;
create trigger nfc_drop_unused_pictures after update or delete on public.nfc_businesses
  for each row execute function nfc_private.drop_unused_pictures();
drop trigger if exists nfc_drop_unused_pictures on public.nfc_profiles;
create trigger nfc_drop_unused_pictures after update or delete on public.nfc_profiles
  for each row execute function nfc_private.drop_unused_pictures();

-- Every hour: uploads that were never saved.
select cron.unschedule('nfc-storage-gc') where exists (select 1 from cron.job where jobname = 'nfc-storage-gc');
select cron.schedule('nfc-storage-gc', '17 * * * *', $$select nfc_private.call_storage_gc('{}')$$);
