-- Turns on the one-phone rule: every API request passes through
-- nfc_check_request (applied after the app that says hello was published).
alter role authenticator set pgrst.db_pre_request = 'public.nfc_check_request';
notify pgrst, 'reload config';
