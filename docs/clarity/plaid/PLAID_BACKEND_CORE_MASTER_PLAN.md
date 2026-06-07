#3 Plaid Backend Core

Status: In Progress

Last updated: June 6, 2026

## Purpose

Build Plaid as Clarity's backend-owned financial ingestion system. Mobile launches Link and sends public tokens; backend owns secrets, access tokens, item/account persistence, transaction sync, webhooks, and user isolation.

## Core Outcome

By the end of this plan:

- Plaid secrets and access tokens never leave backend-controlled code.
- Users can create Link tokens and exchange public tokens through authenticated routes.
- Plaid items, accounts, sync cursors, and transactions persist per user.
- Backend supports disconnect, webhook, and sandbox QA.

## Non-Goals

- Do not implement mobile Link UI in this plan.
- Do not remove CSV fallback.
- Do not let Assistant call Plaid directly.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Plaid contract | ADR/module contract exists. | Plan needs executable backend phases. |
| Backend routes | No complete Plaid route set. | Mobile cannot connect banks. |
| Token storage | Not fully implemented. | Secrets could leak if ownership is unclear. |
| Transactions | CSV/manual oriented. | No sync cursor or Plaid id mapping. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Config | Backend validates Plaid env and secrets. | Safe fail-closed setup. |
| Routes | Authenticated Link/exchange/sync/disconnect/webhook routes. | Mobile has one secure path. |
| Persistence | User-scoped Plaid item/account/transaction records. | Reliable connected finance. |
| Tests | Sandbox and mocked backend tests. | Confidence before mobile integration. |

## Phase 1 - Plaid Config And Secret Policy

Goal: Define Plaid backend configuration and fail-closed behavior.

Files to change:

- `services/rex-api/app/services/plaid_config.py`
- `services/rex-api/app/config.py`
- `services/rex-api/tests/test_plaid_config.py`

Steps:

1. Define required env vars for client id, secret, environment, products, country codes, and redirect/native settings.
2. Add a config helper that reports readiness without exposing secrets.
3. Ensure missing config returns explicit configured=false behavior.
4. Add tests for sandbox, missing config, and secret redaction.

Done looks like:

- Plaid cannot accidentally claim success when env is incomplete.

Acceptance criteria:

- [x] `/ready` reports Plaid readiness without secrets.
- [x] Missing config fails closed.
- [x] Config file remains under 250 lines.

## Phase 2 - Plaid Tables And RLS

Goal: Add database foundation for Plaid items, accounts, sync cursors, and source-aware rows.

Files to change:

- `supabase/migrations/*_create_plaid_items.sql`
- `supabase/migrations/*_create_plaid_accounts.sql`
- `supabase/migrations/*_add_plaid_source_columns.sql`

Steps:

1. Create `plaid_items` with user ownership, Plaid item id, institution metadata, encrypted token reference, cursor, status, timestamps.
2. Create `plaid_accounts` with user/item ownership, Plaid account id, mask, type/subtype, status, linked Clarity account id.
3. Add Plaid source columns to accounts/transactions.
4. Add RLS for user-scoped reads and backend-owned writes.

Done looks like:

- Supabase can store connected institutions without exposing Plaid tokens.

Acceptance criteria:

- [x] Cross-user reads are blocked.
- [x] Access tokens are not available to mobile/Supabase client reads.
- [x] Existing CSV/manual data remains compatible.

## Phase 3 - Plaid Client Wrapper

Goal: Isolate Plaid API calls in one small backend wrapper.

Files to change:

- `services/rex-api/app/services/plaid_api_client.py`
- `services/rex-api/tests/test_plaid_api_client.py`

Steps:

1. Add wrapper methods for link token, public token exchange, accounts, transaction sync, item remove, and webhook verification if needed.
2. Normalize Plaid errors into safe app error classes.
3. Ensure logs never include secrets or access tokens.
4. Mock Plaid calls in tests.

Done looks like:

- Plaid API access is testable and not scattered.

Acceptance criteria:

- [ ] No Plaid SDK/API calls exist outside wrapper/service boundary.
- [ ] Wrapper logs no secrets.
- [ ] Wrapper remains under 300 lines.

## Phase 4 - Link Token Route

Goal: Add authenticated route for mobile to start Plaid Link.

Files to change:

- `services/rex-api/app/routes/plaid.py`
- `services/rex-api/app/main.py`
- `services/rex-api/tests/test_plaid_routes.py`

Steps:

1. Add `POST /plaid/link-token`.
2. Require authenticated Supabase user.
3. Return link token and safe expiration/status metadata only.
4. Track sanitized usage event.

Done looks like:

- Mobile can request a Link token securely.

Acceptance criteria:

- [ ] Unauthenticated requests fail.
- [ ] Response contains no access token or secret.
- [ ] Route file remains under 250 lines.

## Phase 5 - Public Token Exchange Route

Goal: Exchange public token and persist the Plaid item.

Files to change:

