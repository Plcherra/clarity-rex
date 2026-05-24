# Transaction Role Override Plan

Date: 2026-05-24

## Current State

- `transactions.type` remains the signed direction used for storage: `income` or `expense`.
- `transactions.financial_role` is available for semantic overrides via migration `000011_add_transaction_financial_role.sql`.
- App read mappers now hydrate `Transaction.financialRole` only from `transactions.financial_role`.
- When `financial_role` is null, role semantics are derived from category, description, account type, and internal-payment matching.

## Role Contract

- `type`: storage direction only.
- `financial_role`: optional user/system meaning.
- `Transaction.categoryLabel`: app-facing resolved category label.
- `TransactionRecord.categoryId`: raw Supabase category UUID.

Supported `financial_role` values:

- `expense`
- `income`
- `transfer`
- `credit_card_payment`
- `refund`
- `adjustment`

## Remaining Work

- Role override controls have been added to transaction rows in the dashboard and month detail views.
- A dashboard Review queue now surfaces unresolved categories, possible unmatched credit-card payments, and manual role overrides.
- Role changes now persist through `TransactionService.updateTransaction`.
- Include role override metadata in Rex action proposals before allowing Rex to change roles.
- Add audit trail fields if role changes become high-volume or automated.

## Testing Expectations

- Persisted records with category UUIDs must resolve through category labels before role inference.
- Ignored rows, refunds, transfers, confirmed credit-card payments, and income rows must keep correct `countsAsSpend` / `countsAsIncome` behavior after DB mapping.
- Manual `financial_role` overrides must win over category/description inference.
