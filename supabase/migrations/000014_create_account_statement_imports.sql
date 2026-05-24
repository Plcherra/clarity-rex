create table if not exists public.account_statement_imports (
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  import_id text not null,
  statement_balance numeric(12,2),
  statement_start_date date,
  statement_end_date date,
  transaction_count integer not null default 0 check (transaction_count >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, account_id, import_id)
);

create index if not exists account_statement_imports_user_account_created_idx
  on public.account_statement_imports(user_id, account_id, created_at desc);

alter table public.account_statement_imports enable row level security;

drop policy if exists "Users can manage their own statement imports"
  on public.account_statement_imports;
create policy "Users can manage their own statement imports"
on public.account_statement_imports
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
