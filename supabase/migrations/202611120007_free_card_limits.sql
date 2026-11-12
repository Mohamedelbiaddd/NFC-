-- Free website cards stay simple: 4 plain colour themes, no ready-made
-- (premium) designs, no cover picture, no catalogue. Enforced here, so it
-- cannot be bypassed from the browser. Paid cards are unchanged.
create or replace function nfc_private.free_themes() returns text[]
language sql immutable as $$ select array['', 'navy', 'black', 'ivory', 'sky'] $$;

create or replace function public.nfc_owner_login(target_slug text, pin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles;
begin
  begin
    p := nfc_private.owner_check(target_slug, pin);
  exception when sqlstate '28000' then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
  end;
  if p.id is null then return jsonb_build_object('ok', false, 'error', 'Invalid code'); end if;
  return jsonb_build_object('ok', true, 'profile', jsonb_build_object(
    'title', p.title, 'kind', p.kind, 'data', p.data, 'catalog', p.catalog,
    'image_url', p.image_url, 'custom_slug', p.custom_slug,
    'free', p.self_owner is not null, 'free_themes', to_jsonb(nfc_private.free_themes())));
end; $$;

create or replace function public.nfc_owner_update(target_slug text, pin text, new_title text, new_data jsonb, new_catalog jsonb, new_image_url text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.nfc_profiles;
begin
  begin
    p := nfc_private.owner_check(target_slug, pin);
  exception when sqlstate '28000' then
    return jsonb_build_object('ok', false, 'error', sqlerrm);
  end;
  if p.id is null then return jsonb_build_object('ok', false, 'error', 'Invalid code'); end if;
  if new_image_url is not null and new_image_url <> '' and
     new_image_url !~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$' then
    raise exception 'Invalid image';
  end if;
  if p.self_owner is not null then
    new_data := coalesce(new_data, p.data) - 'cover_url' - 'layout' - 'color';
    if not (coalesce(new_data ->> 'theme', '') = any(nfc_private.free_themes())) then
      new_data := new_data - 'theme';
    end if;
    new_catalog := '[]'::jsonb;
  end if;
  update public.nfc_profiles
     set title = left(trim(coalesce(nullif(trim(new_title), ''), p.title)), 120),
         data = coalesce(new_data, p.data),
         catalog = coalesce(new_catalog, p.catalog),
         image_url = case when new_image_url is null then p.image_url
                          when new_image_url = '' then null
                          else new_image_url end
   where id = p.id;
  insert into public.nfc_activity(tenant_id,actor_id,action,subject,subject_id)
  values (p.tenant_id, null, 'owner_edited', p.title, p.id);
  return jsonb_build_object('ok', true);
end; $$;
