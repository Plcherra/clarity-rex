-- Money pressure on goals.
--
-- $0 means the goal does not need money. Positive amounts feed the cumulative
-- "need X by date" view on the Goals tab. Default 0 so existing goals stay
-- non-money until someone sets a figure.

alter table public.plans
  add column if not exists target_amount numeric(12, 2) not null default 0;

alter table public.plans
  drop constraint if exists plans_target_amount_non_negative;

alter table public.plans
  add constraint plans_target_amount_non_negative
  check (target_amount >= 0);

comment on column public.plans.target_amount is
  'Dollars the goal needs. 0 means not a money goal.';
