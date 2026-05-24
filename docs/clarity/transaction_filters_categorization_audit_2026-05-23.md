# Transaction, Filter, and Categorization Hard Audit

Date: 2026-05-23

Scope: mobile transaction import, category assignment, dashboard transaction filters, account transaction review, and budget/category rollups.

Screenshots reviewed:
- `IMG_0973.PNG`: account dashboard shows an error-style import toast after rows appear categorized.
- `IMG_0974.jpg`: category list includes `Income / Payroll`, `Income / Zelle Received`, and `Ignored` with `$0.00`, which makes category mode look broken.

## Executive Summary

The app has enough transaction/category functionality to import and review data, but the logic is not yet internally consistent. The biggest problem is not one bug; it is that different layers answer different questions:

- Import status answers "Did AI succeed?"
- Category screens answer "What display label does this row resolve to?"
- Category group totals answer "How much spending is in this label?"
- Filters answer "Does the row display label equal this string?"
- Dashboard cards answer "What happened in the dashboard reference month?"

Those are valid questions, but the UI mixes them without explaining the distinction. That is why the user can see categorized transactions while still seeing an error/fallback message, `$0.00` category cards, and filters that feel unreliable.

The app needs one shared transaction resolution model for all transaction surfaces: rows, months, categories, filters, budgets, Rex context, import status, and dashboard metrics.

## Critical Findings

### P0 - Import completion still looks like failure when rows are usable

Evidence:
- `apps/mobile/lib/features/transactions/data/csv_import_service.dart:372-382` marks `aiSucceeded = false` if any AI batch failed, even after deterministic fallback categories are applied.
- `apps/mobile/lib/features/transactions/application/import_job_status_service.dart:29-39` shows an error-style snackbar/persistent message whenever AI failed or fallback was used.

User impact:
- A successful import with useful fallback categories can still say: `AI failed; fallback categories were applied.`
- The user reads this as "categorization is broken", even when the visible rows are categorized.

Root cause:
- Import status treats AI transport success as the primary success signal.
- It does not distinguish:
  - all rows categorized by AI,
  - some rows categorized by deterministic fallback,
  - some rows left `Unknown`,
  - category assignment update failed.

Required adjustment:
- Replace `aiSucceeded`-driven UI severity with final data-quality status:
  - success: inserted rows > 0 and unknown/unresolved count is 0,
  - warning: inserted rows > 0 and unresolved count > 0,
  - error: insert failed or category assignment failed.
- Message examples:
  - `Imported 269 transactions. 269 categorized.`
  - `Imported 269 transactions. 31 used local category rules.`
  - `Imported 269 transactions. 18 still need review.`
  - `Import failed before transactions were saved.`

### P0 - Category mode includes income and ignored rows but displays spend-only totals

Evidence:
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:693-708` groups every filtered transaction by display category.
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:1075-1077` computes group total using only negative amounts.
- The screenshot shows `Income / Payroll`, `Income / Zelle Received`, and `Ignored` with `$0.00`.

User impact:
- Category mode looks mathematically wrong.
- It implies the app "lost" income amounts, when the UI is actually showing spend totals for non-spend buckets.

Root cause:
- Category mode is labeled like all transaction categories but totals like spending categories.

Required adjustment:
- Decide category mode semantics:
  - Option A, recommended: `Categories` means spend categories only. Hide income, ignored, transfers, credit card payments, and refunds from spend category cards.
  - Option B: rename the mode to `Groups` and show net/inflow/outflow totals per group.
- If keeping spend category mode, add a separate `Income` or `Cash flow` section elsewhere.

### P0 - Category filter options include groups that should not be spend filters

Evidence:
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:671-682` builds filter options from every transaction display category.
- It does not remove income, ignored, transfers, or unresolved categories.

User impact:
- Selecting category filters can produce confusing row sets and `$0.00` category totals.

Required adjustment:
- Create typed filter groups:
  - `Spending category`
  - `Income type`
  - `Transfer / ignored`
  - `Needs review`
- Or keep one `Category` filter but label each option with role and amount semantics.

### P1 - Time filters are relative to latest imported transaction, not the visible dashboard period

Evidence:
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart:607-649` computes `latest` from the transaction list, then `Latest month` means the month of the newest transaction.
- Account dashboard cards use the dashboard spend reference month.

