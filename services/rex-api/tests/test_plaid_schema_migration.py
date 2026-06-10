from pathlib import Path


MIGRATION = Path(__file__).resolve().parents[3] / "supabase" / "migrations" / (
    "20260607000200_create_plaid_foundation.sql"
)
PLAID_ACCOUNT_INSTITUTION_MIGRATION = (
    Path(__file__).resolve().parents[3]
    / "supabase"
    / "migrations"
    / "20260609000100_add_plaid_account_institution_name.sql"
)


def test_plaid_foundation_migration_is_user_scoped_and_select_only():
    sql = MIGRATION.read_text()

    assert "create table if not exists public.plaid_items" in sql
    assert "create table if not exists public.plaid_item_secrets" in sql
    assert "create table if not exists public.plaid_accounts" in sql
    assert "alter table public.plaid_items enable row level security" in sql
    assert "alter table public.plaid_item_secrets enable row level security" in sql
    assert "alter table public.plaid_accounts enable row level security" in sql
    assert "for select to authenticated" in sql
    assert "for all to authenticated" not in sql
    assert "auth.uid() = user_id" in sql

    secrets_section = sql.split(
        "create table if not exists public.plaid_item_secrets", 1
    )[1].split("create table if not exists public.plaid_accounts", 1)[0]
    assert "create policy" not in secrets_section
    assert "for select to authenticated" not in secrets_section


def test_plaid_foundation_does_not_store_raw_access_token_column():
    sql = MIGRATION.read_text().lower()

    assert "access_token_ref text not null" in sql
    assert "access_token text" not in sql
    assert "access_token_encrypted" not in sql
    assert "plaid_secret" not in sql


def test_plaid_source_columns_preserve_csv_and_manual_paths():
    sql = MIGRATION.read_text().lower()

    assert "add column if not exists source text not null default 'manual'" in sql
    assert "source in ('manual', 'csv', 'plaid')" in sql
    assert "where imported_from_csv = true" in sql
    assert "accounts_user_plaid_account_uidx" in sql
    assert "transactions_user_plaid_transaction_uidx" in sql


def test_plaid_accounts_keep_institution_snapshot_for_mobile_display():
    sql = PLAID_ACCOUNT_INSTITUTION_MIGRATION.read_text().lower()

    assert "alter table public.plaid_accounts" in sql
    assert "add column if not exists institution_name text" in sql
    assert "plaid_accounts_user_institution_idx" in sql
