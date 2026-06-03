# Module Contract: Plaid Sync

Status: Active

Owner: Pedro Martins

Last updated: June 3, 2026

## Purpose

Define the backend boundary for connecting financial accounts through Plaid and syncing account and transaction data into Clarity without expanding CSV import, dashboard, Rex chat, or memory modules.

The Plaid Sync module is an ingestion module. It receives user-authorized Plaid data, normalizes it, deduplicates it against existing imported data, persists it through Clarity financial storage, and exposes only persisted read-model data to the rest of the app.

## Scope

### In Scope

- Create Plaid Link tokens for authenticated users.
- Exchange Plaid public tokens for server-held access tokens.
- Store Plaid item/account metadata needed for future sync and deletion.
- Fetch account and transaction data from Plaid after user authorization.
- Normalize Plaid transactions into the same transaction identity contract used by CSV imports.
- Deduplicate Plaid transactions against existing CSV/manual transactions before persistence.
- Support disconnect, deletion, and sync rollback workflows.
- Produce sync status and degraded-state metadata for user-facing screens.

### Out Of Scope

- CSV parsing or CSV import persistence.
- Dashboard presentation and transaction list rendering.
- Rex chat, memory, goals, or voice orchestration.
- Direct Plaid calls from mobile UI.
- Financial advice, credit decisions, underwriting, or payments.
- Long-term token storage in mobile clients.
- Silent deletion bypassing user/account ownership checks.

## Users And Entry Points

| User/System | Entry Point | Expected Outcome |
| --- | --- | --- |
| Mobile app | `POST /plaid/link-token` | Receive a short-lived Link token for the signed-in user. |
| Mobile app | `POST /plaid/exchange-token` | Exchange a public token after Plaid Link success. |
| Backend sync job | `PlaidSyncService.sync_item` | Fetch new/changed transactions and persist normalized records. |
| Mobile app | `DELETE /plaid/items/{item_id}` | Disconnect an item and remove or deactivate associated stored data according to retention rules. |
| Rex financial context | Existing persisted read model | Consume already-saved financial summaries only. |

## Public API

| Name | Type | Responsibility |
| --- | --- | --- |
| `PlaidSyncService.create_link_token` | Service method | Create a Plaid Link token for a user-scoped session. |
| `PlaidSyncService.exchange_public_token` | Service method | Exchange Plaid public token server-side and persist item metadata. |
| `PlaidSyncService.sync_item` | Service method | Sync accounts/transactions for one user-owned Plaid item. |
| `PlaidSyncService.disconnect_item` | Service method | Revoke/delete Plaid item data and mark local records according to deletion policy. |
| `transactionFingerprint` | Mobile/domain helper | Shared dedupe identity for CSV and Plaid-normalized transactions. |

## Data Ownership

### Reads

- Authenticated user id from backend auth context.
- Plaid item/account metadata owned by the user.
- Existing transaction fingerprints for the user's target account(s).
- Existing account records for matching and display.

### Writes

- Plaid item records: encrypted access token reference, item id, institution metadata, status, last sync time.
- Plaid account records: account id, display name, type/subtype, mask, status.
- Normalized transaction records through the same persistence boundary used by CSV/manual imports.
- Sync events and error diagnostics safe for logs and support.

### Does Not Touch

- Rex memory tables.
- Conversation/message tables.
- Goal, commitment, or accountability tables except through existing read-model context.
- Dashboard widget files.
- CSV parser/import files after the shared dedupe contract is defined.

## Dependencies

| Dependency | Direction | Reason |
| --- | --- | --- |
| Plaid API client | Outgoing | Link token creation, token exchange, account/transaction sync. |
| Supabase/Postgres | Outgoing | Persist item/account/transaction/sync state. |
| Auth user context | Incoming | Ensure every operation is user-scoped. |
| Transaction fingerprint policy | Outgoing | Dedupe Plaid and CSV rows consistently. |
| Financial read model | Incoming consumer | Dashboard, budgets, and Rex consume persisted data after sync. |

## Main Flow

1. Mobile requests a Link token from backend with the user's Supabase session.
2. Backend creates the Link token and returns it without exposing Plaid secrets.
3. User completes Plaid Link in mobile and receives a public token.
4. Mobile sends the public token to backend.
5. Backend exchanges it for an access token and stores server-side item metadata.
6. Backend fetches accounts and transactions for the item.
7. Backend maps Plaid rows into Clarity transaction inputs.
8. Backend computes the shared transaction fingerprint and deduplicates against existing rows.
9. Backend persists new/updated rows and sync status.
10. Dashboard, budgets, and Rex read the updated persisted financial read model.

