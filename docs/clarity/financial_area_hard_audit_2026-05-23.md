# Financial Area Hard Audit

Date: 2026-05-23

Scope: accounts, transactions, CSV import, categorization, dashboard metrics, filters, monthly transaction review, budgets, category data, and Rex financial context.

## Executive Summary

The financial area is now much better than the first broken state: imports have clearer status, dashboard category grouping is spend-aware, transaction filters use resolved categories, the row list can show more than the first 80 rows, budgets can populate from existing picker categories plus real spending, and Rex now receives a full financial context payload.

The app is now structurally ready for device testing. Transactions flow through a shared resolved read model for the main financial surfaces, roles have DB support and row-level override UI, budgets have stable category IDs/keys, imported statement balances feed dashboard totals, and the app-domain transaction category label is no longer named like a raw UUID.

The remaining work is no longer core correctness. It is product depth: richer category merge/merchant-rule management, audit trails for high-volume role changes, and a retrieval-style Rex context for very large histories.

## Current System Map

- Supabase tables:
  - `accounts`: name, type, balance, currency, active state.
  - `categories`: user category UUID, display name, normalized name, type.
  - `transactions`: account UUID, category UUID, absolute amount, `type` of `income` or `expense`, date, description, CSV import metadata.
  - `budgets`: category key, display name, amount, period, start date.
- App domain:
  - `Transaction` uses a signed amount and optional `categoryLabel`, which is the app-facing resolved category name.
  - `ResolvedTransaction` computes display category, financial role, `countsAsSpend`, `countsAsIncome`, and review state.
  - Dashboard, budgets, monthly detail, and Rex all consume these concepts through different pathways.

## What Is Working

- CSV import has batching, duplicate detection, fallback categorization, progress state, and import batch delete support.
- Categories are persisted in Supabase and normalized to avoid duplicate names.
- Manual category edits can update one transaction or explicitly apply to similar merchants.
- Dashboard transaction categories now exclude unresolved/income/ignored groups from spend-category mode.
- The dashboard transaction row list has a `Show more` flow instead of silently stopping at 80 rows.
- Budget rows are activity-driven and can include built-in categories, existing custom categories, spend categories, and saved budget categories.
- Rex receives accounts, categories, budgets, transactions, raw category IDs, and resolved category names.
- Budgets now store and match by stable `category_key`, with `name` kept as display text.

## Implementation Log

- P0 started/completed: DB-to-domain transaction mappers no longer stamp `financialRole` from raw `transactions.type`; loaded rows now allow `effectiveFinancialRole` to derive ignored, refund, transfer, and confirmed credit-card-payment semantics.
- P0 regression coverage added: transaction resolution tests now prove ignored rows, refund rows, transfer rows, and confirmed credit-card payments do not count as spend/income incorrectly after reload-style mapping.
- P0 schema support added: `transactions.financial_role` migration and nullable app model plumbing are in place for explicit future role overrides without treating raw `type` as semantic truth.
- P1 started: introduced a shared `FinancialReadModelService` that fetches accounts, transactions, and budgets once, resolves transaction/category/role semantics once, and feeds dashboard snapshots, budget spent maps, budget performance, refreshed month lines, and Rex financial context.
- P1 budget performance upgraded: `BudgetPerformanceSnapshot` now reports on-track categories and top overspending categories from the shared resolved spending view instead of returning placeholders.
- P1 budget identity completed: budgets now have `category_key` schema support, app record/service plumbing, stable category-key matching in budget editing, shared-read-model budget performance by key, Rex budget context support, and regression coverage for renamed budget display labels.
- P2 started: month detail no longer exposes an account-wide "clear all transactions" action from a monthly review screen. The action is now month-scoped, labels the affected month, and deletes only transactions for that account/date range.
- P2 stale-load hardening started: dashboard summary, dashboard transaction section, budgets screen, and month detail now ignore stale async load completions when a newer load has already started.
- P2 import preview started: account selection now previews parsed CSV row count, new rows, duplicates, date range, spending/income row counts, ending balance, and inferred-layout warnings before any transactions are written.
- Refactor Phase 1 category contract completed: app-domain `Transaction.categoryId` was renamed to `Transaction.categoryLabel`, while `TransactionRecord.categoryId` remains the raw Supabase UUID. Persisted-record coverage now proves ignored, refund, transfer, confirmed credit-card-payment, and income rows resolve correctly through DB mapping.
- Refactor Phase 1 role override plan added in `docs/clarity/transaction_role_override_plan.md`; schema and app plumbing are already present through `transactions.financial_role`, with UI/review flow remaining.
- Refactor Phase 1 manual role override UI added: dashboard and month-detail transaction rows now expose an `Auto role` chip/menu for persisting `expense`, `income`, `transfer`, `credit_card_payment`, `refund`, or `adjustment` into `transactions.financial_role`.
- Refactor Phase 2 continued: dashboard transaction list data now loads scoped transactions, all transactions, and accounts from one `FinancialReadModel`; dashboard refresh recomputation now uses `FinancialReadModelService` instead of owning a separate account/transaction mapper; budget screen read paths now fetch budgets through the read model.
- Refactor Phase 2 mapper consolidation completed: financial read model, CSV import duplicate checks, transaction workflows, category workflows, and app UI streams now use one shared `transactionFromRecord` mapper, removing duplicated DB-to-domain transaction conversion paths in app orchestration code.
- Refactor Phase 2 completed: `FinancialReadModelService` now loads accounts, transactions, budgets, categories, and merchant category rules together; Rex uses model-owned categories instead of a separate category fetch; resolved dashboard, budget, month detail, and transaction views apply the same merchant-aware category memory.
- Refactor Phase 3 started/completed: budgets now support stable `category_id` identity in addition to fallback `category_key`; budget drafts carry category id/key/display label explicitly; budget performance and budget screen spending lookups prefer category IDs so category display renames do not strand existing budgets.
- Refactor Phase 4 started/completed: CSV imports now persist statement-import metadata with ending balance/date range; the financial read model uses latest statement balances for dashboard totals, treats positive credit-card balances as liabilities, exposes an internal-payment review queue for unconfirmed credit-card payment rows, and passes statement/review context to Rex.
- Refactor Phase 4 hardening completed: statement imports now enforce same-user account ownership, duplicate-only imports no longer persist orphan balance metadata, latest import selection has deterministic tie-breaks, and dashboard balance no longer falls back to summing transaction history.

