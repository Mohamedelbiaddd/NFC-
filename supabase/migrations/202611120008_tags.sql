-- Programmable tags: the admin creates batches of blank codes in the app,
-- prints them as QR / writes them on NFC cards and sells them. Link:
-- tapmaroc.com/k/<CODE>. The first person to scan a blank code activates it
-- with their own password and chooses what it opens: a full business card,
-- Google review page, Instagram, WhatsApp, any link… Later they change it
-- with the code + password. One code per person (no account needed).

create table if not exists nfc_private.tags (
  code text primary key check (code ~ '^[A-Z0-9]{8}$'),
  batch text not null default '',
  status text not null default 'blank' check (status in ('blank', 'active', 'disabled')),
  kind text check (kind in ('card', 'link')),
  link_type text,
  target_url text check (target_url is null or (target_url ~ '^https://[^[:space:]]+$' and length(target_url) <= 1000)),
  profile_id uuid references public.nfc_profiles(id) on delete set null,
  pass_hash text,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  owner_name text,
  owner_contact text,
  scans int not null default 0,
  last_scan_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  activated_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists tags_batch on nfc_private.tags(batch);
revoke all on nfc_private.tags from public, anon, authenticated;

-- Unambiguous alphabet (no 0/O, 1/I/L).
create or replace function nfc_private.new_tag_code() returns text
language plpgsql volatile set search_path = '' as $$
declare a text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := '';
    for i in 1..8 loop c := c || substr(a, 1 + floor(random() * length(a))::int, 1); end loop;
    exit when not exists (select 1 from nfc_private.tags where code = c);
  end loop;
  return c;
end; $$;

create or replace function nfc_private.tag_url(kind text, link_type text, value text) returns text
language plpgsql immutable set search_path = '' as $$
declare v text := trim(coalesce(value, '')); u text;
begin
  if v = '' then return null; end if;
  if link_type = 'whatsapp' then
    u := 'https://wa.me/' || regexp_replace(v, '[^0-9]', '', 'g');
  elsif link_type in ('instagram', 'tiktok', 'facebook') and v !~* '^https?://' then
    v := regexp_replace(v, '^@', '');
    u := case link_type when 'instagram' then 'https://instagram.com/' || v
                        when 'tiktok' then 'https://www.tiktok.com/@' || v
                        else 'https://facebook.com/' || v end;
  else
    u := case when v ~* '^https://' then v when v ~* '^http://' then 'https://' || substr(v, 8) else 'https://' || v end;
  end if;
  if u !~ '^https://[^[:space:]<>"]+$' or length(u) > 1000 then raise exception 'Invalid link'; end if;
  return u;
end; $$;

-- Login check with lockout after 5 wrong passwords (15 minutes).
create or replace function nfc_private.tag_check(c text, pw text) returns nfc_private.tags
language plpgsql security definer set search_path = '' as $$
declare t nfc_private.tags;
begin
  select * into t from nfc_private.tags where code = upper(trim(c)) for update;
  if t.code is null or t.status <> 'active' then raise exception 'Invalid code' using errcode = '28000'; end if;
  if t.locked_until is not null and t.locked_until > now() then raise exception 'Too many attempts, try later' using errcode = '28000'; end if;
  if pw is null or t.pass_hash is null or t.pass_hash <> extensions.crypt(pw, t.pass_hash) then
    update nfc_private.tags set failed_attempts = failed_attempts + 1,
      locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end where code = t.code;
    raise exception 'Wrong password' using errcode = '28000';
  end if;
  update nfc_private.tags set failed_attempts = 0, locked_until = null where code = t.code;
  return t;
end; $$;

create or replace function nfc_private.tag_card_profile(t nfc_private.tags, full_name text, job text, phone text, pw text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare fs nfc_private.free_space; s text; pid uuid; n text := left(trim(coalesce(full_name, '')), 80);
begin
  if length(n) < 2 then raise exception 'Name required'; end if;
  select * into fs from nfc_private.free_space where id = 1;
  loop
    s := 'card-' || substr(md5(gen_random_uuid()::text), 1, 12);
    exit when not exists (select 1 from nfc_private.slug_reservations where slug = s);
  end loop;
  insert into public.nfc_profiles (tenant_id, business_id, kind, title, data, published, custom_slug)
  values (fs.tenant_id, fs.business_id, 'vcard', n,
    jsonb_strip_nulls(jsonb_build_object('full_name', n, 'job_title', left(trim(coalesce(job, '')), 80),
      'phone', left(regexp_replace(coalesce(phone, ''), '[^0-9+ ]', '', 'g'), 20),
      'whatsapp', case when length(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g')) >= 6
                       then regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') end)),
    true, s) returning id into pid;
  insert into nfc_private.profile_pins (profile_id, pin_hash, failed_attempts, locked_until, updated_at)
  values (pid, extensions.crypt(pw, extensions.gen_salt('bf')), 0, null, now())
  on conflict (profile_id) do update set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();
  return pid;
end; $$;

-- Public: what a code opens (and count the scan).
create or replace function public.nfc_tag_resolve(code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t nfc_private.tags; s text;
begin
  select * into t from nfc_private.tags where nfc_private.tags.code = upper(trim(nfc_tag_resolve.code));
  if t.code is null then return jsonb_build_object('status', 'unknown'); end if;
  if t.status <> 'active' then return jsonb_build_object('status', t.status); end if;
  update nfc_private.tags set scans = scans + 1, last_scan_at = now() where nfc_private.tags.code = t.code;
  if t.kind = 'card' then
    select custom_slug into s from public.nfc_profiles where id = t.profile_id and published;
    return jsonb_build_object('status', 'active', 'kind', 'card', 'slug', s);
  end if;
  return jsonb_build_object('status', 'active', 'kind', 'link', 'url', t.target_url);
end; $$;

-- Public: first activation of a blank code.
create or replace function public.nfc_tag_activate(code text, password text, kind text, link_type text default null,
  value text default null, full_name text default null, job_title text default null, phone text default null, contact text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t nfc_private.tags; pid uuid; u text; s text;
begin
  select * into t from nfc_private.tags where nfc_private.tags.code = upper(trim(nfc_tag_activate.code)) for update;
  if t.code is null then raise exception 'Invalid code'; end if;
  if t.status <> 'blank' then raise exception 'Already activated'; end if;
  if length(coalesce(password, '')) < 6 then raise exception 'Weak password'; end if;
  if kind = 'card' then
    pid := nfc_private.tag_card_profile(t, full_name, job_title, phone, password);
    select custom_slug into s from public.nfc_profiles where id = pid;
  elsif kind = 'link' then
    u := nfc_private.tag_url('link', link_type, value);
    if u is null then raise exception 'Link required'; end if;
  else
    raise exception 'Invalid kind';
  end if;
  update nfc_private.tags set status = 'active', kind = nfc_tag_activate.kind, link_type = nfc_tag_activate.link_type,
    target_url = u, profile_id = pid, pass_hash = extensions.crypt(password, extensions.gen_salt('bf')),
    owner_name = left(coalesce(nullif(trim(full_name), ''), owner_name), 80), owner_contact = left(trim(coalesce(contact, '')), 120),
    activated_at = now(), updated_at = now()
  where nfc_private.tags.code = t.code;
  return jsonb_build_object('ok', true, 'kind', kind, 'slug', s, 'url', u);
end; $$;

-- Public: owner signs in with code + password.
create or replace function public.nfc_tag_login(code text, password text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t nfc_private.tags; s text;
begin
  begin t := nfc_private.tag_check(code, password);
  exception when sqlstate '28000' then return jsonb_build_object('ok', false, 'error', sqlerrm); end;
  select custom_slug into s from public.nfc_profiles where id = t.profile_id;
  return jsonb_build_object('ok', true, 'kind', t.kind, 'link_type', t.link_type, 'url', t.target_url, 'slug', s, 'scans', t.scans);
end; $$;

-- Public: owner changes what the code opens (and can switch link <-> card).
create or replace function public.nfc_tag_update(code text, password text, kind text, link_type text default null,
  value text default null, full_name text default null, job_title text default null, phone text default null, new_password text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t nfc_private.tags; pid uuid; u text; s text; pw text;
begin
  begin t := nfc_private.tag_check(code, password);
  exception when sqlstate '28000' then return jsonb_build_object('ok', false, 'error', sqlerrm); end;
  pw := coalesce(nullif(new_password, ''), password);
  if length(pw) < 6 then raise exception 'Weak password'; end if;
  pid := t.profile_id;
  if kind = 'card' then
    if pid is null then pid := nfc_private.tag_card_profile(t, full_name, job_title, phone, pw); end if;
  elsif kind = 'link' then
    u := nfc_private.tag_url('link', link_type, value);
    if u is null then raise exception 'Link required'; end if;
  else
    raise exception 'Invalid kind';
  end if;
  if pid is not null then
    update nfc_private.profile_pins set pin_hash = extensions.crypt(pw, extensions.gen_salt('bf')), failed_attempts = 0, locked_until = null, updated_at = now() where profile_id = pid;
  end if;
  update nfc_private.tags set kind = nfc_tag_update.kind,
    link_type = case when nfc_tag_update.kind = 'link' then nfc_tag_update.link_type else t.link_type end,
    target_url = case when nfc_tag_update.kind = 'link' then u else t.target_url end,
    profile_id = pid, pass_hash = extensions.crypt(pw, extensions.gen_salt('bf')), updated_at = now()
  where nfc_private.tags.code = t.code;
  select custom_slug into s from public.nfc_profiles where id = pid;
  return jsonb_build_object('ok', true, 'kind', kind, 'slug', s, 'url', u);
end; $$;

-- Admin (super admin only).
create or replace function public.nfc_tag_batch_create(how_many int, label text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare i int; c text; out text[] := '{}'; b text := left(trim(coalesce(label, '')), 60);
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  if how_many < 1 or how_many > 500 then raise exception 'Between 1 and 500'; end if;
  if b = '' then b := to_char(now(), 'YYYY-MM-DD HH24:MI'); end if;
  for i in 1..how_many loop
    c := nfc_private.new_tag_code();
    insert into nfc_private.tags (code, batch, created_by) values (c, b, auth.uid());
    out := out || c;
  end loop;
  return jsonb_build_object('batch', b, 'codes', to_jsonb(out));
end; $$;

create or replace function public.nfc_tag_batches() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  return coalesce((select jsonb_agg(x order by x->>'created_at' desc) from (
    select jsonb_build_object('batch', batch, 'created_at', min(created_at), 'total', count(*),
      'active', count(*) filter (where status = 'active'), 'blank', count(*) filter (where status = 'blank'),
      'scans', sum(scans)) x
    from nfc_private.tags group by batch) q), '[]'::jsonb);
end; $$;

create or replace function public.nfc_tag_list(batch_name text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('code', t.code, 'status', t.status, 'kind', t.kind, 'link_type', t.link_type,
      'url', t.target_url, 'slug', p.custom_slug, 'owner', t.owner_name, 'contact', t.owner_contact, 'scans', t.scans,
      'activated_at', t.activated_at, 'last_scan_at', t.last_scan_at) order by t.created_at, t.code)
    from nfc_private.tags t left join public.nfc_profiles p on p.id = t.profile_id where t.batch = batch_name), '[]'::jsonb);
end; $$;

create or replace function public.nfc_tag_admin(code text, action text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t nfc_private.tags; pw text;
begin
  if not nfc_private.is_super_admin(auth.uid()) then raise exception 'Not authorized'; end if;
  select * into t from nfc_private.tags where nfc_private.tags.code = upper(trim(nfc_tag_admin.code)) for update;
  if t.code is null then raise exception 'Invalid code'; end if;
  if action = 'disable' then
    update nfc_private.tags set status = 'disabled', updated_at = now() where nfc_private.tags.code = t.code;
  elsif action = 'enable' then
    update nfc_private.tags set status = case when pass_hash is null then 'blank' else 'active' end, updated_at = now() where nfc_private.tags.code = t.code;
  elsif action = 'new_password' then
    pw := lpad((floor(random() * 1e8))::bigint::text, 8, '0');
    update nfc_private.tags set pass_hash = extensions.crypt(pw, extensions.gen_salt('bf')), failed_attempts = 0, locked_until = null, updated_at = now() where nfc_private.tags.code = t.code;
    if t.profile_id is not null then
      update nfc_private.profile_pins set pin_hash = extensions.crypt(pw, extensions.gen_salt('bf')), failed_attempts = 0, locked_until = null, updated_at = now() where profile_id = t.profile_id;
    end if;
    return jsonb_build_object('ok', true, 'password', pw);
  elsif action = 'reset' then
    if t.profile_id is not null then delete from public.nfc_profiles where id = t.profile_id; end if;
    update nfc_private.tags set status = 'blank', kind = null, link_type = null, target_url = null, profile_id = null, pass_hash = null,
      failed_attempts = 0, locked_until = null, owner_name = null, owner_contact = null, scans = 0, last_scan_at = null, activated_at = null, updated_at = now()
    where nfc_private.tags.code = t.code;
  else
    raise exception 'Unknown action';
  end if;
  return jsonb_build_object('ok', true);
end; $$;

revoke all on function public.nfc_tag_resolve(text) from public;
revoke all on function public.nfc_tag_activate(text, text, text, text, text, text, text, text, text) from public;
revoke all on function public.nfc_tag_login(text, text) from public;
revoke all on function public.nfc_tag_update(text, text, text, text, text, text, text, text, text) from public;
grant execute on function public.nfc_tag_resolve(text) to anon, authenticated;
grant execute on function public.nfc_tag_activate(text, text, text, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.nfc_tag_login(text, text) to anon, authenticated;
grant execute on function public.nfc_tag_update(text, text, text, text, text, text, text, text, text) to anon, authenticated;
revoke all on function public.nfc_tag_batch_create(int, text) from public, anon;
revoke all on function public.nfc_tag_batches() from public, anon;
revoke all on function public.nfc_tag_list(text) from public, anon;
revoke all on function public.nfc_tag_admin(text, text) from public, anon;
grant execute on function public.nfc_tag_batch_create(int, text) to authenticated;
grant execute on function public.nfc_tag_batches() to authenticated;
grant execute on function public.nfc_tag_list(text) to authenticated;
grant execute on function public.nfc_tag_admin(text, text) to authenticated;
