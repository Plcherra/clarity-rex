# Clarity Finance Source Of Truth

This document tracks the current finance data wiring used by Dashboard,
Accounts, Budgets, Transactions, Plaid, CSV import, and Rex financial context.

## Canonical Tables

| Data | Source |
| --- | --- |
| Profiles | Supabase `profiles` |
| Accounts | Supabase `accounts` |
| Plaid account metadata | Supabase `plaid_accounts` |
| Plaid item/token state | Backend-owned Supabase Plaid tables |
| Transactions | Supabase `transactions` |
| Categories | Supabase `categories` |
| Budgets | Supabase `budgets` |
| Merchant learning | Supabase `merchant_category_rules` |
| CSV import batches | Supabase `account_statement_imports` |
| Financial audit | Supabase `financial_audit_events` |

## Mobile Read Path

The mobile finance read model is built by
`apps/mobile/lib/features/finance/application/financial_read_model_service.dart`.

It loads:

- accounts
- transactions
- budgets
- categories
- merchant category rules
- account statement imports

The same read model powers:

- Dashboard
- Account detail dashboard
- Budgets
- Transaction review
- Rex financial context

## Mobile Write Path

The native finance UI writes directly to Supabase through feature services:

- `AccountService`
- `TransactionService`
- `CategoryService`
- `BudgetService`
- `MerchantCategoryRuleService`
- `AccountStatementImportService`

Writes must stay user-scoped through Supabase Auth and RLS.

Native UI writes are the primary product path for direct user edits. They should:

- validate input before writing;
- show failure if Supabase rejects the change;
- refresh the shared financial read model after successful mutations;
- record financial audit events where the workflow already supports audit history.

## Rex Finance Path

Rex does not independently fetch finance records today.

Mobile builds a financial summary through
`apps/mobile/lib/rex/data/financial_context_service.dart` and sends it to Rex
only when the user turn is clearly financial.

Backend guardrails:

- `chat_financial_guard.py` uses financial context only for finance intent.
- Unavailable/degraded/partial context is treated as unreliable.
- Rex should say financial data is unavailable rather than guessing.

## Rex Action Write Path

Rex can propose confirmed financial actions. Mobile executes the confirmed action
through `/clarity/actions`, which routes to `ClarityControlService` and writes to
Supabase with backend confirmation.

This is a second write path to the same finance tables. It must follow the same
validation, audit, refresh, and confirmation rules as native UI writes.

Rex action writes are only complete when:

- the user confirms the proposed action;
- Rex API returns an applied result;
- mobile marks the action as applied from that backend result;
- mobile refreshes Dashboard, Accounts, Budgets, and Transactions through
  `notifyDataChanged()`;
- Rex does not claim success before the backend result exists.

## Plaid Path

Plaid is production and backend-owned:

- Mobile requests link tokens through Rex API.
- Native Plaid Link returns a public token.
- Rex API exchanges the public token.
- Rex API syncs Plaid accounts and transactions.
- Mobile reads derived account and transaction records from Supabase.
- Mobile reads Plaid item status from Rex API, including sync status,
  `last_synced_at`, and `webhook_last_received_at`, to explain recovery states.

Plaid tokens and secrets must never be stored in mobile code.

## CSV Path

CSV import is the manual fallback:

- User chooses a file.
- User selects or creates an account.
- Mobile previews and imports transactions.
- AI categorization can use Supabase Edge Function `categorize-transactions`.
- Dashboard, Budgets, and Rex refresh from the same Supabase records.

`UploadScreen` was removed; account-scoped CSV import is the canonical path.

## Current Plan 02 Status

- Finance context is already gated on mobile by finance intent.
- Backend already rejects unreliable financial context for finance turns.
- Degraded Plaid accounts now show a recovery message in the Accounts UI.
- Login-required, pending-expiration, disconnected, degraded, and webhook-delay
  Plaid states have user-facing recovery copy.
- Dashboard now shows a degraded financial data banner when part of the shared
  financial read model fails to load.
- The dual finance write paths are documented here for future validation and
  audit alignment work.
- Remaining validation for this plan is mostly runtime smoke: production Plaid,
  CSV import, category correction, budget refresh, and Rex finance question.
