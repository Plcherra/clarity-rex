alter table public.transactions
add column if not exists financial_role text;

alter table public.transactions
drop constraint if exists transactions_financial_role_check;

alter table public.transactions
add constraint transactions_financial_role_check
check (
  financial_role is null
  or financial_role in (
    'expense',
    'income',
    'transfer',
    'credit_card_payment',
    'refund',
    'adjustment'
  )
);

create index if not exists transactions_user_id_financial_role_idx
on public.transactions(user_id, financial_role)
where financial_role is not null;
