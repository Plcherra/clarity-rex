# Category Validation Guardrails Plan

## Goal

Prevent invalid, unsafe, too-short, or low-quality category names from being
created or shown in the app.

Examples that must be blocked:

1. `C`
2. Empty strings
3. One-letter labels
4. Punctuation-only labels
5. Duplicate categories that differ only by case, spacing, or punctuation

`Unknown` remains the only fallback for invalid category suggestions.

## Product Requirements

1. AI can create new useful categories.
2. Invalid AI suggestions must never create category rows.
3. Invalid suggestions must fall back to `Unknown`.
4. Category validation must be consistent between Flutter and the Edge Function.
5. Category rows must remain scoped to the authenticated user.

## Phase 1: Define Category Name Rules

Priority: Critical

### Rules

1. Trim leading and trailing whitespace.
2. Collapse repeated spaces.
3. Normalize punctuation consistently.
4. Reject names shorter than 3 meaningful characters.
5. Reject names with no letters or numbers.
6. Reject names that are only one token and one character long.
7. Normalize category names before lookup or insert.
8. Use `Unknown` for anything rejected.

### Key Files

1. `lib/features/categories/domain/category_normalization.dart`
2. `supabase/functions/categorize-transactions/index.ts`

### Acceptance Criteria

1. `C` becomes `Unknown`.
2. `  grocery   / supermarket  ` normalizes consistently.
3. `Food & Drink`, `food drink`, and `Food  Drink` do not create obvious
   duplicates.

## Phase 2: Enforce Validation In Flutter

Priority: Critical

### Tasks

1. Update category normalization utilities.
2. Update category creation to reject invalid names before calling Supabase.
3. Update CSV import category application to replace invalid names with
   `Unknown`.
4. Add tests for invalid AI suggestions.

### Key Files

1. `lib/features/categories/domain/category_normalization.dart`
2. `lib/features/categories/data/category_service.dart`
3. `lib/features/transactions/data/csv_import_service.dart`
4. `test/category_creation_normalization_test.dart`
5. `test/csv_import_service_test.dart`

### Acceptance Criteria

1. Flutter never inserts a one-character category.
2. Existing import fallback behavior still guarantees non-null `category_id`.
3. Invalid category suggestions are counted as fallback assignments.

## Phase 3: Enforce Validation In Edge Function

Priority: Critical

### Tasks

1. Apply the same validation before returning suggestions to Flutter.
2. Convert invalid model output to `Unknown`.
3. Keep response shape stable.
4. Add logging for rejected category names without exposing sensitive data.

### Key Files

1. `supabase/functions/categorize-transactions/index.ts`

### Acceptance Criteria

1. Edge Function never returns `C` as a category.
2. Edge Function returns a valid category name or `Unknown` for every
   transaction key.
3. Large imports keep working with validation enabled.

## Phase 4: Clean Existing Bad Category Data

Priority: Medium

Status: Complete

### Tasks

1. Identify existing invalid categories per user. Done with
   `supabase/sql/phase4_invalid_category_audit.sql`.
2. Reassign transactions using invalid categories to `Unknown`. Done in
   `supabase/sql/phase4_cleanup_invalid_categories.sql`.
3. Delete invalid category rows if no longer referenced. Done in
   `supabase/sql/phase4_cleanup_invalid_categories.sql`.
4. Run this as a manual SQL cleanup or one-time migration only if needed. Done
   manually against the linked Supabase project on May 20, 2026.

### Cleanup Result

The cleanup found and deleted one invalid category row named `C`. It did not
need to reassign any transactions from invalid categories, and no null
`category_id` transactions were present.

### Acceptance Criteria

1. Existing `C` category rows are removed or no longer visible.
2. No transaction ends with a null category.
3. Budget page no longer shows invalid categories.

## Phase 5: Improve Deterministic Fallback Rules

Priority: High

Status: Complete

### Tasks

1. Add obvious merchant/category fallback rules for common cases:
   - `DUNKIN`, `DD`, `TST*...DOUGH` -> Coffee / Quick Food. Done.
   - `DOLLARTREE` -> Shopping. Done.
   - `PEARL ST MARKET` -> Grocery / Supermarket. Done.
   - ATM withdrawals -> Cash Withdrawal. Done.
2. Avoid assigning negative purchases to `Income / Payroll`. Done with
   amount-aware fallback rules and Edge Function output sanitation.
3. Prefer `Unknown` over a clearly wrong confident category. Done for negative
   AI income suggestions that do not match deterministic income rules.

### Implementation Result

Deterministic fallback rules now run in Flutter during local fallback category
assignment and in the `categorize-transactions` Edge Function before OpenAI is
called. Known merchant patterns bypass AI, and negative transactions cannot be
accepted as income categories from the model.

### Key Files

1. `lib/features/transactions/domain/spend_categories.dart`
2. `lib/features/transactions/domain/transaction_resolution.dart`
3. `supabase/functions/categorize-transactions/index.ts`

### Acceptance Criteria

1. Known bad examples from manual testing are no longer miscategorized.
2. Fallback rules do not create category sprawl.
3. Fallback rules remain user-editable later through merchant learning.

## Risks

1. Over-strict validation could reject useful short categories like `Gas`.
2. Flutter and Edge Function validation can diverge if duplicated carelessly.
3. Cleaning existing bad data must not delete user-created valid categories.
