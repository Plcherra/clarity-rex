# Financial Refactor Next Phases

Date: 2026-05-24

This plan starts after the financial correctness/read-model refactor, import retry
work, dashboard review mode, and current category-management pass. The app is
ready for device testing, but these phases are the next refactors needed to make
the financial area easier to trust, debug, and scale.

## Phase 1 - Category Management 2.0

Status: implementation complete, pending device testing. Hidden custom
categories, impact-aware delete blocking, and category merge plumbing have been
added.

Goal: turn the current category sheet into a real category control center.

Work:
- Add category merge for duplicate or near-duplicate categories.
- Add hidden/system category controls.
- Block or warn before deleting categories used by transactions, budgets, or
  merchant rules.
- Show affected transaction, budget, and merchant-rule counts before destructive
  category actions.
- Keep built-in categories protected from rename/delete.

Acceptance:
- A user can safely rename, delete, hide, or merge categories without stranding
  budgets or transactions.
- Deleting or merging a used category clearly shows the impact first.
- Built-in categories remain protected.

## Phase 2 - Merchant Rule Management

Status: implementation complete, pending device testing. Merchant rules are now
visible in category management, can be changed, disabled/enabled, or deleted,
and disabled rules are ignored by imports and the financial read model.

Goal: make learned categorization rules visible and editable.

Work:
- Add a merchant rules view grouped by merchant/category.
- Allow users to edit, disable, or delete merchant rules.
- Show when a rule was last used and how many transactions it affects.
- Add confirmation before changing rules that will affect future imports.

Acceptance:
- Users can understand why a merchant is categorized a certain way.
- Bad merchant rules can be corrected without editing one transaction at a time.
- Future-import behavior is explicit.

## Phase 3 - Dedicated Transaction Review Screen

Status: implementation complete, pending device testing. A dedicated
transaction review workspace now loads from the shared financial read model,
supports queue filters, search, selection, bulk category correction, and rows
with inline category/role controls.

Goal: graduate dashboard review mode into a focused review workspace.

Work:
- Create a dedicated review screen backed by the shared financial read model.
- Add queues for unresolved categories, possible internal payments, manual role
  overrides, duplicate/import issues, and ignored rows.
- Add saved filters or reusable filter chips.
- Add bulk actions for safe category/role correction.
- Use virtualized or paged rows for large histories.

Acceptance:
- Users can clear financial data issues from one focused place.
- Large transaction sets remain smooth.
- Review queues match the domain review reasons.

## Phase 4 - Import Repair UX

Status: implementation complete, pending device testing. Import and repair
outcomes now expose a structured summary with counts, retry/review actions, and
a category-management path from the persistent bottom panel.

Goal: make import retry and repair results transparent.

Work:
- Replace the current retry-only banner path with a detailed repair summary.
- Show rows scanned, rows repaired, rows still unknown, duplicate rows skipped,
  and category-update failures.
- Add next actions: review unknowns, retry, open category management, or dismiss.
- Keep repair scoped to the affected account/import batch.

Acceptance:
- Import failures no longer feel mysterious.
- Users can tell what was fixed and what still needs manual review.
- Retry never touches unrelated imports.

## Phase 5 - Rex Financial Retrieval

Status: implementation complete, pending device testing. Rex now receives a
summary-first bounded transaction context plus explicit month, account,
category, and review-queue drill-down indexes.

Goal: let Rex drill into financial data on demand instead of relying only on a
compact upfront context.

Work:
- Keep the default Rex context compact and summary-first.
- Add an app/service path for targeted queries by account, month, category,
  merchant, role, and review reason.
- Give Rex metadata that explains context limits and available drill-downs.
- Add tests for large histories so context size stays bounded.

Acceptance:
- Rex can answer broad questions from summaries.
- Rex can inspect specific slices when the user asks about a month, category, or
  account.
- Large ledgers do not create huge default assistant payloads.

## Phase 6 - Role And Category Audit Trail

Status: implementation complete, pending migration/device testing. Financial
audit events now have a Supabase table/service and workflow hooks for category
changes, bulk edits, merges, merchant rule edits, deletes, visibility changes,
and transaction role overrides. Category management now includes a History tab
for recent financial audit events.

Goal: make high-impact financial mutations accountable.

Work:
- Add audit trail records for category changes, role overrides, merges, bulk
  edits, and future Rex actions.
- Store previous value, new value, source, timestamp, transaction/category IDs,
  and reason where available.
- Surface recent changes in transaction/category detail views.

Acceptance:
- Manual and automated financial changes can be explained after the fact.
- Future Rex actions can be allowed safely because changes are traceable.

## Phase 7 - Financial Read Model Integration Tests

Status: implementation complete. Added integration-style financial contract
tests covering CSV-style persisted rows through dashboard totals, budget
performance, statement-balance scopes, Rex drilldown indexes, and large-ledger
review-row retention.

Goal: protect the correctness contracts we just refactored.

Work:
- Add integration-style tests for CSV import -> dashboard totals.
- Add CSV import -> budget performance tests.
- Add CSV import -> Rex context tests.
- Add account balance tests for checking, savings, credit card, and mixed global
  dashboards.
- Add statement-balance edge-case tests.

Acceptance:
- Core financial flows are covered end to end.
- Category, role, balance, and budget regressions are caught before device
  testing.

## Phase 8 - AppState And UI Dependency Cleanup

Status: implementation complete. Dashboard and account/import presentation now
receive transaction, budget, dashboard, and import-status controllers
explicitly instead of reaching through controller-wide `ui` shortcuts.
Transaction deletion routes through `TransactionWorkflowService`; obsolete
dashboard read delegates replaced by `FinancialReadModel` have been removed;
Rex financial context now depends on narrow callbacks instead of the full UI
dependency graph.

Goal: reduce orchestration coupling now that financial logic has a shared read
model.

Work:
- Move remaining financial workflow coordination out of broad app-level state.
- Narrow controller dependencies to explicit services.
- Remove compatibility delegates that only forward calls.
- Keep dashboard, budgets, transactions, and assistant refresh paths explicit.

Acceptance:
- Financial screens depend on small controllers/services instead of broad app
  state.
- Refresh behavior remains correct.
- Tests can instantiate financial workflows without full app composition.

## Phase 9 - Migration And Data Hygiene Pass

Status: implementation complete, pending Supabase push and production SQL
review. Added `000019_financial_data_hygiene_backfill.sql` to create missing
canonical categories, correct canonical category types, and backfill budget
category identity. Added a one-time data hygiene runbook with SQL checks for
unknown categories, duplicate categories, merchant rules, credit-card payment
review, and accounts without statement imports.

Goal: make production data line up with the refactored contracts.

Work:
- Confirm all required migrations are applied in Supabase.
- Backfill old budget rows with category identity where possible.
- Backfill or review older transactions missing `financial_role` where needed.
- Add a one-time data quality checklist for unknown categories, duplicate
  categories, bad merchant rules, and unmatched internal payments.

Acceptance:
- Existing production rows follow the new read-model assumptions.
- Old data does not keep recreating "unknown" or broken budget behavior.

## Phase 10 - Financial QA And Release Checklist

Goal: finish with repeatable manual/device testing before release.

Work:
- Build a manual test script for import, categorization, budgets, balances,
  review queues, Rex questions, and voice/Rex context.
- Test at least one checking account, one credit card account, duplicate import,
  category correction, budget edit, and role override.
- Capture expected screenshots for critical screens.
- Record known limitations that are product choices, not bugs.

Acceptance:
- The financial area has a repeatable release test path.
- Device testing can confirm behavior without rediscovering the same issues.
- Remaining limitations are documented clearly.