## Critical Findings

### P0 - Fetched transactions can bypass smart financial role logic

Evidence:
- `apps/mobile/lib/core/models/transaction.dart:45` says `financialRole` is optional and should allow derived role logic when null.
- `apps/mobile/lib/features/transactions/domain/financial_role.dart:24-25` returns `t.financialRole` immediately when it is not null.
- Multiple DB-to-domain mappers set `financialRole` from raw transaction `type`, including `apps/mobile/lib/app/ui_dependencies.dart:592-607`, `apps/mobile/lib/app/dashboard_refresh_coordinator.dart:117-132`, `apps/mobile/lib/features/transactions/application/transaction_workflow_service.dart:186-201`, and `apps/mobile/lib/features/transactions/data/csv_import_service.dart:753-755`.

Why this matters:
- Once transactions are loaded from Supabase, an expense row is already stamped as `FinancialRole.expense`.
- The resolver may never reach the logic for ignored rows, refunds, transfers, or confirmed credit card payments.
- This can make dashboard spend, budget spent, Rex summaries, and account views count internal payments or ignored/refund rows incorrectly.

Required fix:
- Stop setting `financialRole` from `TransactionRecord.type` in read mappers.
- Treat DB `type` as signed direction only, not final semantic role.
- Add tests proving that fetched persisted rows categorized as `Credit Card Payment`, `Ignored`, refund, and `Transfer Out` produce the expected `countsAsSpend` / `countsAsIncome`.

### P0 - Transaction role is not represented in the database

Evidence:
- `supabase/migrations/000005_create_transactions_table.sql:5-7` stores `category_id`, `amount`, and `type`, but no semantic role.
- The app needs roles beyond `income` and `expense`: `transfer`, `creditCardPayment`, `refund`, and `adjustment`.

Why this matters:
- The current system must infer roles every time.
- Inference is good for first-pass automation, but users eventually need manual correction.
- Without a persisted role override, a transaction can be categorized correctly but still counted incorrectly.

Required fix:
- Add a `financial_role` column or a separate transaction classification table.
- Keep `type` as direction (`income` / `expense`) and `financial_role` as meaning (`expense`, `income`, `transfer`, `credit_card_payment`, `refund`, `adjustment`).
- Let the resolver use: manual role override, then category/system rules, then matchers, then sign fallback.

### P1 - There is no single financial read model

Status: mostly fixed for the current app surfaces. The shared `FinancialReadModelService` is now the source for dashboard snapshots, dashboard transaction list data, budget spent maps, budget performance, budget screen reads, refreshed month lines, dashboard refresh recomputation, and Rex financial context.

