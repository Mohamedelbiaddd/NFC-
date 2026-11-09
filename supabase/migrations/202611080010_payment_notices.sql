-- Manual payment notices and owner-visible suspension (applied live as
-- migration payment_notices).
--
-- * nfc_businesses.notice / nfc_staff.notice: a message written by the agent
--   or admin (never automatic) shown on the shop owner's dashboard / in the
--   staff member's app. Cleared by hand or automatically by a payment.
-- * Suspended shops: customers' pages stay off, but the owner can still log in
--   and sees a suspension page instead of a "wrong password" error.
--
-- Functions redefined live: nfc_private.shop_by_slug_owner (new),
-- nfc_private.shop_session, public.nfc_shop_login, public.nfc_shop_qr,
-- public.nfc_shop_dashboard (suspended, notice, status), public.nfc_shop_update
-- (refused while suspended), public.nfc_set_notice (new),
-- nfc_private.clear_notice_on_payment (trigger), public.nfc_my_account,
-- public.nfc_network_members and public.nfc_network_shops (+ notice).
alter table public.nfc_businesses
  add column if not exists notice text check (notice is null or length(notice) <= 1000),
  add column if not exists notice_at timestamptz;
alter table public.nfc_staff
  add column if not exists notice text check (notice is null or length(notice) <= 1000),
  add column if not exists notice_at timestamptz;
