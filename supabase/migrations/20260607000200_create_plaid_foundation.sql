create table if not exists public.plaid_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plaid_item_id text not null,
  institution_id text,
  institution_name text,
  sync_cursor text,
  status text not null default 'active',
  last_synced_at timestamptz,
  webhook_last_received_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plaid_items_status_check
    check (status in ('active', 'degraded', 'disconnected', 'error'))
);

create unique index if not exists plaid_items_user_id_id_uidx
on public.plaid_items(user_id, id);

create unique index if not exists plaid_items_user_plaid_item_uidx
on public.plaid_items(user_id, plaid_item_id);

create index if not exists plaid_items_user_status_idx
on public.plaid_items(user_id, status);

drop trigger if exists plaid_items_set_updated_at on public.plaid_items;
create trigger plaid_items_set_updated_at
before update on public.plaid_items
for each row
execute function public.set_updated_at();

alter table public.plaid_items enable row level security;

drop policy if exists "Users can view their own Plaid items"
  on public.plaid_items;
create policy "Users can view their own Plaid items"
on public.plaid_items
for select to authenticated
using (auth.uid() = user_id);

create table if not exists public.plaid_item_secrets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null,
  access_token_ref text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plaid_item_secrets_item_user_fk
    foreign key (user_id, item_id)
    references public.plaid_items(user_id, id)
    on delete cascade
);

create unique index if not exists plaid_item_secrets_user_item_uidx
on public.plaid_item_secrets(user_id, item_id);

drop trigger if exists plaid_item_secrets_set_updated_at on public.plaid_item_secrets;
create trigger plaid_item_secrets_set_updated_at
before update on public.plaid_item_secrets
for each row
execute function public.set_updated_at();

alter table public.plaid_item_secrets enable row level security;

create table if not exists public.plaid_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null,
  plaid_account_id text not null,
  linked_account_id uuid,
  name text not null,
  official_name text,
  mask text,
  account_type text,
  account_subtype text,
  status text not null default 'active',
  current_balance numeric(12,2),
  available_balance numeric(12,2),
  iso_currency_code text,
  unofficial_currency_code text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plaid_accounts_item_user_fk
    foreign key (user_id, item_id)
    references public.plaid_items(user_id, id)
    on delete cascade,
  constraint plaid_accounts_linked_account_user_fk
    foreign key (user_id, linked_account_id)
    references public.accounts(user_id, id)
    on delete set null (linked_account_id),
  constraint plaid_accounts_status_check
    check (status in ('active', 'inactive', 'degraded', 'disconnected'))
);

create unique index if not exists plaid_accounts_user_plaid_account_uidx
on public.plaid_accounts(user_id, plaid_account_id);

create index if not exists plaid_accounts_user_item_idx
on public.plaid_accounts(user_id, item_id);

create index if not exists plaid_accounts_user_linked_account_idx
on public.plaid_accounts(user_id, linked_account_id)
where linked_account_id is not null;

drop trigger if exists plaid_accounts_set_updated_at on public.plaid_accounts;
create trigger plaid_accounts_set_updated_at
before update on public.plaid_accounts
for each row
execute function public.set_updated_at();

alter table public.plaid_accounts enable row level security;

drop policy if exists "Users can view their own Plaid accounts"
  on public.plaid_accounts;
create policy "Users can view their own Plaid accounts"
on public.plaid_accounts
for select to authenticated
using (auth.uid() = user_id);

alter table public.accounts
add column if not exists source text not null default 'manual',
add column if not exists plaid_item_record_id uuid,
add column if not exists plaid_account_id text,
add column if not exists sync_status text,
add column if not exists last_synced_at timestamptz;

alter table public.accounts
drop constraint if exists accounts_source_check;

alter table public.accounts
add constraint accounts_source_check
check (source in ('manual', 'csv', 'plaid'));

alter table public.accounts
drop constraint if exists accounts_plaid_item_user_fk;

alter table public.accounts
add constraint accounts_plaid_item_user_fk
foreign key (user_id, plaid_item_record_id)
references public.plaid_items(user_id, id)
on delete set null (plaid_item_record_id);

create unique index if not exists accounts_user_plaid_account_uidx
on public.accounts(user_id, plaid_account_id)
where plaid_account_id is not null;

create index if not exists accounts_user_source_idx
on public.accounts(user_id, source);

create index if not exists accounts_user_plaid_item_idx
on public.accounts(user_id, plaid_item_record_id)
where plaid_item_record_id is not null;

alter table public.transactions
add column if not exists source text not null default 'manual',
add column if not exists plaid_item_record_id uuid,
add column if not exists plaid_account_id text,
add column if not exists plaid_transaction_id text,
add column if not exists plaid_pending_transaction_id text,
add column if not exists pending boolean not null default false,
add column if not exists removed_at timestamptz,
add column if not exists last_synced_at timestamptz;

update public.transactions
set source = 'csv'
where imported_from_csv = true
  and source = 'manual';

alter table public.transactions
drop constraint if exists transactions_source_check;

alter table public.transactions
add constraint transactions_source_check
check (source in ('manual', 'csv', 'plaid'));

alter table public.transactions
drop constraint if exists transactions_plaid_item_user_fk;

alter table public.transactions
add constraint transactions_plaid_item_user_fk
foreign key (user_id, plaid_item_record_id)
references public.plaid_items(user_id, id)
on delete set null (plaid_item_record_id);

create unique index if not exists transactions_user_plaid_transaction_uidx
on public.transactions(user_id, plaid_transaction_id)
where plaid_transaction_id is not null;

create index if not exists transactions_user_source_idx
on public.transactions(user_id, source);

create index if not exists transactions_user_plaid_item_idx
on public.transactions(user_id, plaid_item_record_id)
where plaid_item_record_id is not null;

comment on table public.plaid_item_secrets is
  'Backend-only Plaid token reference table. No authenticated read policy should be added.';

comment on column public.plaid_item_secrets.access_token_ref is
  'Backend-only reference for a Plaid access token. Do not store raw Plaid access tokens in client-readable rows.';
