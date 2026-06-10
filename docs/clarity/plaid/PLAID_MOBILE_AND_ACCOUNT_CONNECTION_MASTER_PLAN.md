#4 Plaid Mobile And Account Connection

Status: Draft

Last updated: June 6, 2026

## Purpose

Make Connect Bank the primary account setup flow in Clarity while preserving CSV import as a clear fallback.

## Core Outcome

By the end of this plan:

- Users can connect a bank from mobile using Plaid Link.
- Connected institutions, accounts, sync status, resync, and disconnect are visible.
- CSV remains available as "Import CSV instead."
- Plaid and CSV data do not create duplicate account/transaction confusion.

## Non-Goals

- Do not store Plaid secrets in Flutter.
- Do not remove CSV fallback.
- Do not redesign all financial screens; detailed financial UX is covered in the financial experience plan.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Account setup | CSV/manual flows dominate. | App feels primitive. |
| Plaid Link | Native mobile integration not complete. | Users cannot connect banks. |
| Status UI | No complete connected institution lifecycle. | Users cannot trust sync state. |
| CSV fallback | Needs demotion, not deletion. | Import users still need an escape hatch. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Entry points | Connect Bank is primary on Dashboard/Accounts/onboarding. | Modern first impression. |
| Link | Native Plaid Link launches from Flutter. | Reliable mobile connection flow. |
| Status | Connected accounts show sync health and actions. | Trust and control. |
| Fallback | CSV import remains secondary. | Flexibility without product confusion. |

## Phase 1 - Connect Bank Entry Points

Status: Complete

Goal: Make Connect Bank the primary financial data CTA.

Files to change:

