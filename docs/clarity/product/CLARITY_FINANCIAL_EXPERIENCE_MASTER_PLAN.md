#7 Clarity Financial Experience

Status: Draft

Last updated: June 6, 2026

## Purpose

Modernize Dashboard, Accounts, Transactions, Budgets, and import fallback around Plaid-connected data while keeping CSV as a secondary option.

## Core Outcome

By the end of this plan:

- Financial screens use shared Clarity read models.
- Plaid-connected data feels primary.
- CSV fallback remains available but quiet.
- Empty, loading, error, and degraded states are clear.
- Financial data is isolated per user.

## Non-Goals

- Do not implement Plaid backend or native Link in this plan.
- Do not redesign Assistant chat here.
- Do not remove CSV import.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Dashboard | CSV/manual assumptions still shape the experience. | Product does not feel connected. |
| Accounts | Account setup and status are not institution-centered. | Plaid will feel bolted on. |
| Transactions | Source/sync state is not a core concept. | Plaid/CSV duplicates can confuse users. |
| Budgets | Budget guidance is not tightly connected to synced activity; category rows can differ sharply by selected month. | Assistant and budgets can drift. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Dashboard | Daily clarity from connected financial data. | Fast user understanding. |
| Accounts | Institution/account sync lifecycle. | Trust in data freshness. |
| Transactions | Synced activity with source-aware fallback. | Clear history. |
| Budgets | Actionable guidance from current spending. | Better decisions. |

## Phase 1 - Dashboard Data Contract

Goal: Define the dashboard read model before redesign.

Files to change:

- `docs/clarity/product/CLARITY_SHARED_READ_MODELS.md`
- `apps/mobile/lib/features/dashboard/data/dashboard_service.dart`

Steps:

1. Define required dashboard fields: cash overview, recent activity, budget status, connected account status, sync status, alerts.
2. Define empty and partial-data states.
3. Define freshness expectations.
4. Ensure source does not matter to consumers except where shown.

Done looks like:

- Dashboard reads one stable model.

Acceptance criteria:

- [ ] Dashboard contract exists.
- [ ] Contract supports Plaid and CSV data.
- [ ] Assistant can consume the same dashboard summary.

## Phase 2 - Dashboard Redesign

Goal: Redesign Dashboard around daily financial clarity.

Files to change:

- `apps/mobile/lib/features/dashboard/presentation/*`

Steps:

1. Show the most important daily money state first.
2. Add Connect Bank empty state.
3. Show recent activity and budget pressure clearly.
4. Add contextual Assistant entry.
5. Use app-wide design tokens.

Done looks like:

- Dashboard feels useful within seconds.

Acceptance criteria:

- [ ] Connected-data state is clear.
- [ ] Empty state prioritizes Connect Bank.
- [ ] CSV fallback remains available.

## Phase 3 - Accounts Redesign

Goal: Redesign Accounts around institutions and sync state.

Files to change:

- `apps/mobile/lib/features/accounts/presentation/*`

Steps:

1. Group accounts by institution/source.
2. Show sync health and last sync.
3. Keep manual/CSV accounts secondary.
4. Add actions for connect, resync, disconnect, and CSV fallback.
5. Use a stable account identity hierarchy: title is institution + account type, while product/card/program name and mask sit in supporting detail.

Done looks like:

- Users understand where financial data comes from.

Acceptance criteria:

- [ ] Institution state renders.
- [ ] Source labels are quiet but available.
- [ ] Account actions are clear.
- [ ] Account cards do not rely on truncated Plaid product names as the primary identifier.

## Phase 4 - Transactions Redesign

Goal: Make transactions feel like synced activity.

Files to change:

- `apps/mobile/lib/features/transactions/presentation/*`
- `apps/mobile/lib/features/transactions/data/*`

Steps:

1. Show recent activity with date, merchant, amount, account/source, and category.
2. Add source-aware filters only where useful.
3. Handle pending/removed/degraded states.
4. Keep transaction rows compact.

Done looks like:

