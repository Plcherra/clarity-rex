# Finance And Plaid Completion Plan

## Goal

Make Clarity finance reliable enough that Dashboard, Accounts, Budgets, Transactions, CSV import, Plaid, and Rex finance answers all use the same trusted data.

## Current State

- Mobile reads and writes finance records directly through Supabase.
- Plaid link, token exchange, sync, disconnect, and webhook handling live in Rex API.
- CSV import writes Supabase records and can use Supabase Edge Functions for AI categorization.
- Rex finance context is currently assembled on mobile and sent to Rex only on finance-related turns.
- Rex action cards can mutate finance data through `/clarity/actions`.

## Work Plan

### 1. Finance Source Of Truth Audit

- Completed: `docs/FINANCE_SOURCE_OF_TRUTH.md` now records the current finance
  source-of-truth map.
- Canonical finance tables:
  - `accounts`
  - `transactions`
  - `categories`
  - `budgets`
  - `merchant_category_rules`
  - `account_statement_imports`
  - Plaid-derived tables
- Confirmed: Dashboard, Budgets, Accounts, transaction review, and Rex financial
  context all use the shared mobile financial read model built from Supabase
  finance records.

### 2. Rex Finance Context Hardening

- Confirmed: mobile gates financial context by finance intent before sending it.
- Confirmed: mobile sends unavailable/degraded summaries when finance data cannot load.
- Confirmed: backend rejects unreliable financial context for finance turns.
- Completed: Dashboard now shows a degraded-data banner when part of the
  financial read model fails to load.
- Consider a backend-side finance context endpoint only if client-supplied context proves too fragile.

### 3. Dual Mutation Path Review

Mobile UI and Rex actions both mutate finance tables. Align them:

- Shared validation rules for account, transaction, budget, and category writes.
- Documented: native UI writes are the primary direct-edit path; Rex action
  writes are a confirmed second path through `/clarity/actions`.
- Confirmed: mobile refreshes shared finance UI state after Rex-applied actions
  through `notifyDataChanged()`.
- Confirmed: Rex action cards require user confirmation before execution.
- Future hardening: expand shared audit logging through `financial_audit_events`
  where useful.

### 4. Plaid Reliability

- Confirmed: Plaid env readiness is visible in `/ready` through backend
  `get_plaid_config_status()`.
- Completed: Accounts UI now gives recovery guidance for syncing, degraded, and disconnected Plaid states.
- Completed: login-required and pending-expiration Plaid states now map to specific mobile statuses and messages.
- User-facing messaging is now covered for:
  - Login required.
  - Degraded sync.
  - Disconnected item.
  - Pending expiration.
  - Webhook delay.
- Confirmed: manual sync and disconnect paths are visible on connected account cards.
- Confirmed: mobile only handles Plaid link/public-token exchange calls; Plaid
  client secrets and access tokens stay backend-owned.

### 5. CSV Import Finish

- Completed: account-scoped CSV fallback is the canonical import path.
- Completed: duplicate standalone upload screen was removed in Plan 01.
- Confirmed: CSV/manual import is positioned as fallback to Plaid, not the primary path.
- Runtime smoke still needed: file pick, account selection/preview, import progress, AI categorization, merchant rules, budget refresh.

### 6. Budgets And Categories

- Confirmed at architecture level: Budgets use the shared financial read model
  and category read model.
- Existing UI exposes category management errors and retry states.
- Runtime smoke still needed for category correction, merchant rules, and budget refresh.

## Completion Status

Plan 02 is code-complete for the current static implementation pass.

Remaining work is runtime validation:

- Production Plaid connect/sync/degraded recovery.
- CSV import from file pick to dashboard/budget refresh.
- Category correction and merchant rule propagation.
- Rex finance question using visible app data.

## Final Static Review

- Shared finance read path is documented in `docs/FINANCE_SOURCE_OF_TRUTH.md`.
- Dashboard, Budgets, Accounts, transaction review, and Rex financial context use
  the same mobile financial read model.
- Mobile gates financial context by finance intent before sending Rex payloads.
- Backend rejects unreliable finance context for finance turns.
- Dashboard shows a degraded-data banner when part of the read model fails.
- Plaid recovery UI covers syncing, degraded, login-required, pending-expiration,
  disconnected, and stale webhook states.
- Plaid secrets are not present in mobile code.

## Acceptance Criteria

- Dashboard numbers, budget numbers, and Rex finance answers agree for the same data set.
- Plaid tokens and secrets never enter mobile code.
- CSV import can complete from file pick to dashboard refresh.
- Rex never claims a finance mutation succeeded unless backend confirms it.
- User can recover from Plaid degraded states.

## Suggested Tests

- Flutter:
  - `financial_read_model_service_test`
  - `csv_import_service_test`
  - Plaid link/service tests
  - budget workflow tests
- Backend:
  - Plaid route and sync tests
  - clarity action parser/control tests
  - chat financial guard tests

## Manual Smoke

1. Connect a production Plaid bank.
2. Confirm accounts appear.
3. Sync transactions.
4. Import CSV fallback into a manual account.
5. Correct a category.
6. Confirm Dashboard and Budgets refresh.
7. Ask Rex a finance question.
8. Confirm Rex answer uses visible app data only.
