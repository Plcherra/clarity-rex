alter table public.merchant_category_rules
  add column if not exists disabled boolean not null default false;

create index if not exists merchant_category_rules_user_disabled_idx
  on public.merchant_category_rules(user_id, disabled);
