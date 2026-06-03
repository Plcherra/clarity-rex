# Architecture Decision Record: Plaid Sync Architecture

Status: Accepted

Date: June 3, 2026

Owner: Pedro Martins

Related module/plan: `docs/FULL_PROJECT_11_10_POLISH_MASTER_PLAN.md` Phase 9

## Context

Clarity is moving from CSV-only financial data ingestion toward account connection through Plaid. The project recently split oversized CSV import, dashboard, financial read model, and Rex financial-context files so future Plaid work does not recreate god-files.

Plaid introduces sensitive token handling, account metadata, transaction sync, deletion obligations, sync failure states, and consent boundaries. The architecture needs to be decided before adding Plaid SDK code so implementation stays small, user-scoped, and reviewable.

Important constraints:

- Mobile must not receive or store Plaid access tokens.
- Rex must not call Plaid directly.
- Dashboard and budgets should not know whether a transaction came from CSV, Plaid, manual entry, or a future source.
- CSV and Plaid rows representing the same transaction must dedupe consistently.
- User deletion and account disconnection must be explicit and auditable.
- Solo-founder velocity matters, but not at the cost of privacy or silent failure.

## Decision

We will implement Plaid as a dedicated backend ingestion module with server-side token exchange, server-side item/account/transaction sync, shared transaction dedupe, and persisted read-model consumption.

Mobile will own Plaid Link UI and user consent initiation only. Backend will own Link token creation, public-token exchange, Plaid access-token storage, item/account sync, transaction normalization, deletion, and rollback. Rex, dashboard, budgets, and goals will consume only persisted Clarity financial data through existing read-model/context services.

## Options Considered

| Option | Pros | Cons | Decision |
| --- | --- | --- | --- |
| Backend-owned Plaid ingestion module | Strong token safety, clean deletion boundary, keeps Rex/dashboard isolated, supports jobs/webhooks later | Requires backend routes/repository before mobile Link can finish | Chosen |
| Mobile-owned Plaid access and sync | Faster initial UI prototype | Exposes sensitive token handling to app, harder deletion, harder server jobs, weaker compliance posture | Rejected |
| Add Plaid into existing CSV import service | Reuses import persistence quickly | Recreates god-file, mixes source-specific logic, harder to test Plaid separately | Rejected |
| Let Rex query Plaid directly when answering | Fresh data on demand | AI path depends on vendor calls, latency/privacy risk, hard to audit or delete | Rejected |

## Rationale

The backend-owned ingestion module best matches Clarity's compliance and maintainability needs. It keeps secrets server-side, gives deletion/disconnect workflows a single owner, and preserves the clean read-model architecture created in Phase 8.

This structure also keeps Plaid implementation incremental. We can add a skeleton service and docs now, then later add routes, a Plaid client wrapper, repositories, mappers, sync cursor handling, and tests without touching chat, memory, dashboard presentation, or CSV parsing.

## Consequences

### Positive

- Plaid access tokens never live in Flutter.
- Rex remains a consumer of persisted financial context, not an API gateway to Plaid.
- CSV and Plaid dedupe converge through one transaction identity contract.
- Plaid sync can be tested independently from UI and Rex behavior.
- Deletion/disconnect behavior is easier to verify for compliance.

### Negative

- More backend scaffolding is required before mobile Plaid Link is useful.
- A first Plaid release needs schema work for items/accounts/sync status.
- Near-real-time updates require explicit sync jobs/webhooks later.

### Neutral / Operational

- Plaid feature flags should allow disabling Link and sync separately.
- Existing CSV import remains useful and should not be removed.
- Sync status must distinguish empty data from degraded/unavailable data.

## Implementation Notes

Files or systems affected:

- `docs/clarity/plaid/MODULE_CONTRACT_PLAID_SYNC.md`
- `services/rex-api/app/services/plaid_sync_service.py`
- Future: `services/rex-api/app/routes/plaid.py`
- Future: `services/rex-api/app/services/plaid_transaction_mapper.py`
- Future: `services/rex-api/app/services/plaid_item_repository.py`
- Future: Supabase migrations for Plaid item/account/sync metadata
- Existing: `apps/mobile/lib/features/transactions/domain/transaction_fingerprint.dart`
- Existing: `apps/mobile/lib/features/finance/application/financial_read_model_service.dart`

Migration or rollout plan:

1. Add module contract, ADR, and fail-closed service skeleton.
2. Add schema migrations for Plaid items, Plaid accounts, sync cursors, and sync events.
3. Add backend route stubs with auth tests.
4. Add Plaid client wrapper and sandbox tests.
5. Add transaction mapper and dedupe tests.
6. Add mobile Plaid Link UI behind a feature flag.
7. Add manual sandbox connect/sync/disconnect QA.

Rollback plan:

1. Disable Plaid feature flag in mobile/backend config.
2. Stop scheduled/webhook sync jobs if present.
3. Preserve existing CSV/dashboard data paths.
4. Mark Plaid items inactive if sync cannot be trusted.
5. Keep deletion/disconnect routes available until user data obligations are resolved.

## Validation

How we will know the decision worked:

- Plaid work can begin without modifying Rex chat/memory internals.
- Plaid work can begin without modifying CSV parser/import modules except shared dedupe tests.
- Mobile receives only Link/public-token flow data, never server-side access tokens.
- Dashboard and Rex consume persisted financial read-model data after sync.
- Disconnect/delete tests prove user-scoped data handling.

Required tests:

- Plaid service skeleton fails closed when unconfigured.
- Link token route rejects missing auth.
- Public token exchange does not return access token to mobile.
- Plaid-vs-CSV transaction dedupe contract passes.
- Disconnect/delete cannot affect another user's Plaid item.

## Revisit Trigger

Revisit this decision when:

- Plaid webhooks become necessary for sync freshness.
- Pending transaction reconciliation needs Plaid transaction ids beyond fingerprint dedupe.
- Clarity adds a second financial-data provider.
- Token storage moves to a dedicated KMS/secrets provider.

## Follow-Up Tasks

- [ ] Add Plaid schema migration with RLS policies.
- [ ] Add `routes/plaid.py` with auth and feature-flag checks.
- [ ] Add Plaid client wrapper with sandbox configuration.
- [ ] Add account and transaction mapper modules.
- [ ] Add sync cursor and degraded-state tests.
- [ ] Add mobile Plaid Link UI only after backend route tests pass.