Evidence:
- `DashboardUiController.buildSnapshot` fetches accounts, all transactions, and scoped transactions separately in `apps/mobile/lib/app/ui_dependencies.dart:173-187`.
- Dashboard transaction section fetches scoped transactions, optionally all transactions, and accounts again in `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:613-624`.
- Budgets fetch all transactions, transactions by account, and accounts again in `apps/mobile/lib/app/ui_dependencies.dart:531-549`.
- Rex fetches dashboard snapshot, budget performance, accounts, categories, budgets, raw transactions, and resolved transactions separately in `apps/mobile/lib/rex/data/financial_context_service.dart:23-31`.

User impact:
- Same screen can be assembled from slightly different data snapshots.
- Performance will degrade as transaction history grows.
- Bugs are harder to fix because there is no single place to inspect "what the app believes financially."

Required fix:
- Create `FinancialReadModelService` or `FinancialSnapshotRepository`.
- It should fetch accounts, categories, merchant rules, budgets, and transactions once, then expose immutable resolved views:
  - `List<ResolvedTransaction>`
  - account-scoped transaction views
  - period-scoped summaries
  - spending by category
  - budget performance
  - Rex context payload source

### P1 - `Transaction.categoryId` is still a misleading domain field

Status: fixed in Refactor Phase 1. The app model now uses `Transaction.categoryLabel`; raw UUIDs remain isolated to `TransactionRecord.categoryId`.

Evidence:
- Historical issue: `apps/mobile/lib/core/models/transaction.dart` described `categoryId` as a canonical user-chosen spend category, not a Supabase UUID.
- Supabase `TransactionRecord.categoryId` is a real category UUID at `apps/mobile/lib/core/supabase/supabase_records.dart:148-170`.
- Current state: app mappers translate UUIDs into category names before placing them into `Transaction.categoryLabel`.

User impact before fix:
- The name invites future bugs: one layer can pass a UUID and another layer can expect a label.
- This was already a source of the "Unknown categories" behavior.

Completed fix:
- App model fields are now split:
  - `TransactionRecord.categoryId`: raw Supabase UUID.
  - `Transaction.categoryLabel`: app-facing canonical/display label.
- Do not pass raw UUIDs into `spendGroupLabel`.

### P1 - Budgets are keyed by mutable display names

Status: fixed in the P1 implementation. The historical risk remains documented here because existing data needs the `000012_add_budget_category_key.sql` migration applied wherever the app is deployed.

Evidence:
- `supabase/migrations/000004_create_budgets_table.sql:4` stores budget `name`, not category UUID or normalized category key.
- `BudgetWorkflowService.commitBudgetDraft` matches existing budgets by lowercased name, period, and start date in `apps/mobile/lib/features/budgets/application/budget_workflow_service.dart:28-37`.
- `BudgetsViewModel._budgetForDisplayLabel` finds budget amounts by lowercased display label in `apps/mobile/lib/features/budgets/presentation/budgets_viewmodel.dart:461-469`.

User impact:
- Renaming a category can orphan or duplicate budgets.
- Two visually different labels that normalize the same way can collide.
- Budgets cannot cleanly distinguish category identity from presentation text.

Required fix:
- Add `category_id` or `category_key` to budgets.
- Keep `name` as display snapshot only.
- Migrate existing budgets by matching normalized names to category records.

### P1 - Budget performance is incomplete

Status: fixed in the P1 implementation. Budget performance now uses resolved spend, reports on-track category count, and returns top overspending categories.

Evidence:
- `BudgetUiController.budgetPerformanceForScope` returns `onTrackCategoryCount: 0` and `topOverspendingCategories: const []` in `apps/mobile/lib/app/ui_dependencies.dart:516-528`.
- `BudgetCategoryPerformance` already models per-category budget/spent/remaining in `apps/mobile/lib/features/budgets/domain/budget_models.dart:1-15`, but the controller does not populate it.

User impact:
- Dashboard budget cards can show totals but not the actionable categories causing the issue.
- Rex can say budget status, but not reliably explain which budget categories are over.

Required fix:
- Build per-category performance from budget records joined to resolved spend by category.
- Populate:
  - `onTrackCategoryCount`
  - `topOverspendingCategories`
  - categories with budget but no spend
  - spend categories with no budget

### P1 - Account balances are not reconciled with imports

Evidence:
- Account `balance` is stored in `supabase/migrations/000002_create_accounts_table.sql:6`.
- `resolveTotalBalance` falls back to sum of signed transactions when no statement balance is passed in `apps/mobile/lib/features/dashboard/domain/balance_resolve.dart:3-12`.
- `buildDashboardSnapshot` global balance uses `resolveTotalBalance(scopedTransactions, scopedBalanceFromStatement)` in `apps/mobile/lib/features/dashboard/domain/dashboard_snapshot.dart:137-143`, but `DashboardUiController.buildSnapshot` passes `scopedBalanceFromStatement: null` in `apps/mobile/lib/app/ui_dependencies.dart:177-187`.

