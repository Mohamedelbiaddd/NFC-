-- Business cards (vcard) like a modern digital profile: job title, company,
-- social links, address / map, a quote, a cover picture, a colour theme,
-- an optional own colour and a layout (shape) chosen by the card owner.
-- The public profile also returns the business logo, cover and theme.
create or replace function nfc_private.valid_payload(k text, d jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare key text; val jsonb; allowed text[]; required_key text; v text;
begin
  if jsonb_typeof(d) <> 'object' or octet_length(d::text) > 16000 then return false; end if;
  allowed := array['description'];
  case k
    when 'vcard' then
      allowed := allowed || array['full_name', 'phone', 'email', 'website', 'job_title', 'company', 'quote',
        'address', 'maps_url', 'cover_url', 'theme', 'layout', 'color', 'whatsapp', 'instagram', 'facebook', 'tiktok',
        'linkedin', 'x', 'youtube', 'snapchat', 'telegram'];
      required_key := 'full_name';
    when 'menu' then allowed := allowed || array['menu_url']; required_key := 'menu_url';
    when 'review' then allowed := allowed || array['review_url']; required_key := 'review_url';
    when 'equipment' then allowed := allowed || array['equipment_name', 'serial', 'manual_url']; required_key := 'equipment_name';
    when 'loyalty' then allowed := allowed || array['loyalty_url', 'terms']; required_key := 'loyalty_url';
    else return false;
  end case;
  for key, val in select * from jsonb_each(d) loop
    if not (key = any(allowed)) or jsonb_typeof(val) <> 'string' or length(d ->> key) > 2000 then return false; end if;
    v := d ->> key;
    if length(v) = 0 then continue; end if;
    if key in ('menu_url', 'review_url', 'manual_url', 'loyalty_url', 'website', 'maps_url', 'cover_url')
       and v !~ '^https://[^[:space:]]+$' then return false; end if;
    if key in ('theme', 'layout') and v !~ '^[a-z]{2,12}$' then return false; end if;
    if key = 'color' and v !~ '^#[0-9a-fA-F]{6}$' then return false; end if;
    if key = 'whatsapp' and v !~ '^[+0-9 ()-]{6,30}$' then return false; end if;
    -- Social accounts: a handle (@name) or an https link.
    if key in ('instagram', 'facebook', 'tiktok', 'linkedin', 'x', 'youtube', 'snapchat', 'telegram')
       and v !~ '^(https://[^[:space:]]{3,250}|@?[A-Za-z0-9_.-]{1,80})$' then return false; end if;
  end loop;
  return coalesce(length(trim(d ->> required_key)) > 0, false);
end $$;

create or replace function public.nfc_public_profile_by_slug(slug text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'custom_slug', p.custom_slug, 'title', p.title, 'kind', p.kind,
    'image_url', p.image_url, 'data', p.data, 'catalog', p.catalog,
    'updated_at', p.updated_at,
    'editable', exists (select 1 from nfc_private.profile_pins pin where pin.profile_id = p.id),
    'business', jsonb_build_object(
      'name', b.name, 'primary_color', b.primary_color,
      'accent_color', b.accent_color, 'logo_url', b.logo_url,
      'cover_url', b.cover_url, 'theme', b.theme))
  from public.nfc_profiles p
  join public.nfc_businesses b
    on b.id = p.business_id and b.tenant_id = p.tenant_id
  where p.custom_slug = lower(trim(slug))
    and p.published = true
    and not b.suspended
    and length(coalesce(slug, '')) between 3 and 63;
$$;
