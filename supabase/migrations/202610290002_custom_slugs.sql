alter table public.nfc_profiles add column custom_slug text, add column slug_locked boolean not null default false;
update public.nfc_profiles set custom_slug='profile-'||substr(md5(id::text||clock_timestamp()::text),1,16),slug_locked=published;
alter table public.nfc_profiles alter column custom_slug set not null;
alter table public.nfc_profiles add constraint nfc_profiles_custom_slug_key unique(custom_slug),add constraint nfc_profiles_custom_slug_format check(length(custom_slug) between 3 and 63 and custom_slug~'^[a-z0-9]+(-[a-z0-9]+)*$' and custom_slug not in ('admin','api','assets','auth','login','logout','settings','www','new'));
create table nfc_private.slug_reservations(slug text primary key,profile_id uuid not null);
revoke all on nfc_private.slug_reservations from public,anon,authenticated;
insert into nfc_private.slug_reservations select custom_slug,id from public.nfc_profiles;
create function nfc_private.guard_slug() returns trigger language plpgsql security definer set search_path='' as $$
declare holder uuid;
begin
 if tg_op='UPDATE' then
  if old.slug_locked and new.custom_slug is distinct from old.custom_slug then raise exception 'Published slug is permanent. Create a new profile instead.' using errcode='23514';end if;
  new.slug_locked:=old.slug_locked or new.published;
 else new.slug_locked:=new.published;end if;
 insert into nfc_private.slug_reservations(slug,profile_id) values(new.custom_slug,new.id) on conflict(slug) do nothing;
 select profile_id into holder from nfc_private.slug_reservations where slug=new.custom_slug;
 if holder is distinct from new.id then raise exception 'Slug already reserved' using errcode='23505';end if;
 return new;
end;$$;
revoke all on function nfc_private.guard_slug() from public;
create trigger nfc_profile_slug before insert or update on public.nfc_profiles for each row execute function nfc_private.guard_slug();
create function public.nfc_public_profile_by_slug(slug text) returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('custom_slug',p.custom_slug,'title',p.title,'kind',p.kind,'data',p.data,'updated_at',p.updated_at,'business',jsonb_build_object('name',b.name,'primary_color',b.primary_color,'accent_color',b.accent_color)) from public.nfc_profiles p join public.nfc_businesses b on b.id=p.business_id and b.tenant_id=p.tenant_id where p.custom_slug=slug and p.published=true;
$$;
revoke all on function public.nfc_public_profile_by_slug(text) from public;
grant execute on function public.nfc_public_profile_by_slug(text) to anon,authenticated;
revoke all on function public.nfc_public_profile(uuid) from anon,authenticated;