- `apps/mobile/lib/features/dashboard/presentation/*`
- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/onboarding/*`

Steps:

1. Add primary Connect Bank CTA on empty Dashboard and Accounts states.
2. Add secondary "Import CSV instead" action.
3. Make copy describe Clarity connected accounts, not Plaid internals.
4. Track sanitized UI usage events.

Done looks like:

- New users see connected bank setup first.

Acceptance criteria:

- [x] Connect Bank is primary.
- [x] CSV import is secondary and still reachable.
- [x] UI copy uses Clarity vocabulary.

Completion note: Dashboard and Accounts empty states now present Connect Bank
as the primary setup path, keep "Import CSV instead" as the fallback, and use
Clarity-first copy. Entry-point taps emit sanitized debug events only; real
Plaid Link launch remains Phase 2.

Verification:

```bash
cd apps/mobile
flutter analyze
```

## Phase 2 - Native Plaid Link Integration

Status: Complete

Goal: Launch Plaid Link from Flutter using native iOS/Android integration.

Files to change:

- `apps/mobile/pubspec.yaml`
- `apps/mobile/ios/Runner/*`
- `apps/mobile/android/app/src/main/*`
- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`

Steps:

1. Add the chosen Plaid Link Flutter/native integration.
2. Request link token from backend.
3. Launch native Link.
4. Return public token and metadata to Flutter.
5. Keep Hosted Link as documented fallback only if native blocks release.

Done looks like:

- Device can open Plaid Link from Clarity.

Acceptance criteria:

- [x] Link launches on iOS.
- [x] Link launch does not require Plaid secrets in mobile.
- [x] Mobile service remains under 300 lines.

Completion note: Added `plaid_flutter` plus `PlaidLinkService`, and wired
Dashboard/Accounts Connect Bank actions to request a backend link token and
open native Plaid Link. Public tokens are held only in memory for Phase 3
exchange. Platform requirements are explicit: iOS minimum target is 14.0,
Android minimum SDK is 21, and both app identifiers are currently
`app.goclarity.clarity` for Plaid dashboard registration. Before device QA, set
`PLAID_IOS_BUNDLE_ID=app.goclarity.clarity` and
`PLAID_ANDROID_PACKAGE_NAME=com.clarity.clarity` on the backend; add
`PLAID_REDIRECT_URI` only when OAuth institutions require it.

Known caveat: `plaid_flutter` currently warns that it does not support Swift
Package Manager for iOS. CocoaPods still works, and this warning is acceptable
for now because using the plugin keeps the mobile integration simpler and
lower-maintenance than owning custom native bridge code.

Verification:

```bash
cd apps/mobile
flutter test test/plaid_link_service_test.dart
flutter analyze
```

## Phase 3 - Link Success And Error Handling

Status: Complete

Goal: Handle Link success, cancellation, and errors clearly.

Files to change:

- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
- `apps/mobile/lib/features/accounts/presentation/*`

Steps:

1. Exchange public token after Link success.
2. Show safe loading, success, cancellation, and failure states.
3. Track sanitized usage status.
4. Never log public token or account details in debug output.

Done looks like:

- Users understand what happened after Link closes.

Acceptance criteria:

- [x] Success exchanges token through backend.
- [x] Cancellation does not create broken records.
- [x] Error UI is clear and non-technical.

Completion note: Plaid Link success now sends the public token to
`POST /plaid/exchange-token`, and the backend route performs the initial
`sync_item` automatically so accounts and transactions begin persisting before
mobile refreshes Dashboard/Accounts state. Mobile keeps Plaid secrets off-device,
never logs the public token, and only surfaces safe connection/sync summaries.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid_link_service_test.dart
cd ../../services/rex-api
./.venv/bin/python -m pytest -q tests/test_plaid_exchange_route.py
```

## Phase 4 - Post-Connection Experience And Error Handling

Status: Complete

Goal: Make Plaid connection completion, cancellation, failures, and manual
refresh clear to the user.

Files to change:

- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
- `apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`
- `apps/mobile/lib/features/shell/presentation/home_shell.dart`
- `apps/mobile/lib/features/accounts/data/account_service.dart`
- `apps/mobile/lib/core/models/account.dart`
- `services/rex-api/app/routes/plaid.py`

Steps:

1. Show clear connection success feedback with institution/account summary.
2. Show user-friendly cancellation, Link failure, exchange failure, and initial
   sync failure messages.
3. Refresh Dashboard and Accounts after a successful connection.
4. Add manual Refresh Accounts action for connected Plaid items.
5. Keep `plaid_flutter` Swift Package Manager warning documented as known and
   acceptable for now.

Done looks like:

- Users know whether connection worked, failed, or was cancelled, and can
  manually refresh connected accounts.

Acceptance criteria:

- [x] Success feedback includes institution/account context.
- [x] Link exit/cancellation does not create broken records.
- [x] Exchange and initial sync failures show safe user-facing messages.
- [x] Manual Refresh Accounts syncs only the current user's Plaid items.
- [x] No Plaid token or sensitive data appears.

Completion note: Connection success now shows "Bank connected successfully"
feedback on Dashboard/Accounts, Accounts keeps a dismissible success notice,
and a Refresh Accounts toolbar action syncs every connected Plaid item visible
to the current user. The backend `/plaid/sync-item/{item_id}` route now verifies
item ownership before syncing, so normal users can refresh their own bank data
without owner/admin access.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid_link_service_test.dart
cd ../../services/rex-api
./.venv/bin/python -m pytest -q tests/test_plaid_*.py
```

## Phase 5 - Account Status And Resync UI

Status: Complete

Goal: Give users visibility and control over sync state.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`
- `apps/mobile/lib/core/models/account.dart`
- `services/rex-api/app/routes/plaid.py`

Steps:

1. Add sync status labels: connected, syncing, degraded, disconnected.
2. Add resync action.
3. Show last successful sync.
4. Handle backend resync errors with user-friendly copy.

Done looks like:

- Users can see and recover connection issues.

Acceptance criteria:

- [x] Resync calls backend route.
- [x] Degraded status is visible but calm.
- [x] Failed resync does not block app usage.

Completion note: Accounts now loads Plaid item status through
`PlaidAccountService`, shows calm status pills for Connected, Syncing,
Degraded, and Disconnected, displays last synced timestamps when available, and
adds per-account Resync actions. Failed status fetches degrade gracefully instead
of blocking the account list. Manual resync still uses the current-user-owned
`/plaid/sync-item/{item_id}` route.

Pre-Phase 6 refactor note: `accounts_screen.dart` was split from 1000+ lines
into a 296-line coordinator plus focused files for the app bar, body, header,
empty state, account notice, manual account tile, Plaid account tile, add-account
dialog, navigation actions, and Plaid status helpers. Behavior and UI were kept
the same so Phase 6 can add features without extending a god file.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid*
cd ../../services/rex-api
./.venv/bin/python -m pytest -q tests/test_plaid_*.py
```

## Phase 6 - Transaction Display And Basic Account Management

Status: Complete

Goal: Show Plaid-connected transactions and basic account visibility.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`
- `apps/mobile/lib/features/accounts/data/account_service.dart`
- `apps/mobile/lib/core/models/account.dart`
- `apps/mobile/lib/app/ui_dependencies.dart`

Steps:

1. Add recent transaction display under Plaid account tiles.
2. Show institution, mask, balances, and last synced when available.
3. Add pull-to-refresh that triggers existing Plaid resync.
4. Keep empty transaction states graceful.

Done looks like:

- Plaid accounts show synced activity without adding categorization, search, or
  a full transaction screen.

Acceptance criteria:

- [x] Plaid tiles show recent synced transactions.
- [x] Plaid tiles show basic account details from synced backend data.
- [x] Pull-to-refresh uses the existing resync flow.
- [x] Empty transaction states do not look broken.

Completion note: Account overview rows now include the latest five transactions
from the shared financial read model. Plaid account tiles render those recent
transactions, account mask, balances, institution/subtitle data, and existing
last-synced status. The Accounts list is wrapped in pull-to-refresh using the
same current-user resync path as the refresh button.

## Phase 7 - CSV Import As Fallback

Status: Complete

Goal: Preserve CSV import as an intentional secondary path.

Files to change:

- `apps/mobile/lib/features/finance/*`
- `apps/mobile/lib/features/accounts/presentation/*`

Steps:

1. Rename CSV entry points to "Import CSV instead."
2. Keep import flow functional.
3. Explain CSV is manual and may require updates.
4. Avoid presenting CSV as the default onboarding path.

Done looks like:

- CSV is available without defining the product.

Acceptance criteria:

- [x] CSV import still works.
- [x] Connect Bank remains primary.
- [x] Copy clearly distinguishes connected vs imported data.

Completion note:

- CSV remains available as "Import CSV instead" and is framed as a manual fallback, not the main product path. The account selection, preview, account detail, onboarding, shell, and dashboard copy now explain that imported CSV data is manual and may need future uploads, while Connect Bank stays primary.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid_link_service_test.dart test/plaid_account_service_test.dart test/plaid_account_tile_test.dart
flutter test test/csv_import_service_test.dart test/csv_parser_test.dart test/import_job_status_service_test.dart
```

Known note:

- `plaid_flutter` still emits the accepted Swift Package Manager warning for iOS. CocoaPods remains the current path.

## Phase 8 - Plaid/CSV Deduplication UI

Status: Complete

Goal: Prevent duplicate confusion when users have both Plaid and CSV data.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/transactions/presentation/*`
- `docs/clarity/finance_import/PLAID_CSV_IMPORT_BOUNDARY.md`

Steps:

1. Surface source labels quietly.
2. Show potential duplicate guidance when importing CSV for a connected account.
3. Keep dedupe decisions aligned with backend contract.
4. Add test cases for mixed data.

Done looks like:

- Users understand data source and duplicate risk.

Acceptance criteria:

- [x] Mixed Plaid/CSV accounts render without duplicate UI noise.
- [x] CSV import warns when a connected account may already cover the same data.
- [x] Dedupe copy is short and clear.

Completion note:

- Account tiles and recent connected-account transaction rows now show quiet `Plaid` or `Manual/CSV` source labels. CSV imports into Plaid-connected accounts show a calm duplicate-risk confirmation, while the import preview gives connected-account-specific guidance. Future CSV writes explicitly persist `source = csv`, and the Plaid/CSV boundary doc now makes source labels and duplicate-warning behavior part of the UI contract.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid*
flutter test test/csv_import_service_test.dart test/csv_parser_test.dart test/import_job_status_service_test.dart
git diff --check
```

Known note:

- `plaid_flutter` still emits the accepted Swift Package Manager warning for iOS. CocoaPods remains the current path.

## Phase 9 - Real Account Device QA And Final Validation

Status: Pending physical-device real-account validation

Goal: Validate full mobile Plaid connection lifecycle on a physical device using
real Plaid production data.

Files to change:

- `docs/clarity/plaid/PLAID_MOBILE_REAL_ACCOUNT_QA_REPORT.md`

Steps:

1. Connect a real bank account through Plaid Link.
2. Verify token exchange and account creation.
3. Verify initial transaction sync.
4. Verify manual resync.
5. Verify connection status display.
6. Verify CSV fallback still works alongside Plaid.

Done looks like:

- Plaid mobile is validated with real data and ready for broader product integration.

Acceptance criteria:

- [ ] Real account connect/sync/resync passes on physical device.
- [ ] CSV fallback passes alongside Plaid data.
- [x] QA report records automated readiness, manual test steps, latency fields, failures, and remaining risks.

Preflight note:

- Automated readiness passed on 2026-06-08. Real account validation cannot be marked complete until Pedro runs the physical-device flow and records results in the QA report.
- Real-bank fix readiness passed on 2026-06-09 after the Plaid OAuth callback,
  exchange resilience, account persistence, dashboard, budget, and Assistant
  truth fixes. The final gate is still Pedro's fresh physical-device production
  connection test with sanitized results recorded in
  `PLAID_MOBILE_REAL_ACCOUNT_QA_REPORT.md`.

## Verification Commands

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test
./scripts/mobile_release_run.sh
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

This plan is complete only when Connect Bank is primary, CSV still works, and sandbox device QA passes.
