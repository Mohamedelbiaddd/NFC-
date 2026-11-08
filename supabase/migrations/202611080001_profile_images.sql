-- Profile cover image support.
-- Apply after 202610290002_custom_slugs.sql.
-- 1) Adds nfc_profiles.image_url (public URL of the object in Storage).
-- 2) Returns image_url from both public RPCs so /p/<slug> can render it.

alter table public.nfc_profiles add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'nfc_profiles_image_url_https'
      and conrelid = 'public.nfc_profiles'::regclass
  ) then
    alter table public.nfc_profiles
      add constraint nfc_profiles_image_url_https
      check (
        image_url is null
        or (image_url ~ '^https://[^[:space:]]+$' and length(image_url) <= 2000)
      ) not valid;
  end if;
end $$;

alter table public.nfc_profiles validate constraint nfc_profiles_image_url_https;

-- Kept internal to the app (anonymised UUID lookup). The web front end uses the
-- slug variant below, but both payloads now carry the image.
create or replace function public.nfc_public_profile(profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'id',p.id,'title',p.title,'kind',p.kind,'image_url',p.image_url,
  'data',p.data,'updated_at',p.updated_at,
  'business',jsonb_build_object(
   'name',b.name,'primary_color',b.primary_color,'accent_color',b.accent_color))
 from public.nfc_profiles p
 join public.nfc_businesses b
   on b.id=p.business_id and b.tenant_id=p.tenant_id
 where p.id=profile_id and p.published=true;
$$;
revoke all on function public.nfc_public_profile(uuid) from public, anon, authenticated;

create or replace function public.nfc_public_profile_by_slug(slug text)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'custom_slug',p.custom_slug,'title',p.title,'kind',p.kind,
  'image_url',p.image_url,'data',p.data,'updated_at',p.updated_at,
  'business',jsonb_build_object(
   'name',b.name,'primary_color',b.primary_color,'accent_color',b.accent_color))
 from public.nfc_profiles p
 join public.nfc_businesses b
   on b.id=p.business_id and b.tenant_id=p.tenant_id
 where p.custom_slug=slug and p.published=true;
$$;
revoke all on function public.nfc_public_profile_by_slug(text) from public;
grant execute on function public.nfc_public_profile_by_slug(text) to anon,authenticated;