User impact:
- A dashboard balance may be transaction net, not true account balance.
- A per-account card can show stored account balance, while global dashboard derives a different number.
- Runway can be wrong because it depends on total balance.

Required fix:
- Make balance source explicit:
  - manual account balance,
  - imported statement ending balance,
  - computed transaction net.
- On CSV import, capture/latest statement ending balance per account when available.
- Global balance should be sum of account balances with clear inclusion rules for credit cards.

### P1 - Credit card payment matching is conservative but invisible

Evidence:
- `effectiveFinancialRole` only marks a credit card payment as such when `findConfirmedCreditCardPaymentMatch` finds an opposite-side row in `apps/mobile/lib/features/transactions/domain/financial_role.dart:40-50`.
- The matcher requires a non-credit-card source outflow, a credit-card target inflow, same amount, and max 3-day date delta in `apps/mobile/lib/features/transactions/domain/internal_payment_matcher.dart:44-89`.

User impact:
- If only the checking account is imported, the payment remains spend.
- If the credit card import has slightly different date/amount/description, the payment remains spend.
- The app gives no "unmatched payment" review queue.

Required fix:
- Add a `Needs review: possible internal payment` state.
- Show unmatched payment rows separately.
- Allow manual role override to `Credit card payment`.

### P1 - Rex financial context is rich but too raw

Status: partially fixed. Rex now gets data from the shared financial read model, but the payload still includes broad transaction detail and needs a compact retrieval strategy before this is considered finished.

Evidence:
- `AssistantFinancialContextService.buildSummary` includes every transaction in `apps/mobile/lib/rex/data/financial_context_service.dart:107-115`.
- The transaction context includes raw description, account names, category IDs, category names, amounts, import IDs, timestamps in `apps/mobile/lib/rex/data/financial_context_service.dart:232-267`.

User impact:
- Rex has access now, but the payload can become large and expensive.
- If role/category logic is wrong upstream, Rex will explain wrong conclusions confidently.
- There is no clear split between "full raw ledger" and "summary facts Rex should reason from."

Required fix:
- Feed Rex from the same financial read model.
- Include a compact summary plus recent/high-signal rows by default.
- Add a separate retrieval path for drilling into specific months/categories/accounts.

### P2 - CSV import lacks a preview and repair flow

Status: partially fixed. Import preview is now in place before writes. The remaining repair/retry screen for unresolved/category-update failures is still open.

Evidence:
- `CsvImportService.importAndCategorize` parses, inserts, categorizes, and applies categories in one stream in `apps/mobile/lib/features/transactions/data/csv_import_service.dart:230-447`.
- Duplicate detection uses account/date/amount/description fingerprint in `apps/mobile/lib/features/transactions/domain/transaction_fingerprint.dart:7-17`.

User impact:
- Users cannot see what will be imported before rows are saved.
- Duplicate detection is practical but not auditable in UI.
- If category assignment partially fails, the app can report the issue but has no retry UI.

Required fix:
- Add import preview:
  - detected date range,
  - row count,
  - duplicate count,
  - unknown count estimate,
  - ending balance if present,
  - bank/profile mapping.
- Add retry actions for unresolved/category-update failures.

### P2 - Category management is hidden inside transaction row chips

Evidence:
- Category rename/delete/create live inside `TransactionCategoryField` overlay in `apps/mobile/lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart:24-103` and `:275-304`.
- `CategoryReadModel.categoriesHiddenFromPicker` and display renames are placeholders returning empty data in `apps/mobile/lib/features/categories/application/category_read_model.dart:46-48`.

User impact:
- Users can create/rename/delete categories from a small transaction dropdown, but there is no dedicated category settings screen.
- No way to review merchant rules, aliases, hidden categories, or system categories.

Required fix:
- Add a real category management page:
  - category list by type,
  - rename/delete/merge,
  - merchant rules review,
  - hidden/system category controls,
  - count of assigned transactions and budgets affected.

### P2 - Destructive actions are too broad in monthly detail

Status: fixed in the P2 implementation. Month detail now deletes only the visible account/month range instead of all transactions for the account.

Evidence:
- Month detail shows `Clear all transactions` for an account and deletes every transaction for that account, not just the visible month, in `apps/mobile/lib/features/dashboard/presentation/month_detail_screen.dart:104-145`.

User impact:
- A user reviewing one month could delete the whole account history.