User impact:
- The account header can show May 2026 metrics, while transaction category review can be March 2026 or all time.
- This is visible in the screenshot: the dashboard says May 2026 / `$0.00`, while category rows clearly represent imported historical data.

Required adjustment:
- Make time filters explicit:
  - `Current dashboard month`
  - `Latest transaction month`
  - `All imported history`
  - month picker
- Show the active date range near the transaction count.

### P1 - `Transaction.categoryId` means different things in different layers

Status: fixed in Refactor Phase 1. App-facing transactions now use `Transaction.categoryLabel`; raw Supabase category UUIDs remain on `TransactionRecord.categoryId`.

Evidence:
- Historical issue: the app-domain `Transaction.categoryId` name implied a raw UUID while often holding a resolved label.
- Current state: `Transaction.categoryLabel` is the app-facing label and `TransactionRecord.categoryId` is the raw Supabase UUID.
- Current mappers convert raw `TransactionRecord.categoryId` through `categoryNameForId` before setting `Transaction.categoryLabel`.

User impact before fix:
- Category resolution could silently differ depending on which controller/service created the `Transaction`.
- Filters and grouping could appear fixed in one view and broken in another.

Completed adjustment:
- `TransactionRecord.categoryId`: Supabase category UUID.
- `Transaction.categoryLabel`: resolved display/canonical label.
- Raw category UUIDs are no longer passed into `spendGroupLabel`.

### P1 - Import fallback count means only `Unknown`, but fallback message means "not AI"

Evidence:
- `apps/mobile/lib/features/transactions/data/csv_import_service.dart:567-569` increments `fallbackCategoryCount` only when final category is Unknown.
- But import completion message uses fallback language when AI fails, even if deterministic fallback assigned real categories.

User impact:
- The app can say fallback categories were applied while all rows have meaningful category labels.

Required adjustment:
- Track separate counts:
  - `aiCategorizedCount`
  - `learnedRuleCategorizedCount`
  - `deterministicFallbackCategorizedCount`
  - `unknownCount`
  - `categoryUpdateFailureCount`

### P1 - Filters and grouping duplicate category resolution logic instead of consuming `ResolvedTransaction`

Evidence:
- `financial_dashboard_view.dart` uses `_displayCategory(transaction)` directly for filter/group/search.
- Metrics use `ResolvedTransaction` in dashboard domain code.
- Month grouping uses a different call path via `monthlyBankGroupsNewestFirstForScopedTransactions`.

User impact:
- Totals, row labels, search, filters, and metrics can drift.

Required adjustment:
- Build one `ResolvedTransactionViewModel` list when loading dashboard transactions.
- All row views, filters, category groups, and month groups should consume that list.

### P1 - Manual category update applies merchant learning too broadly by default

Evidence:
- `apps/mobile/lib/features/transactions/application/category_workflow_service.dart:58-67` defaults `applyToSimilarMerchants = true`.
- UI asks confirmation only when matching count is > 1.

User impact:
- One tap can create a merchant rule and affect future imports even when the user intended a one-off correction.

Required adjustment:
- Default inline assignment should update only this transaction.
- Provide a clear secondary action: `Apply to similar`.
- Persist merchant rule only after explicit confirmation.

### P2 - Category group cards do not communicate amount type

Evidence:
- `_CategoryGroupCard` always shows `formatMoney(group.spending)`.
- It does not say `spent`, `received`, `net`, or `ignored`.

User impact:
- `$0.00` on income rows looks like missing data.

Required adjustment:
- Add amount labels or split sections:
  - `Spent $99.64`
  - `Received $1,200.00`
  - `Ignored 1 row`

### P2 - Row list truncates at 80 without pagination or "load more"