- `services/rex-api/app/routes/plaid.py`
- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/tests/test_plaid_exchange_route.py`

Steps:

1. Add `POST /plaid/exchange-token`.
2. Exchange public token backend-side.
3. Store access token only through encrypted/backend-owned path.
4. Return safe item/account summaries.
5. Track sanitized usage event.

Done looks like:

- Public token exchange completes without exposing access token.

Acceptance criteria:

- [ ] Access token never appears in route response.
- [ ] Item is scoped to authenticated user.
- [ ] Exchange failure returns safe error.

## Phase 6 - Item Persistence

Goal: Create and update Plaid item records reliably.

Files to change:

- `services/rex-api/app/services/plaid_item_repository.py`
- `services/rex-api/tests/test_plaid_item_repository.py`

Steps:

1. Add repository methods for create, update status, update cursor, disconnect, and lookup by user.
2. Guard every write by user id.
3. Store institution metadata and sync status.
4. Keep item removal separate from historical transaction deletion.

Done looks like:

- Backend can manage item lifecycle safely.

Acceptance criteria:

- [ ] Repository refuses cross-user item updates.
- [ ] Disconnect marks item inactive/degraded without deleting unrelated history.
- [ ] Repository remains under 300 lines.

## Phase 7 - Account Persistence

Goal: Map Plaid accounts into Clarity accounts.

Files to change:

- `services/rex-api/app/services/plaid_account_mapper.py`
- `services/rex-api/app/services/plaid_account_repository.py`
- `services/rex-api/tests/test_plaid_account_mapper.py`

Steps:

1. Fetch Plaid accounts after exchange/sync.
2. Create or update linked Clarity accounts.
3. Preserve manual/CSV accounts.
4. Store account status, type, subtype, mask, and source quietly.

Done looks like:

- Connected bank accounts show up as Clarity accounts.

Acceptance criteria:

- [ ] Same Plaid account updates existing linked account.
- [ ] Manual accounts are not overwritten.
- [ ] Cross-user account mutation is blocked.

## Phase 8 - Transaction Sync With Cursor

Goal: Sync Plaid transactions incrementally into Clarity.

Files to change:

- `services/rex-api/app/services/plaid_transaction_sync.py`
- `services/rex-api/app/services/plaid_transaction_mapper.py`
- `services/rex-api/tests/test_plaid_transaction_sync.py`

Steps:

1. Use Plaid cursor-based sync.
2. Upsert added/modified transactions.
3. Mark removed transactions without breaking history.
4. Store Plaid transaction id and pending status.
5. Update cursor only after successful sync.

Done looks like:

- Transactions sync reliably without duplicates.

Acceptance criteria:

- [ ] Added, modified, removed, and pending transactions are handled.
- [ ] Cursor advances only after success.
- [ ] Existing CSV/manual transactions remain intact.

## Phase 9 - Webhook Handling

Goal: Add backend webhook handling for Plaid sync updates.

Files to change:

- `services/rex-api/app/routes/plaid_webhooks.py`
- `services/rex-api/app/services/plaid_webhook_service.py`
- `services/rex-api/tests/test_plaid_webhooks.py`

Steps:

1. Add webhook route.
2. Verify webhook payload/source according to Plaid requirements.
3. Queue or trigger safe sync for the owning item.
4. Track sanitized webhook usage/failure events.

Done looks like:

- Plaid can notify Clarity when transactions need syncing.

Acceptance criteria:

- [ ] Invalid webhook payloads are rejected.
- [ ] Webhook never exposes tokens in logs.
- [ ] Sync is user/item scoped.

## Phase 10 - Backend Plaid Test Suite

Goal: Prove backend Plaid is safe before mobile integration.

Files to change:

- `services/rex-api/tests/test_plaid_*`
- `docs/clarity/plaid/PLAID_BACKEND_QA_REPORT.md`

Steps:

1. Run focused Plaid backend tests.
2. Run RLS/user isolation checks.
3. Run readiness and missing-config checks.
4. Document sandbox readiness.

Done looks like:

- Backend is ready for mobile Link work.

Acceptance criteria:

- [ ] Focused Plaid tests pass.
- [ ] RLS checks pass.
- [ ] QA report lists remaining risks.

## Verification Commands

```bash
supabase db push
cd services/rex-api && pytest tests/test_plaid_config.py tests/test_plaid_routes.py tests/test_plaid_item_repository.py tests/test_plaid_transaction_sync.py tests/test_plaid_webhooks.py
rg -n "access_token|PLAID_SECRET|public_token" services/rex-api/app/routes apps/mobile/lib
```

## Execution Order

1. `CLARITY_PREBUILD_FOUNDATION_MASTER_PLAN.md`
2. `CLARITY_USAGE_TRACKING_SIMPLIFIED_PLAN.md`
3. `PLAID_BACKEND_CORE_MASTER_PLAN.md`
4. `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
5. `CLARITY_DESIGN_SYSTEM_MASTER_PLAN.md`
6. `CLARITY_UNIFIED_PRODUCT_SHELL_MASTER_PLAN.md`
7. `CLARITY_FINANCIAL_EXPERIENCE_MASTER_PLAN.md`
8. `CLARITY_ASSISTANT_INTELLIGENCE_MASTER_PLAN.md`
9. `CLARITY_RELEASE_VALIDATION_MASTER_PLAN.md`

## Release Gate

Mobile Plaid work starts only after backend sandbox link/exchange/sync/disconnect paths are safe and tested.

## Completion Ledger

- Phase 1 completed on June 7, 2026: added backend Plaid settings, a secret-safe readiness helper, optional `/ready` Plaid reporting, missing-config fail-closed behavior, `.env.example` Plaid placeholders, and focused config/readiness tests.
- Phase 2 completed on June 7, 2026: added Plaid item/account tables, a backend-only token reference table, select-only user RLS, source-aware account/transaction columns, CSV backfill compatibility, and schema tests proving no raw access-token column is exposed.
