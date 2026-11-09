-- Daily birthday job: every morning (08:05 UTC = 09:05 Morocco) the
-- wallet-pass function refreshes the Google Wallet cards of customers whose
-- birthday is today, with a notification. The call carries a random secret
-- kept in nfc_private.app_secrets (service role only).
create extension if not exists pg_cron;
create extension if not exists pg_net;

insert into nfc_private.app_secrets(name, value)
values ('CRON_SECRET', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (name) do nothing;

select cron.unschedule('nfc-birthdays') where exists (select 1 from cron.job where jobname = 'nfc-birthdays');
select cron.schedule('nfc-birthdays', '5 8 * * *', $job$
  select net.http_post(
    url := 'https://ikcaingdfybpqrdzucyd.supabase.co/functions/v1/wallet-pass',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('action', 'birthdays',
      'secret', (select value from nfc_private.app_secrets where name = 'CRON_SECRET')),
    timeout_milliseconds := 60000);
$job$);