## Failure States

| Failure | User Impact | Handling |
| --- | --- | --- |
| Plaid credentials missing | Link cannot start | Return configured error; do not claim connection succeeded. |
| Link token creation fails | User cannot connect account | Show retryable connection error and log non-secret diagnostics. |
| Public token exchange fails | Account not connected | Do not store partial item as active; prompt user to retry. |
| Institution temporarily unavailable | Sync delayed | Mark item degraded; keep existing data visible with stale timestamp. |
| Duplicate transaction found | No duplicate row appears | Skip or update existing row using fingerprint policy. |
| Partial transaction sync | Some data may be missing | Persist sync cursor/status and retry next sync. |
| Disconnect/delete request fails | Account may remain connected | Surface failure; do not claim deletion until confirmed. |

## Testing Contract

Required tests:

- Link token request rejects unauthenticated users.
- Missing Plaid credentials fail closed.
- Public token exchange never exposes access tokens to mobile.
- Plaid and CSV representations of the same transaction produce the same dedupe fingerprint.
- Different accounts do not dedupe against each other.
- Disconnect marks local item/account state consistently and does not delete another user's data.
- Sync failure returns degraded status instead of empty truth.

Manual QA:

- Connect a sandbox Plaid account.
- Confirm accounts appear in dashboard after sync.
- Confirm Rex can answer from persisted financial context without direct Plaid access.
- Disconnect the account and confirm dashboard/Rex no longer use active Plaid data.
- Request deletion and confirm Plaid item/account/transaction handling follows retention policy.

## File Ownership

Files owned by this module:

- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/app/routes/plaid.py` (future)
- `services/rex-api/tests/test_plaid_sync_service_contract.py`
- `docs/clarity/plaid/MODULE_CONTRACT_PLAID_SYNC.md`
- `docs/clarity/plaid/ADR_PLAID_SYNC_ARCHITECTURE.md`

Files this module may call but should not own:

- `apps/mobile/lib/features/transactions/domain/transaction_fingerprint.dart`
- `apps/mobile/lib/features/finance/application/financial_read_model_service.dart`
- `apps/mobile/lib/features/transactions/data/csv_import_service.dart`
- `apps/mobile/lib/features/dashboard/presentation/*`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/memory_*`

## Size And Refactor Guardrails

| File | Current Lines | Target | Hard Limit | Refactor Trigger |
| --- | ---: | ---: | ---: | --- |
| `plaid_sync_service.py` | 0 | 150-300 | 500 | Split client, mapper, repository, or sync cursor logic. |
| `routes/plaid.py` | 0 | 100-200 | 500 | Split auth/request validation from route handlers. |
| `plaid_transaction_mapper.py` | 0 | 100-200 | 500 | Split account vs transaction mapping. |
| `plaid_item_repository.py` | 0 | 100-250 | 500 | Split token/item/account/transaction persistence. |

## Known Tradeoffs

| Tradeoff | Reason | Risk | Revisit When |
| --- | --- | --- | --- |
| Backend owns all Plaid token handling | Prevents token exposure in mobile and keeps deletion centralized | More backend work before mobile can connect accounts | Plaid Link implementation starts |
| Rex consumes persisted context only | Keeps AI/chat isolated from vendor APIs | Rex may see data only after sync finishes | Real-time Plaid refresh becomes necessary |
| Shared fingerprint dedupe is simple | Works for CSV/Plaid parity and avoids duplicate rows | Some pending/authorized transactions may need stronger ids later | Plaid transaction ids and pending states are implemented |

## Open Questions

- Which Supabase tables will store Plaid item/account metadata?
- Should Plaid access tokens be encrypted directly in Supabase or stored via a secrets/KMS-backed reference?
- What sync cadence should launch use: manual, on app open, scheduled backend job, or webhook-driven?
- How should pending Plaid transactions reconcile with posted transactions?

## Acceptance Criteria

- [x] Contract defines link token, token exchange, account sync, transaction sync, dedupe, deletion, and rollback boundaries.
- [x] Mobile/backend/Rex ownership is explicit.
- [x] Plaid does not touch Rex chat, memory, dashboard UI, or CSV parser/import modules directly.
- [x] Required tests and manual QA are listed.
- [x] File-size guardrails are defined before implementation.
