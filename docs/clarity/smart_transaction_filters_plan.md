# Smart Transaction Filters Plan

## Goal

Make transaction discovery feel like a natural part of the dashboard and account
detail experience. Filters should change the existing transaction visualization
area instead of opening a separate browsing screen or bringing back a review
queue.

The main use case is finding `Unknown` transactions after import, but the same
controls should also help users inspect categories, large expenses, income,
refunds, and specific time periods.

## Product Requirements

1. Users can find `Unknown` transactions quickly.
2. Filters live inline inside the dashboard/account transaction section.
3. Global dashboard filters may include account scope.
4. Account detail filters must not include account scope because the user is
   already inside one account.
5. Users can filter by category, time, amount type, and sort order.
6. Users can search merchant and description text.
7. Users can correct categories directly from filtered transaction rows.
8. Filters are optional tools, not a forced review queue.
9. Saved shortcut buttons are not part of the current UX.

## Phase 1: Inline Transaction Visualization

Status: Complete

Priority: High

### Tasks

1. Keep the existing month summary list as the default visualization. Done.
2. Add inline view modes for months, categories, and rows. Done.
3. Remove separate transaction browsing entry points. Done.
4. Avoid reintroducing "transactions need attention" language. Done.

### Key Files

1. `lib/features/dashboard/presentation/financial_dashboard_view.dart`
2. `lib/features/accounts/presentation/account_detail_screen.dart`
3. `lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart`

### Acceptance Criteria

1. Dashboard and account detail expose transaction discovery inline. Done.
2. Users do not have to leave the dashboard/account context to filter
   transactions. Done.
3. No mandatory review queue appears. Done.

### Implementation Notes

1. The transaction section now supports `Months`, `Categories`, and `Rows`
   modes.
2. Account detail keeps the user scoped to the active account.
3. The separate transaction explorer screen was removed because filters now
   control the inline transaction section.

## Phase 2: Build Core Filters

Status: Complete

Priority: Critical

### Filters

1. Category:
   - all categories
   - `Unknown`
   - one selected category
   - Done.
2. Time:
   - all time
   - month
   - year
   - Done.
3. Account:
   - all accounts
   - one selected account
   - global dashboard only
   - Done.
4. Amount type:
   - all amounts
   - spending
   - income
   - Done.
5. Sort:
   - newest
   - oldest
   - amount high to low
   - merchant A-Z
   - Done.

### Key Files

1. `lib/features/dashboard/presentation/financial_dashboard_view.dart`
2. `lib/features/transactions/data/transaction_service.dart`
3. `lib/features/categories/data/category_service.dart`

### Acceptance Criteria

1. Filtering does not require fetching only the newest 1000 rows. Done.
2. Filters work for large accounts. Done.
3. `Unknown` filter returns matching transactions across months. Done.
4. Account filters are hidden in account-scoped views. Done.

### Implementation Notes

1. Core filters are implemented inline over the existing paginated transaction
   fetch.
2. Account detail receives an account-scoped transaction set and only exposes
   relevant category/time/amount/sort controls.
3. The first version keeps filtering local in Flutter; server-side query
   filters can be added later if very large datasets make local filtering slow.

## Phase 3: Add Smart Search

Status: Complete

Priority: High

### Search Behavior

1. Search by merchant or description. Done.
2. Normalize text for case, punctuation, and bank noise. Done.
3. Match similar merchant variants where possible. Done.
4. Support simple query terms:
   - `unknown`
   - `march 2026`
   - `coffee`
   - `over 100`
   - `income`
   - Done.
5. Keep search local in Flutter first if the loaded result set is bounded. Done.
6. Move search to Supabase queries if local search becomes slow.

### Key Files

1. `lib/features/dashboard/presentation/financial_dashboard_view.dart`
2. `lib/features/transactions/domain/merchant_normalization.dart`
3. `lib/features/transactions/data/transaction_service.dart`

### Acceptance Criteria

1. Searching merchant text finds matching rows across visible periods. Done.
2. Searching `unknown` exposes fallback-category rows. Done.
3. Search results can be category-corrected inline. Done.

### Implementation Notes

1. Smart search is part of the inline transaction section.
2. Search recognizes merchant/category/description text, month-year phrases,
   amount thresholds, and amount-type queries without bringing back a review
   queue.

## Phase 4: Add Bulk Correction Actions

Status: Complete

Priority: High

### Tasks

1. Let users correct a transaction category from filtered rows. Done.
2. Offer `Apply to similar transactions` after category correction. Done.
3. Use grouped Supabase bulk updates. Done.
4. Connect corrections to merchant learning rules. Done.

### Key Files

1. `lib/features/transactions/application/category_workflow_service.dart`
2. `lib/features/transactions/data/transaction_service.dart`
3. `lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart`

### Acceptance Criteria

1. User can correct Unknown rows efficiently. Done.
2. Similar-merchant updates do not run one transaction at a time. Done.
3. Dashboard and Budget views refresh after corrections. Done.

### Implementation Notes

1. Category correction remains row-based in the inline transaction list.
2. The similar-merchant confirmation can update matching rows and remember the
   merchant rule for future imports.

## Phase 5: Polish Inline Filters

Status: Complete

Priority: Medium

### Tasks

1. Remove saved shortcut buttons from the transaction filter surface. Done.
2. Keep quick access through category chips and smart search instead. Done.
3. Keep the UI compact enough for mobile dashboard/account pages. Done.

### Acceptance Criteria

1. No saved shortcut section appears in the app. Done.
2. Users can still reach Unknown, large expenses, and subscriptions through
   category/search/filter controls. Done.
3. The filter UI remains contextual to global dashboard vs account detail. Done.

## Risks

1. Inline filters can crowd the dashboard if too many controls are visible at
   once.
2. Smart search can overmatch merchants if normalization is too aggressive.
3. Similar-merchant correction needs clear confirmation to avoid accidental
   large changes.
