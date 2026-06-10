alter table public.plaid_accounts
add column if not exists institution_name text;

create index if not exists plaid_accounts_user_institution_idx
on public.plaid_accounts(user_id, institution_name)
where institution_name is not null;