Evidence:
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart` has `_InlineTransactionsList._maxRows = 80`.

User impact:
- On a 269-row import, users can think filters lost rows.

Required adjustment:
- Add `Show more`, virtualized list, or a full transaction review screen.

### P2 - Import result tests lock in misleading behavior

Evidence:
- Tests assert AI failure with deterministic fallback is a completed import, but import status tests only cover fully failed imports.

Required adjustment:
- Add tests for:
  - AI unavailable + deterministic categories + zero unknowns should be warning or success, not error.
  - category mode excludes income/ignored when in spend mode.
  - category filter + time filter use the same resolved transaction list.
  - latest transaction month vs current dashboard month behavior.

## Repair Plan

## Implementation Log

- P0 complete: import completion now reports final data quality instead of AI transport status; spend category mode/filter options now exclude unresolved, income, and ignored rows.
- P1 complete: import results now track AI, learned merchant rule, deterministic local fallback, unresolved, and category update failure counts separately.
- P1 complete: transaction time filters now distinguish dashboard month, latest transaction month, latest transaction year, and all imported history with the active date range visible in the transaction subtitle.
- P1 complete: inline/manual category assignments now default to only the selected transaction; applying to similar merchants and saving a future import rule requires explicit confirmation.
- P1 complete: dashboard transaction search, filters, category groups, row category chips, and month grouping now consume the shared `ResolvedTransaction` read model instead of resolving category/role semantics independently.
- P1 complete: transaction/category workflows now map persisted category UUIDs through the category read model before building app `Transaction` objects, avoiding raw database IDs leaking into display/category resolution.
- P2 complete: category group cards now label their total as `Spent`, so amount semantics are visible at the card level.
- P2 complete: inline transaction review now has a `Show more` control instead of stopping at the first 80 rows.
- P2 complete: spend-category grouping is covered by a domain regression test that excludes income, ignored, and unresolved rows.

### Step 1 - Create a shared resolved transaction read model

Create one app-facing model, for example:

```dart
class ResolvedTransactionView {
  final TransactionRecord record;
  final Account? account;
  final CategoryRecord? storedCategory;
  final String displayCategory;
  final FinancialRole role;
  final bool countsAsSpend;
  final bool countsAsIncome;
  final bool isIgnored;
  final bool needsReview;
  final double signedAmount;
}
```

Every transaction UI surface should use this model.

### Step 2 - Fix import completion semantics

Replace `aiSucceeded + fallbackCategoryCount` with final outcome counts.

Acceptance criteria:
- If all rows are categorized by AI or deterministic fallback, do not show an error.
- If some rows are still Unknown, show a review warning.
- If DB insert/update fails, show an error.

### Step 3 - Redesign transaction category mode

Recommended model:
- `Spending categories`: expense rows only, sorted by spend.
- `Income`: income rows only, sorted by received amount.
- `Ignored / transfers`: collapsed utility group, not mixed into spend categories.
- `Needs review`: unresolved rows.

Acceptance criteria:
- No income category card with `$0.00` in the spend category list.
- Ignored rows never appear as a spend category.

### Step 4 - Replace current filters with explicit filter state

Use a filter object:

```dart
class TransactionFilterState {
  final String? accountId;
  final String? categoryKey;
  final FinancialRole? role;
  final DateTimeRange? dateRange;
  final bool needsReviewOnly;
  final TransactionSortMode sort;
  final String query;
}
```

Acceptance criteria:
- Filter chips show exact active state.
- Time filter displays exact date range.
- Clearing filters resets all state.
- Category filter options are derived from resolved rows and role-aware.

### Step 5 - Make account dashboard period obvious

The top cards should say which month they summarize and should not conflict with all-time transaction review below.

Acceptance criteria:
- Header metric says `Available in May 2026`.
- Transaction section says `All imported history`, `March 2026`, or selected range.
- User can change month from the transaction section.

### Step 6 - Add regression tests before visual polish

Minimum tests:
- Import with AI failure but deterministic fallback categories does not produce error severity when unknown count is 0.
- Import with Unknown rows produces a review warning with unknown count.
- Category group spend mode excludes income and ignored rows.
- Income group displays income amount, not `$0.00`.
- Category filter uses resolved category labels, not raw DB ids.
- Time filter range is deterministic and visible.

## Suggested Implementation Order

1. Fix import status severity and counters.
2. Add resolved transaction view model.
3. Rewrite category groups and filters to use resolved rows.
4. Add date range/month picker behavior.
5. Add transaction list pagination or full review screen.
6. Add tests and only then do UI polish.

## Definition Of Perfect Enough

The transaction experience is ready when:

- An import produces one truthful status: categorized, partially categorized, or failed.
- Every visible amount explains whether it is spend, income, net, or ignored.
- Dashboard cards and transaction lists always state their date range.
- The same transaction has the same category everywhere.
- Filters never change the meaning of totals silently.
- User category changes are predictable and reversible.
- Rex receives the same resolved transaction facts the UI shows.
