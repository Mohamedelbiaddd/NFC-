-- Editable landing page (tapmaroc.com). One published document holds text
-- overrides per language plus a few settings (WhatsApp number). Anyone may
-- read it; only a super admin may change it, and every change is kept.
create table if not exists nfc_private.site_content (
  id int primary key default 1 check (id = 1),
  doc jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
create table if not exists nfc_private.site_content_history (
  id bigserial primary key,
  doc jsonb not null,
  saved_at timestamptz not null default now(),
  saved_by uuid
);
revoke all on nfc_private.site_content, nfc_private.site_content_history from public, anon, authenticated;
insert into nfc_private.site_content (id) values (1) on conflict do nothing;

create or replace function public.nfc_site_content()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select doc from nfc_private.site_content where id = 1), '{}'::jsonb);
$$;
revoke all on function public.nfc_site_content() from public;
grant execute on function public.nfc_site_content() to anon, authenticated;

create or replace function public.nfc_site_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select nfc_private.is_super_admin(auth.uid());
$$;
revoke all on function public.nfc_site_is_admin() from public, anon;
grant execute on function public.nfc_site_is_admin() to authenticated;

create or replace function public.nfc_site_save(new_doc jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare lang text; k text; v jsonb;
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  if jsonb_typeof(new_doc) <> 'object' or octet_length(new_doc::text) > 200000 then
    raise exception 'Invalid content';
  end if;
  for lang, v in select * from jsonb_each(new_doc) loop
    if lang not in ('ar', 'fr', 'en', 'settings') or jsonb_typeof(v) <> 'object' then
      raise exception 'Invalid section %', lang;
    end if;
    for k in select jsonb_object_keys(v) loop
      if k !~ '^[a-z0-9][a-z0-9._-]{0,40}$' or jsonb_typeof(v -> k) <> 'string'
         or length(v ->> k) > 2000 then
        raise exception 'Invalid key %', k;
      end if;
    end loop;
  end loop;
  if new_doc #>> '{settings,whatsapp}' is not null
     and new_doc #>> '{settings,whatsapp}' !~ '^[0-9]{8,15}$' then
    raise exception 'Invalid WhatsApp number';
  end if;
  insert into nfc_private.site_content_history (doc, saved_by)
    select doc, updated_by from nfc_private.site_content where id = 1;
  update nfc_private.site_content set doc = new_doc, updated_at = now(), updated_by = auth.uid() where id = 1;
  return new_doc;
end; $$;
revoke all on function public.nfc_site_save(jsonb) from public, anon;
grant execute on function public.nfc_site_save(jsonb) to authenticated;

-- Italian added later (2026-11-12): allow an 'it' section.
do $$ declare d text; begin
  d := pg_get_functiondef('public.nfc_site_save(jsonb)'::regprocedure);
  if position($q$('ar', 'fr', 'en', 'settings')$q$ in d) > 0 then
    execute replace(d, $q$('ar', 'fr', 'en', 'settings')$q$, $q$('ar', 'fr', 'en', 'it', 'settings')$q$);
  end if;
end $$;
