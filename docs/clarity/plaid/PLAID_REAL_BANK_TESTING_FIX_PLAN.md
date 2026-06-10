# Plaid Real Bank Testing Fix Plan

Status: In Progress

Last updated: June 9, 2026

## Purpose

Fix the remaining issues blocking real Plaid bank testing. Plaid can now reach
Bank of America and show a successful handoff, but Clarity is not yet saving the
connected accounts because the mobile app is not reliably reaching
`/plaid/exchange-token`.

## Core Outcome

By the end of this plan:

- A real Bank of America connection creates a Plaid item in Clarity.
- Connected checking and credit accounts appear in Dashboard and Accounts.
- Initial transaction sync runs or clearly shows a recoverable sync state.
- Budgets and categories reflect Plaid transactions without ghost-data noise.
- Assistant answers from the same Plaid-backed Clarity data shown in the app.

## Non-Goals

- Do not remove CSV fallback.
- Do not redesign the full financial UI.
- Do not add Plaid products beyond the currently approved workflow unless
  explicitly required.
- Do not store Plaid secrets or access tokens in Flutter.

## Current Blocking Evidence

- Plaid dashboard shows `HANDOFF - onSuccess`.
- VPS logs show `POST /plaid/link-token`.
- VPS logs do not show `POST /plaid/exchange-token` after the successful handoff.
- The app returns to the empty Dashboard/Accounts state after Plaid success.

## Phase 1 - Mobile Plaid Success Callback Reliability

Status: Complete

Goal: Ensure real Plaid handoff produces a `PlaidLinkLaunchSuccess` and sends the
`public_token` to the backend.

Files to change:

- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
- `apps/mobile/ios/Runner/Info.plist`
- `apps/mobile/ios/Runner/SceneDelegate.swift`
- `apps/mobile/ios/Runner/Runner.entitlements`
- `apps/mobile/test/plaid_link_service_test.dart`

Steps:

1. Keep Plaid success, exit, event, and OAuth redirect listeners alive through
   the full OAuth return flow.
2. Do not complete the flow as an exit while an OAuth handoff is still pending.
3. Increase or replace the short exit grace timer with explicit handoff-aware
   state.
4. Log sanitized callback transitions: Link open, OAuth redirect received,
   resume attempted, success received, public token present, exchange started.
5. Confirm the iOS associated domain and redirect URI match
   `app.goclarity.clarity` and `https://api.goclarity.app/plaid/oauth`.

Done looks like:

- After Bank of America handoff, mobile logs show success with
  `public_token_present=true`.
- VPS logs show `POST /plaid/exchange-token`.
- The app no longer returns to empty state before token exchange.

Completion note:

- Added handoff-aware Plaid Link state so OAuth exits do not complete the flow
  before Link success has a chance to arrive.
- Added app-resume OAuth recovery using the latest incoming link.
- Added sanitized callback and exchange logs without exposing tokens.
- Added a guard/test for Link success callbacks that do not include a public
  token.
- Verification passed: `flutter analyze` and
  `flutter test test/plaid_link_service_test.dart`.

## Phase 2 - Public Token Exchange And Initial Sync Resilience

Status: Complete

Goal: Make the backend save the Plaid item even if the first sync is delayed or
partially fails.

Files to change:

