-- Each customer keeps the goal/reward of the cycle they are in (applied live
-- as migration customer_locked_goal). A shop changing its goal affects new
-- customers immediately and existing customers only from their next cycle,
-- i.e. after they received the reward they were working towards.
--
-- Functions redefined live: nfc_private.customer_json (goal/reward/old_rule
-- from the customer), nfc_private.add_visit (free when stamps >= customer
-- goal; a new cycle takes the shop's current rule), public.nfc_customer_join
-- (new customers lock the current rule) and public.nfc_shop_void_visit.
alter table public.nfc_customers
  add column if not exists goal int,
  add column if not exists reward text;
update public.nfc_customers c
   set goal = coalesce(c.goal, b.loyalty_goal), reward = coalesce(c.reward, b.loyalty_reward)
  from public.nfc_businesses b where b.id = c.business_id;
alter table public.nfc_customers drop constraint if exists nfc_customers_goal_check;
alter table public.nfc_customers add constraint nfc_customers_goal_check
  check (goal is null or goal between 1 and 50);
