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

- [ ] Connect Bank is primary.
- [ ] CSV import is secondary and still reachable.
- [ ] UI copy uses Clarity vocabulary.

## Phase 2 - Native Plaid Link Integration

Goal: Launch Plaid Link from Flutter using native iOS/Android integration.

Files to change:

- `apps/mobile/pubspec.yaml`
- `apps/mobile/ios/Runner/*`
- `apps/mobile/android/app/src/main/*`
- `apps/mobile/lib/features/accounts/data/plaid_link_service.dart`

Steps:

1. Add the chosen Plaid Link Flutter/native integration.
2. Request link token from backend.
3. Launch native Link.
4. Return public token and metadata to Flutter.
5. Keep Hosted Link as documented fallback only if native blocks release.

Done looks like:

- Device can open Plaid Link from Clarity.

Acceptance criteria:

- [ ] Link launches on iOS.
- [ ] Link launch does not require Plaid secrets in mobile.
- [ ] Mobile service remains under 300 lines.

## Phase 3 - Link Success And Error Handling

Goal: Handle Link success, cancellation, and errors clearly.

Files to change:

- `apps/mobile/lib/features/accounts/data/plaid_link_service.dart`
- `apps/mobile/lib/features/accounts/presentation/*`

Steps:

1. Exchange public token after Link success.
2. Show safe loading, success, cancellation, and failure states.
3. Track sanitized usage status.
4. Never log public token or account details in debug output.

Done looks like:

- Users understand what happened after Link closes.

Acceptance criteria:

- [ ] Success exchanges token through backend.
- [ ] Cancellation does not create broken records.
- [ ] Error UI is clear and non-technical.

## Phase 4 - Connected Institution UI

Goal: Show connected banks as institutions with accounts underneath.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`
- `apps/mobile/lib/features/accounts/presentation/widgets/*`
- `apps/mobile/lib/features/accounts/data/account_service.dart`

Steps:

1. Group Plaid accounts by institution.
2. Show institution name, connection status, last sync time, and account count.
3. Show account rows with type/subtype/mask only where useful.
4. Keep manual/CSV accounts in a secondary section.

Done looks like:

- Accounts feels like connected finance, not a CSV ledger.

Acceptance criteria:

- [ ] Institutions render from persisted data.
- [ ] Manual and CSV accounts remain visible.
- [ ] No Plaid token or sensitive data appears.

## Phase 5 - Account Status And Resync UI

Goal: Give users visibility and control over sync state.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`

Steps:

1. Add sync status labels: connected, syncing, degraded, disconnected.
2. Add resync action.
3. Show last successful sync.
4. Handle backend resync errors with user-friendly copy.

Done looks like:

- Users can see and recover connection issues.

Acceptance criteria:

- [ ] Resync calls backend route.
- [ ] Degraded status is visible but calm.
- [ ] Failed resync does not block app usage.

## Phase 6 - Disconnect Flow

Goal: Let users disconnect a bank safely.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`

Steps:

1. Add disconnect action behind confirmation.
2. Explain what remains: historical transactions may remain unless user deletes data.
3. Call backend disconnect route.
4. Refresh account status after disconnect.

Done looks like:

- Users can revoke connection without data confusion.

Acceptance criteria:

- [ ] Disconnect requires confirmation.
- [ ] Disconnect does not delete unrelated CSV/manual history.
- [ ] UI reflects disconnected status.

## Phase 7 - CSV Import As Fallback

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

- [ ] CSV import still works.
- [ ] Connect Bank remains primary.
- [ ] Copy clearly distinguishes connected vs imported data.

## Phase 8 - Plaid/CSV Deduplication UI

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

- [ ] Mixed Plaid/CSV accounts render without duplicate UI noise.
- [ ] CSV import warns when a connected account may already cover the same data.
- [ ] Dedupe copy is short and clear.

## Phase 9 - Sandbox Device QA

Goal: Validate full mobile Plaid connection lifecycle on device.

Files to change:

- `docs/clarity/plaid/PLAID_MOBILE_SANDBOX_QA_REPORT.md`

Steps:

1. Connect sandbox institution.
2. Verify accounts appear.
3. Verify transactions sync.
4. Verify resync.
5. Verify disconnect.
6. Verify CSV fallback still works.

Done looks like:

- Plaid mobile is ready for broader product integration.

Acceptance criteria:

- [ ] Sandbox connect/sync/disconnect passes on device.
- [ ] CSV fallback passes.
- [ ] QA report records latency, failures, and remaining risks.

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