- Transaction browsing is calm and clear.

Acceptance criteria:

- [ ] Plaid and CSV transactions render together without confusion.
- [ ] Pending transaction state is supported.
- [ ] Rows do not overflow on mobile.

## Phase 5 - Budgets Redesign

Goal: Make budgets actionable and connected to synced activity.

Files to change:

- `apps/mobile/lib/features/budgets/presentation/*`
- `apps/mobile/lib/features/budgets/data/*`

Steps:

1. Show budget health by category/time period.
2. Highlight meaningful pressure, not noise.
3. Add Assistant explanation/action entry.
4. Use synced transactions as default input.
5. Keep saved budget categories visible across comparable months; show activity-only categories only when they have spend in the selected period.

Done looks like:

- Budgets guide decisions, not just display categories.

Acceptance criteria:

- [ ] Budget state is readable at a glance.
- [ ] Assistant can explain budget state from same data.
- [ ] Empty budget state is useful.
- [ ] A category with a saved budget does not disappear just because the selected month has no spend.
- [ ] A category with no budget and no selected-period spend stays hidden to avoid category-directory noise.

## Phase 6 - Import/CSV Fallback Redesign

Goal: Keep CSV useful without making it primary.

Files to change:

- `apps/mobile/lib/features/finance/*`
- `apps/mobile/lib/features/accounts/presentation/*`

Steps:

1. Present CSV as "Import CSV instead."
2. Explain manual nature and duplicate risk.
3. Keep import status and error states clear.
4. Preserve existing import capabilities.

Done looks like:

- CSV is available but no longer defines the app.

Acceptance criteria:

- [ ] CSV import still works.
- [ ] Copy positions CSV as fallback.
- [ ] Import errors are clear.

## Phase 7 - Empty, Error, And Loading States

Goal: Make all financial states polished and consistent.

Files to change:

- `apps/mobile/lib/features/dashboard/presentation/*`
- `apps/mobile/lib/features/accounts/presentation/*`
- `apps/mobile/lib/features/transactions/presentation/*`
- `apps/mobile/lib/features/budgets/presentation/*`

Steps:

1. Add consistent empty states.
2. Add non-alarming sync/degraded states.
3. Add loading states that do not jump layouts.
4. Add retry/reconnect actions where appropriate.

Done looks like:

- The app feels stable even when data is missing or delayed.

Acceptance criteria:

- [ ] Every primary financial screen has empty/loading/error states.
- [ ] Degraded Plaid state has recovery action.
- [ ] No layout overlap on mobile.

## Phase 8 - Multi-User Data Isolation Tests

Goal: Prove financial data is user-scoped.

Files to change:

- `services/rex-api/tests/test_financial_user_isolation.py`
- `apps/mobile/test/*`

Steps:

1. Test two users with separate accounts.
2. Test two users with separate transactions.
3. Test budgets and Assistant financial summaries do not cross users.
4. Test usage events do not expose other users.

Done looks like:

- Multi-user launch has basic financial isolation coverage.

Acceptance criteria:

- [ ] Backend isolation tests pass.
- [ ] Assistant does not receive other user's financial data.
- [ ] UI service tests use current user scope.

## Phase 9 - Financial UX QA

Goal: Verify the financial experience end to end.

Files to change:

- `docs/clarity/product/CLARITY_FINANCIAL_UX_QA_REPORT.md`

Steps:

1. QA Dashboard, Accounts, Transactions, Budgets, CSV fallback.
2. QA Plaid connected and degraded states.
3. QA small and large iPhone layouts.
4. Record release blockers.

Done looks like:

- Financial product is ready for final validation.

Acceptance criteria:

- [ ] QA report exists.
- [ ] No critical UX blocker remains.
- [ ] Flutter analyze/tests pass.

## Verification Commands

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test
cd services/rex-api && pytest tests/test_financial_user_isolation.py
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

This plan is complete only when financial screens are Plaid-first, CSV-compatible, user-scoped, and visually aligned with Clarity.