Required fix:
- Rename the action to `Delete all account transactions` if keeping it.
- Prefer month-scoped delete, import-batch delete, and account delete as separate actions.
- Require typing the account name for full account transaction deletion.

### P2 - Dashboard and budget loading are prone to stale async updates

Status: mostly fixed for the audited screens. Dashboard summary, dashboard transaction section, budgets screen, and month detail now use request generation guards so older loads cannot overwrite newer results.

Evidence:
- `FinancialDashboardView._loadData` starts async work on every controller notification in `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:192-212`.
- Transaction section `_load` does the same in `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:613-638`.
- Budgets screen `_loadData` also performs multi-step async state updates in `apps/mobile/lib/features/budgets/presentation/budgets_screen.dart:150-171`.

User impact:
- Fast imports, category edits, navigation, or repeated refreshes can allow older requests to finish after newer requests.
- The UI can briefly show stale numbers.

Required fix:
- Use request sequence tokens or cancellable operations.
- Move orchestration into a read model provider/controller with one load lifecycle.

## Refactor Plan

### Phase 1 - Fix correctness contracts

- Remove automatic `financialRole` stamping from DB read mappers.
- Add tests for persisted rows with `Credit Card Payment`, `Ignored`, refunds, transfers, and income categories.
- Rename app-facing category fields so raw UUID and display label cannot be confused.
- Add a role override plan/migration.

### Phase 2 - Create the financial read model

Status: completed for the current financial surfaces. Dedicated transaction review can build on the same read model when that screen is expanded.

- Add `FinancialReadModelService`.
- It fetches accounts, categories, merchant rules, budgets, and transactions once.
- It returns immutable resolved views for dashboard, budgets, Rex, account pages, and transaction review.
- Replace duplicate fetch/resolve logic in `DashboardUiController`, budget controller, dashboard transaction section, and Rex context.

### Phase 3 - Make budgets category-safe

Status: completed for current budget creation, editing, read-model performance, and rename-safe matching. Existing rows without a matching category can still fall back to `category_key`.

- Add `category_id` or stable `category_key` to budgets.
- Migrate existing budget `name` rows.
- Populate full `BudgetPerformanceSnapshot`.
- Add tests for category rename preserving budgets.

### Phase 4 - Reconcile account balance and transfers

Status: completed for imported statement balances, explicit dashboard balance rules, credit-card liability normalization, and an internal-payment review queue. A fuller review UI can surface the queue in Phase 5.

- Store latest imported statement balance per account/import.
- Make global balance rules explicit, especially for credit cards.
- Add possible internal-payment review queue.
- Add manual role override UI.

### Phase 5 - Upgrade finance UX

Status: completed for the current financial UX pass. The dashboard transaction
section has a Review mode backed by domain review reasons, role filtering, and
queues for unresolved categories, unconfirmed internal payments, and manual role
overrides. Import warnings now route back to the dashboard review queue, duplicate
CSV previews explain the repair path, and failed/unknown category assignment can
be retried for the affected import batch. Budgets exposes category management
with custom category edits plus transaction, budget, and merchant-rule usage
counts. The dashboard is also grouped into cash flow, spending, budget, account
health, and transaction review sections.

- Add import preview and import repair/retry screen: completed as preview plus retryable batch repair banner/action.
- Add category management page: completed for budget-facing category management; merge and merchant-rule editing can be a later advanced settings pass.
- Add transaction review screen with virtualized rows, saved filters, role filters, and unresolved queue: completed inline in dashboard with role/review filters and `Show more`; saved filter presets remain optional.
- Split dashboard into cash flow, spending, budget, and account health sections: completed.

## Testing Gaps

- Unit tests for persisted transaction role resolution after DB mapping.
- Integration test: CSV import -> dashboard spend -> budget performance -> Rex context.
- Budget tests for rename/delete/merge category behavior.
- Account balance tests for checking, savings, credit card, and mixed-account global dashboard.
- Import preview/dedupe tests with repeated CSV files and slightly changed descriptions.
- Widget tests for dashboard filters, month picker, category mode, and show-more behavior.
- Rex context size/shape tests for large transaction histories.

## Real Readiness

Ready for device testing:
- Basic import flow.
- Category assignment.
- Dashboard category filters.
- Budget category visibility.
- Rex access to financial records.

Remaining product-depth work:
- Category merge and merchant-rule management UI.
- Rex retrieval/drill-down path for very large histories beyond the compact default context.
- Optional audit trail for high-volume role/category automation.

The next best engineering move after device testing is to add widget/integration coverage around the new review, retry, and category-management flows.
