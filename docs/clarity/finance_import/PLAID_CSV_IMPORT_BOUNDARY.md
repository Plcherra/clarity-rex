# Plaid and CSV Import Boundary

## Purpose

This boundary keeps financial ingestion source-specific while preserving one
shared read model for the dashboard, Rex, budgets, and transaction review.

CSV import and future Plaid sync may parse transactions differently, but both
must converge before persistence on the same transaction identity, category
resolution, and read-model contracts.

## Current CSV Boundary

- `apps/mobile/lib/features/transactions/data/csv_import_service.dart`
  orchestrates CSV parse, duplicate detection, persistence, and categorization.
- `apps/mobile/lib/features/transactions/data/csv_import_categorizer.dart`
  owns learned merchant rules, AI category suggestions, fallback categories, and
  category application.
- `apps/mobile/lib/features/transactions/domain/transaction_fingerprint.dart`
  owns the stable dedupe key: account, date, signed amount, and normalized
  description.
- `apps/mobile/lib/features/finance/application/financial_read_model_service.dart`
  loads persisted data only. It must not know whether records came from CSV,
  Plaid, manual entry, or another source.

## Plaid Insertion Rule

Plaid sync should add a focused ingestion service rather than extending the CSV
service or dashboard widgets.

Recommended shape:

- `plaid_import_service.dart`: fetch/sync Plaid transactions and map them into
  the same transaction persistence inputs.
- `plaid_transaction_mapper.dart`: normalize Plaid transaction fields into the
  Clarity transaction model.
- Shared duplicate policy: call `transactionFingerprint` on the normalized
  transaction and compare against existing persisted transactions for the same
  account.

## Contract

Plaid-style and CSV-style rows representing the same transaction must generate
the same fingerprint when they share:

- account id
- calendar date
- signed amount
- normalized merchant/description text

Different accounts must not dedupe against each other, even if date, amount, and
description match.

This contract is covered by
`apps/mobile/test/financial_integration_contracts_test.dart`.

## UI Boundary

- Account tiles should show quiet source labels: `Plaid` for connected accounts
  and `Manual/CSV` for manually maintained accounts.
- Transaction rows shown inside connected account summaries should also show
  quiet source labels so mixed Plaid and CSV rows are understandable without
  looking like an error state.
- If a user imports CSV into an already Plaid-connected account, Clarity should
  calmly warn that overlapping CSV rows can create duplicates. The UI should not
  block the path because CSV can still be useful for historical gaps, but the
  user should make that choice intentionally.
- Deduplication remains a persistence/import concern. Presentation components
  should explain source and risk; they should not invent their own duplicate
  rules.

## Non-Goals

- Do not add Plaid SDK or API logic inside dashboard presentation files.
- Do not make Rex financial context query Plaid directly.
- Do not bypass `FinancialReadModel`; the dashboard, Rex, and budgets should all
  read from the same persisted model.
