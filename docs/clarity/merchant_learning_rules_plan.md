# Merchant Learning Rules Plan

## Goal

When a user manually corrects a transaction category, Clarity should learn that
merchant pattern and apply the correction to matching past and future
transactions.

Example:

If the user changes a Dunkin transaction to `Coffee / Quick Food`, Clarity
should update and remember similar merchants:

1. `DUNKIN`
2. `DD`
3. `DUNKIN DONUTS`
4. `DUNKIN' DONUTS`

## Product Requirements

1. Learning is scoped to the authenticated user.
2. Manual correction updates matching past transactions.
3. Future imports apply learned merchant rules automatically.
4. Learned rules should beat fresh AI guesses.
5. Matching should be conservative enough to avoid broad wrong updates.
6. Learning data must live in Supabase, not local storage.

## Phase 1: Add Merchant Rule Data Model

Priority: Critical
Status: Complete

### Table Shape

Create a Supabase table such as `merchant_category_rules`:

```sql
merchant_category_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  merchant_key text not null,
  merchant_display text,
  aliases text[] not null default '{}',
  category_id uuid not null references public.categories(id) on delete cascade,
  match_type text not null default 'normalized_exact',
  confidence numeric not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, merchant_key)
)
```

### Tasks

1. Add migration. Done.
2. Add row-level security policies. Done.
3. Add uniqueness by `user_id + merchant_key`. Done.
4. Add indexes for rule lookup. Done.

### Acceptance Criteria

1. Users can only read/write their own merchant rules. Done.
2. Duplicate rules for the same normalized merchant are prevented. Done.
3. Rules can be queried quickly during import. Done.

### Implementation Notes

1. Added `supabase/migrations/000009_create_merchant_category_rules.sql`.
2. Rules are scoped by `user_id` and use a composite foreign key to the user's
   category row.
3. `merchant_key` is unique per user, with indexes for category, match type, and
   alias lookup.
4. RLS allows authenticated users to manage only their own rules.

## Phase 2: Build Merchant Normalization

Priority: Critical
Status: Complete

### Tasks

1. Normalize merchant descriptions into stable merchant keys. Done.
2. Strip dates, card fragments, authorization numbers, and location suffixes.
   Done.
3. Preserve meaningful brand tokens. Done.
4. Add alias support for known variants. Done.
5. Avoid overmatching aggregator prefixes like `TST*`, `SQ*`, and `PAYPAL`
   without preserving the underlying merchant name. Done.

### Examples

1. `DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA` -> `dunkin`
2. `DD/BR #1234` -> `dunkin`
3. `TST* BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA` -> `bom dough`
4. `APPLE.COM/BILL 05/03 REFUND 866-712-7753 CA` -> `apple com bill`

### Key Files

1. `lib/features/transactions/domain/merchant_normalization.dart`
2. `lib/features/transactions/domain/transaction_resolution.dart`
3. `test/merchant_normalization_test.dart`

### Acceptance Criteria

1. Known merchant variants produce stable keys. Done.
2. Bank noise is removed. Done.
3. Different unrelated merchants are not merged accidentally. Done.

### Implementation Notes

1. Updated `lib/features/transactions/domain/merchant_normalization.dart` with a
   deterministic merchant-key normalizer.
2. The normalizer strips dates, phone/reference numbers, masked fragments, bank
   noise, and common trailing location tokens.
3. Aggregator prefixes such as `TST`, `SQ`, and `PAYPAL` are removed only when a
   meaningful underlying merchant remains.
4. Added explicit high-confidence aliases for Dunkin variants.
5. Added `test/merchant_normalization_test.dart` to lock the examples and guard
   against accidental broad matching.

## Phase 3: Learn On Manual Correction

Priority: Critical
Status: Complete

### Tasks

1. Update manual category correction flow. Done.
2. After user selects a category, create or update the merchant rule. Done.
3. Find matching past transactions for the authenticated user. Done.
4. Bulk update matching transaction `category_id` values. Done.
5. Refresh dashboard, account, transaction, and budget views. Done.

### Key Files

