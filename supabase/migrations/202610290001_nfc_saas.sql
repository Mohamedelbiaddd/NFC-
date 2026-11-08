create schema if not exists nfc_private;
revoke all on schema nfc_private from public;
grant usage on schema nfc_private to authenticated;
create table public.nfc_tenants (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 120),
 owner_id uuid not null references auth.users(id), created_at timestamptz not null default now()
);
create table public.nfc_memberships (
 tenant_id uuid references public.nfc_tenants(id) on delete cascade,
 user_id uuid references auth.users(id) on delete cascade,
 role text not null check(role in ('owner','admin','editor','viewer')),
 primary key(tenant_id,user_id)
);
create function nfc_private.has_role(t uuid, roles text[] default array['owner','admin','editor','viewer']) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.nfc_memberships where tenant_id=t and user_id=auth.uid() and role=any(roles));
$$;
revoke all on function nfc_private.has_role(uuid,text[]) from public;
grant execute on function nfc_private.has_role(uuid,text[]) to authenticated;
create function nfc_private.valid_payload(k text,d jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare key text; val jsonb; allowed text[]; required_key text;
begin
 if jsonb_typeof(d)<>'object' or octet_length(d::text)>16000 then return false; end if;
 allowed:=array['description'];
 case k
 when 'vcard' then allowed:=allowed||array['full_name','phone','email','website']; required_key:='full_name';
 when 'menu' then allowed:=allowed||array['menu_url']; required_key:='menu_url';
 when 'review' then allowed:=allowed||array['review_url']; required_key:='review_url';
 when 'equipment' then allowed:=allowed||array['equipment_name','serial','manual_url']; required_key:='equipment_name';
 when 'loyalty' then allowed:=allowed||array['loyalty_url','terms']; required_key:='loyalty_url';
 else return false;
 end case;
 for key,val in select * from jsonb_each(d) loop
  if not(key=any(allowed)) or jsonb_typeof(val)<>'string' or length(d->>key)>2000 then return false; end if;
  if key in ('menu_url','review_url','manual_url','loyalty_url','website') and length(d->>key)>0 and
   ((d->>key)!~'^https://[^[:space:]]+$') then return false; end if;
 end loop;
 return coalesce(length(trim(d->>required_key))>0,false);
end; $$;
create table public.nfc_businesses (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
 name text not null check(length(name) between 1 and 120),
 primary_color text not null default '#7367F0' check(primary_color~'^#[0-9a-fA-F]{6}$'),
 accent_color text not null default '#2DD4BF' check(accent_color~'^#[0-9a-fA-F]{6}$'),
 created_at timestamptz not null default now(), unique(tenant_id,id)
);
create table public.nfc_profiles (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
 business_id uuid not null, kind text not null check(kind in ('vcard','menu','review','equipment','loyalty')),
 title text not null check(length(title) between 1 and 120), data jsonb not null default '{}',
 published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(tenant_id,business_id) references public.nfc_businesses(tenant_id,id) on delete cascade,
 check(nfc_private.valid_payload(kind,data))
);
create table public.nfc_write_events (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.nfc_tenants(id) on delete cascade,
 profile_id uuid not null references public.nfc_profiles(id) on delete cascade,
 actor_id uuid not null default auth.uid() references auth.users(id),
 action text not null check(action in ('written_verified','formatted_unverified','verified','locked')),
 created_at timestamptz not null default now()
);
create index on public.nfc_businesses(tenant_id);
create index on public.nfc_profiles(tenant_id,business_id);
create index on public.nfc_write_events(tenant_id,created_at);
create function nfc_private.guard_tenant() returns trigger language plpgsql set search_path='' as $$
begin
 if new.tenant_id<>old.tenant_id then raise exception 'Tenant cannot change'; end if;
 if tg_table_name='nfc_profiles' then new.updated_at:=now(); end if;
 return new;
end; $$;
create trigger nfc_business_tenant before update on public.nfc_businesses for each row execute function nfc_private.guard_tenant();
create trigger nfc_profile_tenant before update on public.nfc_profiles for each row execute function nfc_private.guard_tenant();
alter table public.nfc_tenants enable row level security;
alter table public.nfc_memberships enable row level security;
alter table public.nfc_businesses enable row level security;
alter table public.nfc_profiles enable row level security;
alter table public.nfc_write_events enable row level security;
create policy tenant_read on public.nfc_tenants for select to authenticated using(nfc_private.has_role(id));
create policy tenant_edit on public.nfc_tenants for update to authenticated using(nfc_private.has_role(id,array['owner','admin'])) with check(nfc_private.has_role(id,array['owner','admin']));
create policy tenant_delete on public.nfc_tenants for delete to authenticated using(nfc_private.has_role(id,array['owner']));
create policy membership_read on public.nfc_memberships for select to authenticated using(nfc_private.has_role(tenant_id));
create policy business_read on public.nfc_businesses for select to authenticated using(nfc_private.has_role(tenant_id));
create policy business_insert on public.nfc_businesses for insert to authenticated with check(nfc_private.has_role(tenant_id,array['owner','admin','editor']));
create policy business_edit on public.nfc_businesses for update to authenticated using(nfc_private.has_role(tenant_id,array['owner','admin','editor'])) with check(nfc_private.has_role(tenant_id,array['owner','admin','editor']));
create policy business_delete on public.nfc_businesses for delete to authenticated using(nfc_private.has_role(tenant_id,array['owner','admin']));
create policy profile_read on public.nfc_profiles for select to authenticated using(nfc_private.has_role(tenant_id));
create policy profile_insert on public.nfc_profiles for insert to authenticated with check(nfc_private.has_role(tenant_id,array['owner','admin','editor']));
create policy profile_edit on public.nfc_profiles for update to authenticated using(nfc_private.has_role(tenant_id,array['owner','admin','editor'])) with check(nfc_private.has_role(tenant_id,array['owner','admin','editor']));
create policy profile_delete on public.nfc_profiles for delete to authenticated using(nfc_private.has_role(tenant_id,array['owner','admin']));
create policy event_read on public.nfc_write_events for select to authenticated using(nfc_private.has_role(tenant_id));
create policy event_insert on public.nfc_write_events for insert to authenticated with check(actor_id=auth.uid() and nfc_private.has_role(tenant_id,array['owner','admin','editor']) and exists(select 1 from public.nfc_profiles p where p.id=profile_id and p.tenant_id=nfc_write_events.tenant_id));
revoke all on public.nfc_tenants,public.nfc_memberships,public.nfc_businesses,public.nfc_profiles,public.nfc_write_events from anon,authenticated;
grant select,delete on public.nfc_tenants to authenticated;
grant update(name) on public.nfc_tenants to authenticated;
grant select on public.nfc_memberships to authenticated;
grant select,insert,update,delete on public.nfc_businesses,public.nfc_profiles to authenticated;
grant select,insert on public.nfc_write_events to authenticated;
create function public.nfc_create_workspace(workspace_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare t uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 insert into public.nfc_tenants(name,owner_id) values(trim(workspace_name),auth.uid()) returning id into t;
 insert into public.nfc_memberships values(t,auth.uid(),'owner'); return t;
end; $$;
create function public.nfc_set_member(workspace_id uuid, member_email text, member_role text) returns void language plpgsql security definer set search_path='' as $$
declare u uuid;
begin
 if not nfc_private.has_role(workspace_id,array['owner','admin']) then raise exception 'Not authorized'; end if;
 if member_role not in ('admin','editor','viewer','remove') then raise exception 'Invalid role'; end if;
 select id into u from auth.users where lower(email)=lower(trim(member_email));
 if u is null then raise exception 'Account must register first'; end if;
 if exists(select 1 from public.nfc_memberships where tenant_id=workspace_id and user_id=u and role='owner') then raise exception 'Cannot change owner'; end if;
 if not nfc_private.has_role(workspace_id,array['owner']) and
 (member_role='admin' or exists(select 1 from public.nfc_memberships where tenant_id=workspace_id and user_id=u and role='admin')) then raise exception 'Only owner manages administrators'; end if;
 if member_role='remove' then delete from public.nfc_memberships where tenant_id=workspace_id and user_id=u;
 else insert into public.nfc_memberships values(workspace_id,u,member_role) on conflict(tenant_id,user_id) do update set role=excluded.role; end if;
end; $$;
create function public.nfc_public_profile(profile_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'title',p.title,'kind',p.kind,'data',p.data,'updated_at',p.updated_at,
 'business',jsonb_build_object('name',b.name,'primary_color',b.primary_color,'accent_color',b.accent_color))
 from public.nfc_profiles p join public.nfc_businesses b on b.id=p.business_id and b.tenant_id=p.tenant_id where p.id=profile_id and p.published=true;
$$;
revoke all on function public.nfc_create_workspace(text),public.nfc_set_member(uuid,text,text),public.nfc_public_profile(uuid) from public;
grant execute on function public.nfc_create_workspace(text),public.nfc_set_member(uuid,text,text) to authenticated;
grant execute on function public.nfc_public_profile(uuid) to anon,authenticated;
revoke all on function nfc_private.valid_payload(text,jsonb),nfc_private.guard_tenant() from public;
grant execute on function nfc_private.valid_payload(text,jsonb) to authenticated;