- `services/rex-api/app/routes/plaid.py`
- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/app/services/plaid_account_service.py`
- `services/rex-api/app/services/plaid_transaction_sync.py`
- `services/rex-api/tests/test_plaid_exchange_route.py`
- `services/rex-api/tests/test_plaid_sync_service.py`

Steps:

1. Keep the public token exchange fully authenticated.
2. Persist the Plaid item and encrypted access token before initial sync.
3. Return a successful connection state if the item is saved but sync is pending
   or degraded.
4. Keep access tokens, account numbers, and raw Plaid responses out of logs and
   responses.
5. Add tests for exchange success, sync success, sync degraded, and safe error
   responses.

Done looks like:

- A successful Link handoff creates a durable Plaid item.
- Initial sync failure does not make the user reconnect from scratch.
- The app can show `Connected`, `Syncing`, or `Degraded` instead of empty state.

Completion note:

- Updated `/plaid/exchange-token` so public token exchange and Plaid item/token
  persistence remain the source of truth for a successful connection.
- Initial sync errors now return a safe degraded connection response
  instead of failing the exchange and forcing the user to reconnect.
- Added item status marking for degraded first-sync failures without touching
  encrypted access token storage.
- Verification passed:
  `pytest -q tests/test_plaid_exchange_route.py tests/test_plaid_sync_service.py`.

## Phase 3 - Connected Account Persistence Verification

Status: Complete

Goal: Prove that multiple Plaid accounts from one institution appear as separate
Clarity accounts.

Files to change:

- `services/rex-api/app/services/plaid_account_service.py`
- `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`
- `apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_tile.dart`
- `apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`
- Relevant backend and Flutter tests

Steps:

1. Verify Plaid account rows include institution, account name, mask, subtype,
   balances, Plaid item id, and sync timestamp.
2. Verify Clarity account rows are created/updated for each Plaid account.
3. Verify Accounts screen renders multiple Plaid accounts cleanly.
4. Verify manual accounts and Plaid accounts can coexist.

Done looks like:

- Bank of America checking and credit accounts both appear on Accounts.
- Each account has a clear source label, mask, balance, status, and last synced
  timestamp when available.

Completion note:

- Added a Plaid account institution snapshot so each synced Plaid account can
  render the correct bank name without guessing from the account name.
- Passed Plaid item `institution_name` into account sync so Clarity account rows
  are created/updated with institution, source, Plaid item id, Plaid account id,
  balance, sync status, and last synced timestamp.
- Updated mobile account reads so both one-shot fetches and realtime account
  streams merge Plaid metadata before rendering.
- Normalized degraded initial sync status to the database-supported `degraded`
  value.
- Verification passed: Plaid backend tests, Plaid mobile tests, and
  `flutter analyze`.

## Phase 4 - Dashboard And Transactions Alignment

Status: Complete

Goal: Confirm Dashboard, cash flow, balances, insights, and transaction lists use
Plaid-backed data correctly.

Files to change:

- `apps/mobile/lib/features/finance/application/financial_read_model.dart`
- `apps/mobile/lib/features/dashboard/presentation/*`
- `apps/mobile/lib/features/accounts/presentation/widgets/accounts_body.dart`
- `apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_tile.dart`
- `apps/mobile/lib/features/transactions/presentation/*`

Steps:

1. Verify Dashboard totals include all Plaid accounts.
2. Verify transactions are grouped by account.
3. Verify income and spending use Plaid transaction signs correctly.
4. Verify pending transactions are visible or safely excluded according to the
   current UX rule.
5. Add tests for multiple-account dashboard totals.

Done looks like:

- Dashboard no longer shows "Connect your first bank" after a successful
  connection.
- Cash flow, income, spending, and account count reflect Plaid data.
- Account detail tiles show recent synced transactions.

Completion note:

- Updated the Dashboard empty-state rule so a connected Plaid account is enough
  to leave setup mode while first transaction sync catches up.
- Added pending transaction support to the mobile transaction/read-model layer:
  pending rows can appear in recent transaction lists with a quiet label, but
  they are excluded from settled cash flow, spending, budget, leak, and category
  rollups.
- Added focused tests for connected-account empty state and multiple Plaid
  account totals with pending transactions.
- Verification passed: focused Plaid/dashboard tests and `flutter analyze`.

## Phase 5 - Budget Category Noise And Plaid Categorization

Status: Complete

Goal: Prevent old categories and no-budget rows from making Plaid testing look
broken.

Files to change:

- `apps/mobile/lib/features/budgets/application/budget_cleanup_service.dart`
- `apps/mobile/lib/features/budgets/presentation/*`
- `services/rex-api/app/services/plaid_category_mapper.py`
- `apps/mobile/test/budget_cleanup_service_test.dart`

Steps:

1. Keep orphan budget deletion logic.
2. Do not auto-delete built-in/default categories without an explicit user
   action.
3. Hide inactive categories that have no budget and no active transactions from
   the main Budgets list.
4. Keep custom category deletion behind a confirmation dialog.
5. Verify Plaid category mapping reuses normalized categories instead of creating
   unnecessary duplicates.

Done looks like:

- Budgets screen is clean before Plaid testing.
- Old CSV category rows do not look like active budgets.
- Plaid transactions still map to usable Clarity categories.

Completion note:

- Budget rows now carry both category id and normalized category-key identities
  so Plaid/CSV spend and saved budgets reconcile into the same row.
- The main Budgets list hides inactive rows with no budget and no active
  transactions, while preserving built-in/default categories for future Plaid
  mapping.
- Custom category deletion remains behind the existing confirmation flow, and
  built-in/hidden categories are not treated as custom deletion candidates.
- Added tests for inactive row hiding, Plaid spend-to-budget identity matching,
  active no-budget spend visibility, cleanup category safety, and Plaid
  normalized category reuse.
- Verification passed: focused mobile Plaid/budget tests, all Plaid backend
  tests, `flutter analyze`, and `git diff --check`.

## Phase 6 - Assistant Plaid Truth Verification

Goal: Confirm Assistant/Rex reads the same Plaid-backed financial data shown in
Clarity.

Files to change:

- `apps/mobile/lib/features/assistant/data/financial_context_service.dart`
- `apps/mobile/lib/features/assistant/chat/data/chat_api.dart`
- `apps/mobile/lib/features/assistant/voice/data/cloud_voice_api.dart`
- `apps/mobile/lib/features/assistant/voice/data/streaming_voice_api.dart`
- Assistant context tests

Steps:

1. Verify the assistant context includes Plaid accounts after connection.
2. Verify transaction summaries include Plaid transactions.
3. Verify budgets use the same category and spend values shown in the Budgets
   screen.
4. Add truth tests for: "What accounts do I have?", "What did I spend this
   month?", and "What does Clarity know about my finances?"

Done looks like:

- If Clarity shows the account, balance, budget, or transaction summary, the
  Assistant does not say it does not know.

Completion note:

- Assistant financial context now filters to active Clarity records and exposes
  Plaid account source, institution, mask, sync, balance, and available-balance
  fields without exposing Plaid secrets.
- Transaction context now includes source, source label, and pending state so
  Assistant can explain Plaid-backed activity with the same posted/pending
  distinction shown in the app.
- Budget context now includes full category performance, not only totals and
  overspending, so Assistant can answer category-level budget/spend questions
  from the same read model as the Budgets screen.
- Added truth tests for "What accounts do I have?", "What did I spend this
  month?", and "What does Clarity know about my finances?" using Plaid-backed
  accounts, transactions, and budgets.

## Phase 7 - Real Device QA Pass

Status: Ready for Pedro physical-device validation

Goal: Validate the full production Plaid lifecycle on a physical iPhone.

Files to change:

- `docs/clarity/plaid/PLAID_MOBILE_REAL_ACCOUNT_QA_REPORT.md`
- `docs/clarity/plaid/PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`

Steps:

1. Build and install a fresh release app.
2. Connect Bank of America with checking and credit accounts.
3. Confirm `/plaid/exchange-token` and sync logs on the VPS.
4. Confirm Dashboard, Accounts, Transactions, Budgets, and Assistant.
5. Confirm manual CSV fallback remains reachable and warns about duplicates.
6. Record latency, issues, and screenshots in the QA report.

Done looks like:

- Real account testing passes end to end.
- Remaining risks are documented.
- `PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md` can be marked complete.

Preflight note:

- Automated Phase 7 readiness passed on June 9, 2026: backend Plaid tests,
  Flutter analyze, focused Plaid/budget/assistant truth tests, and release
  command generation all passed.
- The QA report is updated for a fresh Bank of America retest, but the phase
  remains pending final physical-device confirmation because Codex cannot
  perform private bank login or inspect private financial data.

## Verification Commands

Backend:

```bash
cd services/rex-api
pytest -q tests/test_plaid_*.py
git diff --check
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid*
flutter test test/budget_cleanup_service_test.dart
```

Device release:

```bash
./scripts/mobile_release_run.sh
```

VPS live log:

```bash
sudo journalctl -u clarity-rex -f
```

Expected successful Plaid log sequence:

```text
POST /plaid/link-token
POST /plaid/exchange-token
Plaid public token exchange completed ... accounts=...
```
