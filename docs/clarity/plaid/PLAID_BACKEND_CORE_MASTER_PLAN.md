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

- [x] No Plaid SDK/API calls exist outside wrapper/service boundary.
- [x] Wrapper logs no secrets.
- [x] Wrapper remains under 300 lines.

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
4. Fail closed on missing config and return safe normalized Plaid errors.

Done looks like:

- Mobile can request a Link token securely.

Acceptance criteria:

- [x] Unauthenticated requests fail.
- [x] Response contains no access token or secret.
- [x] Route file remains under 250 lines.

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
5. Do not record broad feature analytics under simplified usage v1.

Done looks like:

- Public token exchange completes without exposing access token.

Acceptance criteria:

- [x] Access token never appears in route response.
- [x] Item is scoped to authenticated user.
- [x] Exchange failure returns safe error.

## Phase 6 - Plaid Webhook And Item Status Route

Goal: Add a lightweight Plaid webhook receiver and authenticated item status route.

Files to change:

- `services/rex-api/app/routes/plaid.py`
- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/tests/test_plaid_webhook_routes.py`
- `services/rex-api/tests/test_plaid_sync_service.py`

Steps:

1. Add `POST /plaid/webhook` with basic Plaid verification header checks.
2. Add authenticated `GET /plaid/item-status/{item_id}` scoped to the current user.
3. Handle `ITEM_LOGIN_REPAIRED`, `SYNC_UPDATES_AVAILABLE`, and `ITEMS:REMOVE` events.
4. Return from webhooks quickly and defer item updates through background handling.
5. Do not implement full transaction sync in this phase.

Done looks like:

- Plaid can notify Clarity about item status changes without exposing secrets.

Acceptance criteria:

- [x] Webhook rejects missing or invalid verification headers.
- [x] Item status route is authenticated and user scoped.
- [x] Webhook updates item status metadata without exposing tokens.
- [x] Full transaction sync remains out of scope.

## Phase 7 - Plaid Account And Transaction Sync

Goal: Manually sync a connected Plaid item into Clarity accounts and transactions.

Files to change:

- `services/rex-api/app/routes/plaid.py`
- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/tests/test_plaid_sync_service.py`
- `services/rex-api/tests/test_plaid_webhook_routes.py`

Steps:

1. Decrypt the backend-only Plaid access token reference.
2. Fetch Plaid accounts and upsert linked Clarity/Plaid account rows.
3. Run cursor-based Plaid transaction sync manually.
4. Upsert added/modified Plaid transactions with `source = 'plaid'`.
5. Mark removed Plaid transactions without deleting history.
6. Update the item cursor only after sync work completes.
7. Expose owner-only `POST /plaid/sync-item/{item_id}`.

Done looks like:

- Owner can manually sync one Plaid item into persisted Clarity financial data.

Acceptance criteria:

- [x] Same Plaid account updates existing linked account rows.
- [x] Transactions use `source = 'plaid'`.
- [x] Cursor advances only after sync completes.
- [x] Sync route is authenticated and owner-only.
- [x] Access token never appears in route responses.

## Phase 7.5 - Refactor PlaidSyncService

Goal: Split the large Plaid sync service into focused units without changing external behavior.

Files to change:

- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/app/services/plaid_token_service.py`
- `services/rex-api/app/services/plaid_account_service.py`
- `services/rex-api/app/services/plaid_transaction_service.py`
- `services/rex-api/app/services/plaid_cursor_service.py`
- `services/rex-api/app/dependencies.py`
- `services/rex-api/tests/test_plaid_sync_service.py`

Steps:

1. Move token encryption/decryption into a token service.
2. Move item/cursor/Supabase storage calls into a cursor service.
3. Move account fetch/upsert behavior into an account service.
4. Move transaction sync/upsert/removed behavior into a transaction service.
5. Keep `PlaidSyncService.sync_item()` as the same public orchestration API.
6. Update tests without changing expected behavior.

Done looks like:

- `PlaidSyncService` is a thin orchestrator and each focused service remains small.

Acceptance criteria:

- [x] `PlaidSyncService.sync_item()` public API is unchanged.
- [x] Each focused service is under 300 lines.
- [x] Existing Plaid tests pass.
- [x] No external route behavior changes.

## Phase 8 - Transaction Sync Hardening And Cursor Safety

Goal: Harden the existing Plaid transaction sync path for idempotency, pending rows, removed rows, and cursor safety.

Files to change:

- `services/rex-api/app/services/plaid_transaction_sync.py`
- `services/rex-api/app/services/plaid_transaction_mapper.py`
- `services/rex-api/app/services/plaid_transaction_service.py`
- `services/rex-api/tests/test_plaid_transaction_sync.py`

Steps:

1. Move transaction payload mapping into a dedicated mapper.
2. Move transaction sync orchestration into a dedicated sync service.
3. Preserve idempotency with `user_id,plaid_transaction_id` upserts.
4. Preserve pending transaction fields.
5. Mark removed transactions with `removed_at` without deleting history.
6. Update the cursor only after all transaction writes complete.
7. Add tests for cursor-update failures and retry-safe upsert behavior.

Done looks like:

- Transaction sync is ready for repeated/manual syncs without duplicate rows or unsafe cursor advancement.

Acceptance criteria:

- [x] Added, modified, removed, and pending transactions are handled.
- [x] Cursor advances only after transaction writes complete.
- [x] Existing CSV/manual transactions remain intact.
- [x] Transaction sync and mapper files remain under 300 lines.

## Phase 9 - Webhook Handling

Goal: Harden backend webhook handling for Plaid sync updates.

Files to change:

- `services/rex-api/app/routes/plaid.py`
- `services/rex-api/app/routes/plaid_webhooks.py`
- `services/rex-api/app/services/plaid_webhook_service.py`
- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/app/main.py`
- `services/rex-api/tests/test_plaid_webhook_routes.py`

Steps:

1. Move `POST /plaid/webhook` into a dedicated webhook route file.
2. Verify Plaid verification header and reject malformed webhook payloads.
3. Require `item_id` for item-scoped webhook events.
4. Queue safe background item handling through the existing sync service.
5. Mark sync-needed events as item metadata instead of running full sync inline.
6. Do not record broad Plaid analytics under simplified usage v1.

Done looks like:

- Plaid can notify Clarity when transactions need syncing.

Acceptance criteria:

- [x] Invalid webhook payloads are rejected.
- [x] Webhook never exposes tokens in responses.
- [x] Sync-needed webhook handling is item scoped.
- [x] Webhook route returns quickly and defers item handling.

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
- Phase 3 completed on June 7, 2026: added a small Plaid REST wrapper for Link token creation, public token exchange, accounts, transaction sync, and item removal, with safe error normalization and mocked endpoint tests.
- Phase 4 completed on June 7, 2026: added authenticated `POST /plaid/link-token`, safe Link-token-only response shaping, cross-user request rejection, missing-config 503 behavior, normalized Plaid error responses, route wiring, and focused route tests.
- Phase 5 completed on June 7, 2026: added authenticated `POST /plaid/exchange-token`, public-token exchange through the Plaid client wrapper, service-role item persistence, encrypted backend-only Plaid token references, safe item summary responses, and focused route/service tests.
- Phase 6 completed on June 7, 2026: added `POST /plaid/webhook` with basic Plaid verification header gating, authenticated user-scoped `GET /plaid/item-status/{item_id}`, background webhook handling for login repair, sync update, and item remove events, and focused route/service tests without implementing full transaction sync.
- Phase 7 completed on June 7, 2026: added manual owner-only `POST /plaid/sync-item/{item_id}`, decrypted backend token use, Plaid account fetch, linked Clarity/Plaid account upserts, cursor-based transaction sync for added/modified/removed rows, final cursor update, rate-limit handling, and focused route/service tests.
- Phase 7.5 completed on June 7, 2026: split the 730-line Plaid sync service into token, cursor, account, and transaction services while keeping `PlaidSyncService.sync_item()` as the same external orchestration API and preserving the existing Plaid route/test behavior.
- Phase 8 completed on June 7, 2026: moved Plaid transaction payload mapping into `plaid_transaction_mapper.py`, moved sync orchestration into `plaid_transaction_sync.py`, kept `PlaidTransactionService` as a compatibility adapter, and added focused tests for idempotent upserts, pending rows, removed rows, and cursor-update failure behavior.
- Phase 9 completed on June 7, 2026: moved `POST /plaid/webhook` into a dedicated webhook route, added a Plaid webhook service for signature and payload validation, rejected malformed or unscoped item events, kept webhook responses secret-free, and continued item-scoped background handling for sync-needed metadata.
