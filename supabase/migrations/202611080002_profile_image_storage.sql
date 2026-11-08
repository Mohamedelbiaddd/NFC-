-- Storage bucket for profile images.
-- Objects are written to <tenant_id>/<profile_id>/<timestamp>.<jpg|png|webp>.
-- The bucket is public (read via the public URL, exactly what the web page
-- needs) while writes stay limited to members of that tenant.
--
-- If a bucket with the same name already exists its configuration is kept as
-- is; only the policies are (re)created. Set SUPABASE_STORAGE_BUCKET at build
-- time when the bucket is named differently.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-images',
  'profile-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do nothing;

-- Folder-aware authorisation helper. The first path segment must be the tenant
-- id the caller belongs to with an editor-level role. A malformed folder name
-- (no castable uuid) simply denies the request instead of raising.
create or replace function nfc_private.can_manage_profile_image(
  bucket text,
  object_name text
) returns boolean language sql stable security definer set search_path='' as $$
 select bucket = 'profile-images'
   and nfc_private.has_role(
     case
       when (storage.foldername(object_name))[1]
         ~ '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
       then ((storage.foldername(object_name))[1])::uuid
     end,
     array['owner','admin','editor']);
$$;
revoke all on function nfc_private.can_manage_profile_image(text,text) from public;
grant execute on function nfc_private.can_manage_profile_image(text,text)
  to authenticated;

drop policy if exists profile_image_insert on storage.objects;
create policy profile_image_insert on storage.objects
  for insert to authenticated
  with check (nfc_private.can_manage_profile_image(bucket_id, name));

drop policy if exists profile_image_update on storage.objects;
create policy profile_image_update on storage.objects
  for update to authenticated
  using (nfc_private.can_manage_profile_image(bucket_id, name))
  with check (nfc_private.can_manage_profile_image(bucket_id, name));

drop policy if exists profile_image_delete on storage.objects;
create policy profile_image_delete on storage.objects
  for delete to authenticated
  using (nfc_private.can_manage_profile_image(bucket_id, name));
