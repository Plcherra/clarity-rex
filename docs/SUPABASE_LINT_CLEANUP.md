# Supabase lint cleanup

Remediation for the Supabase **Database Linter** export (project `oanwrprjpkfsyzxjlwer`, 2026-06-27).

## Fixed in migration

Apply:

```bash
supabase db push
# or run supabase/migrations/20260627000100_supabase_lint_remediation.sql in the SQL editor
```

| Lint | Level | Fix |
| --- | --- | --- |
| `function_search_path_mutable` | WARN | `set_updated_at`, `normalize_category_name`, `set_category_normalized_name` now set `search_path = public` |
| `auth_rls_initplan` | WARN | All user-scoped RLS policies use `(select auth.uid())` instead of `auth.uid()` |
| `rls_enabled_no_policy` | INFO | Explicit deny policies on `admin_users` and `plaid_item_secrets` (backend/service-role only) |
| `unindexed_foreign_keys` | INFO | Indexes added for all flagged FK columns |
| `no_primary_key` | INFO | Primary keys added on legacy memory archive tables |

## Dashboard-only (you must do in Supabase UI)

### Leaked password protection (WARN)

1. **Authentication → Sign In / Providers → Email**
2. Enable **Leaked password protection** (HaveIBeenPwned check)

Docs: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### Auth DB connection strategy (INFO — optional at beta scale)

This lint is **low priority**. Fixed 10 Auth connections is fine until you scale up or see Auth pool errors.

**Where to find it (easy to miss):**

1. Left sidebar → **Authentication**
2. Scroll to **CONFIGURATION** → click **Performance** (last item in that section, below Audit Logs)
3. Find **Allocation strategy**
4. Change from **Absolute** (fixed number, e.g. 10) to **Percentage**
5. Set a reasonable max (Supabase often suggests ~10–20% on Pro; leave headroom for PostgREST/API)
6. **Save changes**

It is **not** under:

- Authentication → URL Configuration
- Authentication → Attack Protection
- Project Settings → Database → Connection pooling (that is Supavisor/Postgres, not Auth)

Docs: https://supabase.com/docs/guides/database/connection-management

## Intentionally deferred (INFO — do not “fix” yet)

### Unused indexes

The linter reports indexes with zero usage in `pg_stat_user_indexes`. At beta scale this is expected:

- **Chat recall:** `messages_content_fts_idx`, `messages_content_trgm_idx`, `conversations_title_*`
- **Hybrid search:** `chat_search_embeddings_*`
- **Finance / Plaid:** account and transaction source indexes
- **Usage admin:** `user_usage_events_*`

Keep these until production traffic proves they are unused. Re-export lints after beta traffic before dropping anything.

### Unused vs new FK indexes

The new FK indexes from `20260627000100` may also show as unused until delete/update paths exercise them. That is normal.

## Re-verify

After migration + dashboard changes:

1. Supabase Dashboard → **Database → Linter**
2. Re-export CSV and confirm WARN count is zero (except any new findings)
3. Smoke-test: sign-in, read accounts/transactions, Rex chat, Knows memory list
