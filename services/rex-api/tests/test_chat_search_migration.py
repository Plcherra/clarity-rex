from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[3]
MIGRATION_PATH = (
    PROJECT_ROOT
    / "supabase"
    / "migrations"
    / "20260623000100_add_rex_chat_search_indexes.sql"
)
EMBEDDINGS_MIGRATION_PATH = (
    PROJECT_ROOT
    / "supabase"
    / "migrations"
    / "20260623000200_create_chat_search_embeddings.sql"
)


def test_chat_search_migration_keeps_search_user_scoped():
    sql = MIGRATION_PATH.read_text(encoding="utf-8").lower()

    assert "create extension if not exists pg_trgm" in sql
    assert "security invoker" in sql
    assert "m.user_id = auth.uid()" in sql
    assert "c.user_id = auth.uid()" in sql
    assert "grant execute on function public.search_user_chat_messages" in sql
    assert "security definer" not in sql


def test_chat_search_migration_adds_scale_indexes():
    sql = MIGRATION_PATH.read_text(encoding="utf-8").lower()

    assert "messages_user_timestamp_idx" in sql
    assert "messages_content_fts_idx" in sql
    assert "messages_content_trgm_idx" in sql
    assert "conversations_title_fts_idx" in sql
    assert "conversations_title_trgm_idx" in sql


def test_chat_search_embeddings_migration_is_user_scoped_vector_scaffold():
    sql = EMBEDDINGS_MIGRATION_PATH.read_text(encoding="utf-8").lower()

    assert "create extension if not exists vector" in sql
    assert "create table if not exists public.chat_search_embeddings" in sql
    assert "embedding extensions.vector(1536)" in sql
    assert "enable row level security" in sql
    assert "auth.uid() = user_id" in sql
    assert "using hnsw" in sql
    assert "vector_cosine_ops" in sql
