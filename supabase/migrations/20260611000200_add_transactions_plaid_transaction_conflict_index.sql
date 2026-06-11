-- Allow Supabase/PostgREST upserts to resolve Plaid transaction rows by user/transaction.
-- The existing partial unique index protects Plaid rows, but PostgREST cannot use
-- a partial index for on_conflict=user_id,plaid_transaction_id.
create unique index if not exists transactions_user_plaid_transaction_conflict_uidx
on public.transactions(user_id, plaid_transaction_id);
