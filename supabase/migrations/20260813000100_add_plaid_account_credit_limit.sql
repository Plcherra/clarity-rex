alter table public.plaid_accounts
  add column if not exists credit_limit numeric(12,2);
