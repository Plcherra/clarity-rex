-- Allow Supabase/PostgREST upserts to resolve Plaid account rows by user/account.
-- The earlier partial unique index protects Plaid rows, but PostgREST cannot use
-- a partial index for on_conflict=user_id,plaid_account_id.
create unique index if not exists accounts_user_plaid_account_conflict_uidx
on public.accounts(user_id, plaid_account_id);
