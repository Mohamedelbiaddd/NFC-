-- Shop location and geofence radius (applied live as migration shop_geofence).
-- Google Wallet chooses its own trigger radius for nearby notifications; the
-- radius is kept for Apple Wallet (maxDistance) and for our own use.
alter table public.nfc_businesses
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists geofence_radius_m int not null default 200;
alter table public.nfc_businesses drop constraint if exists nfc_businesses_geo_check;
alter table public.nfc_businesses add constraint nfc_businesses_geo_check check (
  (latitude is null) = (longitude is null)
  and (latitude is null or (latitude between -90 and 90 and longitude between -180 and 180))
  and geofence_radius_m between 50 and 1000);
-- nfc_private.shop_public_json, public.nfc_shop_update and
-- public.nfc_shops_overview were redefined to read/write latitude, longitude
-- and radius_m (see the live database for the full definitions).