1. `lib/features/transactions/application/category_workflow_service.dart`
2. `lib/features/transactions/data/transaction_service.dart`
3. `lib/features/categories/data/category_service.dart`
4. New file: `lib/features/transactions/data/merchant_category_rule_service.dart`

### Acceptance Criteria

1. Correcting one Dunkin transaction updates matching old Dunkin rows. Done.
2. Updates use grouped bulk Supabase operations. Done.
3. The corrected category appears in Budget totals after refresh. Done.

### Implementation Notes

1. Added `MerchantCategoryRuleService` for Supabase-backed rule fetch/upsert.
2. Manual category correction now upserts a user-scoped merchant rule when the
   transaction has a stable merchant key.
3. Matching existing transactions are found using deterministic merchant
   normalization and updated through `updateTransactionsCategory`.
4. The flow refreshes all app state after the grouped category update so
   dashboard, account, transaction, and budget views reflect the correction.
5. Added focused matching tests in `test/merchant_learning_rules_test.dart`.

## Phase 4: Apply Rules During CSV Import

Priority: Critical
Status: Complete

### Tasks

1. Load merchant rules before categorization. Done.
2. Apply matching rules to inserted transactions before AI. Done.
3. Send only unmatched transactions to AI when practical. Done.
4. Let merchant rules override AI suggestions for matching transactions. Done.
5. Fall back to `Unknown` when neither rule nor AI produces a valid category.
   Done.

### Key Files

1. `lib/features/transactions/data/csv_import_service.dart`
2. `lib/features/transactions/data/merchant_category_rule_service.dart`
3. `lib/features/transactions/data/transaction_service.dart`

### Acceptance Criteria

1. Future imports categorize learned merchants without waiting for AI. Done.
2. Learned rules reduce Unknown count over time. Done.
3. Imports still guarantee non-null `category_id`. Done.

### Implementation Notes

1. `CsvImportService.importAndCategorize(...)` now loads
   `merchant_category_rules` after inserting rows and before AI categorization.
2. Inserted transactions with normalized merchant keys matching a learned rule
   receive that learned category without being sent to AI.
3. Mixed imports send only unmatched rows to `categorize-transactions`, reducing
   AI work and preserving learned corrections.
4. Learned categories are merged after AI suggestions, so rules remain the final
   authority for matching merchants.
5. Category assignment still runs through the existing grouped bulk update path,
   preserving the non-null `category_id` guarantee.
6. Added CSV import tests for all-learned and mixed learned/AI imports.

## Phase 5: Add User Control And Safety

Priority: High

### Tasks

1. [x] After manual correction, ask whether to apply to similar merchants.
2. [x] Show how many transactions will be updated before bulk update.
3. [x] Add a correction path.
4. [x] Add a future merchant rules management screen only if needed.

### Implementation Notes

1. Manual category corrections now preview matching merchant transactions before any broad update.
2. Users can cancel, update only the selected transaction, or update all similar transactions.
3. Choosing “Only this one” skips rule creation, so future imports are not affected by that correction.
4. Choosing “Update N” creates/updates the merchant rule and bulk-updates matching historical transactions.
5. The correction path is to choose another category for the same merchant group; a dedicated rule management screen is deferred until there is a clear product need.

### Acceptance Criteria

1. [x] Users are protected from accidental broad changes.
2. [x] Users understand when a correction is being applied broadly.
3. [x] Learning remains helpful without feeling hidden or surprising.

## Phase 6: Tests And Quality Gates

Priority: Critical

### Tests

1. Merchant normalization variants.
2. Manual correction creates a merchant rule.
3. Manual correction bulk updates matching past transactions.
4. Future import applies learned rules before AI.
5. Learned rules are scoped per user.
6. Unrelated merchants are not updated.

### Validation

1. `flutter analyze`
2. `flutter test`
3. `git diff --check`
4. Manual import and correction test on iPhone.

## Risks

1. Overmatching can incorrectly rewrite many transactions.
2. Undermatching reduces the value of learning.
3. Merchant aliases need to be explicit for high-risk abbreviations.
4. Rule changes must keep Budget totals and transaction lists in sync.
