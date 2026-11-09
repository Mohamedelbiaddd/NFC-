-- Industry template and opening hours for loyalty shops (applied live as
-- migration shop_industry_hours). See the live definitions of
-- nfc_private.shop_public_json, public.nfc_shop_update and
-- public.nfc_shops_overview, which now also return/accept industry and hours.
alter table public.nfc_businesses
  add column if not exists industry text not null default 'barber',
  add column if not exists hours text;
alter table public.nfc_businesses drop constraint if exists nfc_businesses_industry_check;
alter table public.nfc_businesses add constraint nfc_businesses_industry_check
  check (industry in ('barber','beauty','carwash','bakery','cafe','snack','other')
         and (hours is null or length(hours) <= 300));

create or replace function nfc_private.shop_public_json(b public.nfc_businesses)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'slug', b.shop_slug, 'name', b.name, 'primary_color', b.primary_color,
    'accent_color', b.accent_color, 'goal', b.loyalty_goal,
    'reward', b.loyalty_reward, 'phone', b.phone, 'address', b.address,
    'industry', b.industry, 'hours', b.hours, 'banners', b.banners);
$$;

create or replace function public.nfc_shop_update(target_slug text, session text, settings jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b public.nfc_businesses; new_banners jsonb; item jsonb;
begin
  b := nfc_private.shop_session(target_slug, session);
  if b.id is null then return jsonb_build_object('ok', false, 'error', 'session'); end if;
  new_banners := coalesce(settings -> 'banners', b.banners);
  if jsonb_typeof(new_banners) <> 'array' or jsonb_array_length(new_banners) > 5 then
    return jsonb_build_object('ok', false, 'error', 'banners');
  end if;
  for item in select * from jsonb_array_elements(new_banners) loop
    if jsonb_typeof(item) <> 'string'
       or (item #>> '{}') !~ '^https://[^[:space:]]+/storage/v1/object/public/profile-images/[^[:space:]]+$' then
      return jsonb_build_object('ok', false, 'error', 'banners');
    end if;
  end loop;
  update public.nfc_businesses set
    name = coalesce(nullif(trim(settings ->> 'name'), ''), name),
    phone = case when settings ? 'phone' then nullif(trim(settings ->> 'phone'), '') else phone end,
    address = case when settings ? 'address' then nullif(trim(settings ->> 'address'), '') else address end,
    hours = case when settings ? 'hours' then nullif(trim(settings ->> 'hours'), '') else hours end,
    loyalty_goal = coalesce((settings ->> 'goal')::int, loyalty_goal),
    loyalty_reward = coalesce(nullif(trim(settings ->> 'reward'), ''), loyalty_reward),
    banners = new_banners
  where id = b.id;
  return jsonb_build_object('ok', true);
exception when check_violation or invalid_text_representation then
  return jsonb_build_object('ok', false, 'error', 'invalid');
end; $$;

drop function if exists public.nfc_shops_overview(uuid);
create or replace function public.nfc_shops_overview(workspace_id uuid default null)
returns table(id uuid, tenant_id uuid, name text, shop_slug text, loyalty_enabled boolean,
              goal int, reward text, phone text, address text, hours text, industry text,
              created_by uuid, creator text,
              customers bigint, visits bigint, visits_7d bigint, has_password boolean,
              created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.id, b.tenant_id, b.name, b.shop_slug, b.loyalty_enabled, b.loyalty_goal,
         b.loyalty_reward, b.phone, b.address, b.hours, b.industry, b.created_by,
         coalesce(w.display_name, split_part(u.email, '@', 1)),
         (select count(*) from public.nfc_customers c where c.business_id = b.id),
         (select count(*) from public.nfc_visits v where v.business_id = b.id and not v.voided),
         (select count(*) from public.nfc_visits v where v.business_id = b.id and not v.voided
            and v.created_at > now() - interval '7 days'),
         exists (select 1 from nfc_private.shop_secrets s
                 where s.business_id = b.id and s.owner_pass_hash is not null),
         b.created_at
  from public.nfc_businesses b
  left join auth.users u on u.id = b.created_by
  left join public.nfc_workers w on w.id = b.created_by
  where b.shop_slug is not null
    and ((workspace_id is not null and b.tenant_id = workspace_id
          and nfc_private.has_role(workspace_id))
         or (workspace_id is null and nfc_private.is_super_admin(auth.uid())))
  order by b.created_at desc;
$$;
revoke all on function public.nfc_shops_overview(uuid) from public;
grant execute on function public.nfc_shops_overview(uuid) to authenticated;
