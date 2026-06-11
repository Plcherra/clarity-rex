# Plaid Issues Fix Plan

Status: In Progress

Current cursor: Phase 12 - Physical Device Plaid QA

This plan captures the remaining Plaid integration findings from the latest review. It is the active Plaid cleanup queue before returning to the broader product launch plan. Work should be completed phase by phase, with focused tests and completion notes added before moving to the next phase.

Reference: Plaid's official webhook verification docs describe `Plaid-Verification` as a JWT header value and require retrieving the matching JWK with `/webhook_verification_key/get`, validating the JWT, enforcing freshness, and comparing the request-body SHA-256 hash.

## Misalignment Mapping From Latest Scan

| Finding | Covered here? | Owning phase |
| --- | --- | --- |
| `/plaid/exchange-token` returns `accounts: []`. | Yes, existing issue. | Phase 2 |
| Account names/institution display are incomplete after Plaid sync. | Partly existing, expanded here. | Phase 2 |
| Plaid accounts inherit CSV-era destructive transaction delete controls. | New issue added. | Phase 3 |
| Some Plaid transaction months can disappear because grouping filters out rows by description. | New issue added. | Phase 4 |
| Plaid account tile recent-transaction behavior conflicts with the mobile master plan. | New issue added. | Phase 5 |
| Disconnect/offboarding route and UI are missing. | Yes, existing issue. | Phase 6 |
| Verified `SYNC_UPDATES_AVAILABLE` webhook does not run or enqueue sync. | Yes, existing issue. | Phase 7 |
| Mobile OAuth redirect is hard-coded to production. | Resolved as stale plan wording after source scan. | Phase 8 |
| Real-device account cards show generic/truncated names such as `credit Account ...` and `depository Acco...`. | New issue added from physical screenshots. | Phase 9 |
| Manual sync returns 200 but date coverage/freshness is unclear, including same-day rows such as Jun 11. | New issue added from physical screenshots/logs. | Phase 10 |
| Plaid rows such as interest, Cursor, Hetzner, 11labs, GOG, AMC, and overdraft protection remain Uncategorized. | New issue added from physical screenshots. | Phase 11 |
| Physical production iPhone QA is still pending. | Yes, existing issue, moved to final gate after new real-device blockers. | Phase 12 |

## Phase 1 - Official Plaid Webhook Verification Flow

- **Status:** Complete
- **Severity:** High
- **Current Problem:** Plaid webhook verification previously accepted any non-empty `Plaid-Verification` header.
- **Why it matters:** A spoofed webhook could incorrectly mark Plaid Items as sync requested, degraded, or disconnected.
- **Proposed Solution:** Implement Plaid's official webhook verification flow: extract the JWT from the `Plaid-Verification` header, decode the JWT header, require `alg = ES256`, fetch the matching JWK using `/webhook_verification_key/get`, verify the JWT signature and freshness, compute the SHA-256 hash of the raw webhook body, and compare it against `request_body_sha256` before processing the webhook.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `services/rex-api/app/services/plaid_webhook_service.py`
  - `services/rex-api/app/routes/plaid_webhooks.py`
  - `services/rex-api/app/services/plaid_api_client.py`
  - `services/rex-api/tests/test_plaid_webhook_routes.py`
- **Acceptance Criteria:**
  - [x] Missing Plaid verification header is rejected.
  - [x] Malformed or unsigned JWT is rejected.
  - [x] Bad signature is rejected.
  - [x] Expired JWT is rejected.
  - [x] Request body hash mismatch is rejected.
- **Completion Note:** Added a dedicated Plaid webhook verifier, wired the webhook route to verify the exact raw request body, added `/webhook_verification_key/get` support to the Plaid client, removed the old header-presence placeholder, and covered valid JWTs, missing headers, bad signatures, expired JWTs, and body-hash mismatches in tests.

## Phase 2 - Exchange Response And Account Display Contract

- **Status:** Complete
- **Severity:** High
- **Current Problem:** `/plaid/exchange-token` still returns account and transaction counts but returns `accounts: []`. Separately, mobile account metadata merging reads institution, official name, mask, balance, and status from `plaid_accounts`, but does not explicitly merge the Plaid account `name` back into the account display contract.
- **Why it matters:** A successful Plaid connection can look empty or partially unnamed if the follow-up Supabase refresh misses, if account metadata is incomplete, or if UI needs the immediate exchange response to render success context.
- **Proposed Solution:** Return sanitized account summaries from exchange after initial sync, including linked account id, Plaid item record id, institution name, display account name, official name, mask, type/subtype, balance, available balance, and sync status. Align mobile account parsing/display so connected accounts consistently show a useful account name and institution without exposing sensitive identifiers.
- **Files Involved:**
  - `services/rex-api/app/routes/plaid.py`
  - `services/rex-api/app/services/plaid_account_service.py`
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `services/rex-api/tests/test_plaid_exchange_route.py`
  - `apps/mobile/lib/features/accounts/data/account_service.dart`
  - `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
  - `apps/mobile/lib/features/accounts/presentation/`
  - `apps/mobile/test/plaid_link_service_test.dart`
  - `apps/mobile/test/plaid_account_service_test.dart`
- **Acceptance Criteria:**
  - [x] Exchange response includes sanitized account summaries after successful sync.
  - [x] Exchange response never includes access tokens, account numbers, or raw Plaid payloads.
  - [x] Mobile can show success context from the exchange response even before the next Supabase refresh.
  - [x] Connected account rows display account name, institution, mask, status, and balances when available.
  - [x] Focused backend and mobile tests cover the sanitized account contract.
- **Completion Note:** Added sanitized linked-account summaries to `/plaid/exchange-token` after successful initial sync, kept raw Plaid account identifiers and tokens out of the response, added mobile parsing for the immediate account-summary contract, and updated account metadata merging so Plaid account names feed the displayed account name. Verified with backend Plaid tests, mobile Plaid tests, and Flutter analyze.

## Phase 3 - Protect Plaid Data From CSV-Era Destructive Controls

- **Status:** Complete
- **Severity:** High
- **Current Problem:** The account/month detail flow still exposes CSV-era destructive controls such as "Delete this month" based only on visible account/month rows. It does not appear to guard against Plaid-synced rows or Plaid-connected accounts.
- **Why it matters:** Plaid data is synced source data, not a one-off imported file. Deleting a Plaid month locally can create sync confusion, hide legitimate financial history, and make the next resync behavior unclear.
- **Proposed Solution:** Gate month/account transaction deletion by source. Keep CSV upload deletion for CSV imports, but do not show destructive local month deletion for Plaid-synced rows. If a Plaid account needs removal, route users through the explicit disconnect/offboarding flow in Phase 6.
- **Files Involved:**
  - `apps/mobile/lib/features/dashboard/presentation/month_detail_screen.dart`
  - `apps/mobile/lib/app/ui_dependencies.dart`
  - `apps/mobile/lib/features/transactions/application/transaction_workflow_service.dart`
  - `apps/mobile/lib/features/accounts/presentation/account_detail_screen.dart`
  - `apps/mobile/test/`
- **Acceptance Criteria:**
  - [x] "Delete this month" does not appear for Plaid-only month groups.
  - [x] Mixed Plaid/CSV months do not allow accidental deletion of Plaid rows through CSV controls.
  - [x] CSV upload deletion remains available for CSV import batches.
  - [x] User-facing copy points Plaid users to disconnect/resync instead of local deletion.
  - [x] Tests cover Plaid-only, CSV-only, and mixed-source month detail behavior.
- **Completion Note:** Added a source-aware month deletion policy for month detail, hid month and row deletion controls whenever visible rows include Plaid transactions, added a Plaid protection notice that points users to resync or disconnect instead of local deletion, guarded transaction workflow single deletes from Plaid rows, and made date-range deletion skip Plaid rows even when mixed with local rows. Verified with month deletion policy tests, dashboard grouping tests, Plaid mobile tests, financial read-model tests, and Flutter analyze.

## Phase 4 - Transaction Month Grouping And Plaid Row Visibility

- **Status:** Complete
- **Severity:** Medium
- **Current Problem:** Month grouping uses the CSV-era bank statement row filter and drops rows when the description contains broad words like `balance`. That can hide legitimate Plaid rows such as balance transfers or bank descriptions containing balance-related text.
- **Why it matters:** Users can see "not every month" or missing activity even when transactions were fetched and stored correctly.
- **Proposed Solution:** Split CSV statement-summary filtering from Plaid transaction visibility. Continue filtering CSV summary/balance lines where appropriate, but preserve Plaid-sourced transaction rows unless they are explicitly removed or otherwise excluded by a clear Plaid-safe rule.
- **Files Involved:**
  - `apps/mobile/lib/features/transactions/domain/bank_statement_monthly.dart`
  - `apps/mobile/lib/features/dashboard/domain/dashboard_snapshot.dart`
  - `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_transactions.dart`
  - `apps/mobile/test/dashboard_transaction_groups_test.dart`
  - `apps/mobile/test/financial_read_model_service_test.dart`
- **Acceptance Criteria:**
  - [x] Plaid rows with descriptions containing `balance` still appear in month groups.
  - [x] CSV summary/balance rows remain filtered out where they are generated by statement imports.
  - [x] Month group counts match visible transaction rows after filters are cleared.
  - [x] Pending Plaid rows are visible in transaction lists but excluded from settled rollups.
  - [x] Tests cover Plaid row visibility and CSV summary filtering separately.
- **Completion Note:** Made month grouping source-aware so Plaid transactions bypass only the CSV summary-description filter while still rejecting empty descriptions and invalid amounts. Added tests proving Plaid `balance transfer` rows remain visible, CSV balance/summary rows stay filtered, and pending Plaid rows remain visible in month groups while existing dashboard rollups continue excluding pending rows. Verified with bank statement monthly tests, dashboard transaction grouping tests, financial read-model tests, Plaid mobile tests, and Flutter analyze.

## Phase 5 - Plaid Account Tile Transaction Display Contract

- **Status:** Complete
- **Severity:** Medium
- **Current Problem:** The mobile Plaid master plan says Plaid account tiles show recent synced transactions, and `AccountOverviewItem` still computes latest transactions. The current `PlaidAccountTile` intentionally hides recent transactions, and tests assert that the preview remains hidden.
- **Why it matters:** The plan, code, and tests disagree. That makes it unclear whether transactions are supposed to appear on account tiles or only in account detail/transaction browsing.
- **Proposed Solution:** Decide and enforce one product contract. Either show a compact, source-safe recent-transaction preview on Plaid account tiles, or remove the dead preview plumbing and update the Plaid mobile master plan to say account tiles only show account status/balances while transactions live in detail screens.
- **Files Involved:**
  - `docs/clarity/plaid/PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
  - `apps/mobile/lib/app/ui_dependencies.dart`
  - `apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_tile.dart`
  - `apps/mobile/lib/features/accounts/presentation/widgets/plaid_recent_transactions.dart`
  - `apps/mobile/test/plaid_account_tile_test.dart`
- **Acceptance Criteria:**
  - [x] Plan, code, and tests agree on whether Plaid account tiles show transaction previews.
  - [x] Plaid account tiles intentionally do not show transaction previews.
  - [x] Unused transaction-preview plumbing is removed.
  - [x] Account detail and dashboard transaction views remain the canonical transaction browsing surfaces.
- **Completion Note:** Chose the launch contract that Plaid account tiles stay compact and show account state only: status, institution, mask, balances, and sync controls. Removed `AccountOverviewItem.recentTransactions` computation and the unused `PlaidRecentTransactions` widget, kept tile tests asserting no transaction preview appears, and updated Plaid master-plan and real-bank QA wording so transaction browsing belongs to account detail and dashboard transaction views. Verified with focused Plaid mobile tests and Flutter analyze.

## Phase 6 - Plaid Disconnect And Offboarding Flow

- **Status:** Complete
- **Severity:** Medium
- **Current Problem:** The backend has Plaid Item removal support in the API client, but no safe user-facing disconnect route or UI flow is exposed.
- **Why it matters:** Users need a reliable way to revoke bank connections, stop sync, and cleanly remove or deactivate Plaid-linked account data before launch.
- **Proposed Solution:** Add an authenticated disconnect route that verifies Item ownership, calls Plaid Item remove, marks local Plaid records disconnected, and updates the Accounts UI with a calm disconnect action. The behavior must match the retention/deletion policy: disconnect stops future sync, while deletion requests are handled by the documented deletion workflow.
- **Files Involved:**
  - `services/rex-api/app/routes/plaid.py`
  - `services/rex-api/app/services/plaid_api_client.py`
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `services/rex-api/tests/test_plaid_routes.py`
  - `services/rex-api/tests/test_plaid_sync_service.py`
  - `apps/mobile/lib/features/accounts/presentation/`
  - `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`
- **Acceptance Criteria:**
  - [x] Authenticated user can disconnect only their own Plaid item.
  - [x] Backend calls Plaid item removal and handles Plaid failures safely.
  - [x] Local Plaid item/account status changes to disconnected without exposing tokens.
  - [x] Mobile shows a clear disconnect action and confirmation.
  - [x] Disconnected accounts do not continue to offer resync as if active.
  - [x] Backend and mobile tests cover owner scoping and user-visible states.
- **Completion Note:** Added `POST /plaid/disconnect-item/{item_id}` with authenticated owner scoping, Plaid `/item/remove` invocation, and safe response metadata only. Added owner-scoped secret loading and local offboarding updates for `plaid_items`, `plaid_accounts`, and linked `accounts.sync_status`. Mobile now exposes a disconnect API method, a Plaid tile disconnect action with confirmation, disconnected status handling, and refresh guards so disconnected items are not resynced as active. Verified with backend Plaid route/sync/API tests, the full backend Plaid test sweep, mobile Plaid service/tile/link tests, and Flutter analyze.

## Phase 7 - Verified Webhook Sync Processing

- **Status:** Complete
- **Severity:** Medium
- **Current Problem:** `SYNC_UPDATES_AVAILABLE` currently marks metadata as sync requested but does not enqueue or run a transaction sync.
- **Why it matters:** Production data freshness would depend on manual or app-triggered sync instead of Plaid's event-driven update path.
- **Proposed Solution:** Process only verified Plaid webhooks and add a safe background sync path for verified `SYNC_UPDATES_AVAILABLE` events, with retry protection, rate-limit handling, and Item ownership safeguards. The webhook response should remain quick and secret-free.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `services/rex-api/app/services/plaid_webhook_service.py`
  - `services/rex-api/app/routes/plaid_webhooks.py`
  - `services/rex-api/tests/test_plaid_webhook_routes.py`
  - `services/rex-api/tests/test_plaid_sync_service.py`
- **Acceptance Criteria:**
  - [x] Verified `SYNC_UPDATES_AVAILABLE` schedules or invokes item sync safely.
  - [x] Webhook response does not block on long sync work.
  - [x] Rate-limited sync marks a retryable/degraded state without losing cursor safety.
  - [x] Unverified webhooks cannot trigger sync.
  - [x] Tests cover verified event, invalid verification, sync failure, and response shape.
- **Completion Note:** Added a webhook-triggered sync path for verified `SYNC_UPDATES_AVAILABLE` events. The webhook route still verifies the exact request first and returns the same quick, secret-free response while FastAPI background processing handles the work. The sync service now records the webhook receipt, resolves non-disconnected local Plaid items by Plaid's external item id, invokes `sync_item` for each syncable item, and marks rate-limited or failed sync attempts as degraded with retry metadata instead of throwing out of the background path. Added tests for verified sync invocation, invalid verification not triggering processing, rate-limited retryable degradation, non-rate sync degradation, and response shape. Verified with the backend Plaid test sweep.

## Phase 8 - Mobile OAuth Redirect Configuration

- **Status:** Complete
- **Severity:** Low
- **Current Problem:** The plan still described an older mobile OAuth implementation where Dart listened for `https://api.goclarity.app/plaid/oauth` and compared incoming links against a hard-coded production redirect URI. The current mobile source no longer has that Dart redirect matcher.
- **Why it matters:** Leaving stale redirect-handling instructions in the active launch plan would send manual review toward a nonexistent code path and could cause unnecessary mobile configuration work.
- **Proposed Solution:** Treat Plaid OAuth redirect configuration as backend-owned for Link token creation and native-owned for iOS Universal Link continuation. The backend already reads `PLAID_REDIRECT_URI` and sends it to Plaid for iOS Link tokens only. The iOS app keeps the production Associated Domain entitlement for the production bundle, and the native LinkKit bridge owns Plaid Link success/exit/event callbacks without a Dart URL comparison layer.
- **Files Involved:**
  - `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
  - `apps/mobile/ios/Runner/AppDelegate.swift`
  - `apps/mobile/ios/Runner/SceneDelegate.swift`
  - `apps/mobile/ios/Runner/Runner.entitlements`
  - `services/rex-api/app/services/plaid_api_client.py`
  - `services/rex-api/tests/test_plaid_api_client.py`
  - `apps/mobile/test/plaid_link_service_test.dart`
- **Acceptance Criteria:**
  - [x] Source scan confirms mobile Dart no longer hard-codes or compares `https://api.goclarity.app/plaid/oauth`.
  - [x] Backend Link token creation reads `PLAID_REDIRECT_URI` from configuration and sends it for iOS.
  - [x] Backend Link token creation does not send `redirect_uri` for Android.
  - [x] iOS Associated Domains remain explicit for the production Universal Link host.
  - [x] Docs describe LinkKit/native callback ownership instead of stale Dart incoming-link matching.
- **Completion Note:** Re-scanned the mobile Plaid source and confirmed there is no Dart incoming-link redirect matcher or `resumeAfterTermination` path. Current iOS code uses a native `PlaidLinkBridge` with LinkKit, while App/Scene delegate Universal Link hooks call into the bridge and defer continuation to LinkKit. Backend configuration remains the source of truth for Plaid `redirect_uri` during iOS Link token creation, with tests proving iOS receives the configured redirect URI and Android does not. Updated the active issue plan and related QA docs to remove the stale hard-coded mobile matcher requirement. Verified with mobile Plaid tests, Flutter analyze, backend Plaid tests, and `git diff --check`.

## Phase 9 - Real Device Account Identity And Account Card UX

- **Status:** Complete
- **Severity:** High
- **Current Problem:** Real-device account cards and detail headers can show generic Plaid labels such as `credit Account ...`, `depository Acco...`, or `depository Account 3279`, making it hard to identify the bank, account type, and account mask. The screenshots also showed old account-card transaction previews, which local Phase 5 code has already removed but needs to be confirmed in a fresh build.
- **Why it matters:** Plaid accounts are the primary navigation surface. Users must be able to quickly identify Capital One Checking vs Savings vs Credit Card before trusting transactions, budgets, or Assistant answers.
- **Proposed Solution:** Compose safe display names from institution, account subtype/type, and mask whenever Plaid's `name` or `official_name` is generic. Apply the repair in backend persistence and mobile display so old stored rows and future syncs both render clearly. Keep account cards compact and account-only; transaction browsing remains in detail/dashboard surfaces.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_account_service.py`
  - `services/rex-api/tests/test_plaid_sync_service.py`
  - `apps/mobile/lib/core/models/account.dart`
  - `apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_header.dart`
  - `apps/mobile/test/plaid_account_tile_test.dart`
- **Acceptance Criteria:**
  - [x] Generic Plaid labels are replaced with institution/type titles such as `Capital One Checking`, `Capital One Savings`, or `Bank of America Credit Card`.
  - [x] Account cards show institution, type, mask, status, balance/available balance, and last synced metadata without requiring transaction previews.
  - [x] Older stored generic rows are repaired by mobile display logic before the next backend sync.
  - [x] Account card tests cover generic Plaid label repair and no transaction previews.
- **Completion Note:** Backend account sync now composes safe names from institution, subtype/type, and mask when Plaid gives generic names like `depository Account 3279` or `credit Account 9876`. Mobile account models repair existing stored generic rows through `displayName`/`displaySubtitle`, and account cards/detail titles/filters/prompts use those repaired labels. A follow-up real-device pass refined the hierarchy so the title is institution plus account type while Plaid product names such as `360 Performance Savings`, `Adv Plus Banking`, or `Customized Cash Rewards` move to supporting detail with the mask. Account-card tests cover generic-name repair, product-name hierarchy, and hidden transaction previews.

## Phase 10 - Plaid Sync Coverage And Freshness Contract

- **Status:** Complete
- **Severity:** High
- **Current Problem:** Physical logs show manual `/plaid/sync-item/{item}` calls returning 200, but the UI may still show a history range like Mar 19, 2026 - Jun 10, 2026 for one account while today is Jun 11, 2026. It is unclear whether Plaid has not returned current-day/pending rows yet, whether Clarity stored them but filters them, or whether the user expects a longer history window than the Item currently provides.
- **Why it matters:** A finance app cannot feel launch-ready if users cannot tell whether Plaid sync is fresh or whether months/transactions are missing.
- **Proposed Solution:** Treat `/transactions/sync` as the source of truth for the Plaid-provided historical window and do not impose a local 4-month cap. Record sync page counts, added/modified/removed counts, pending counts, and min/max returned dates in backend logs so device QA can distinguish Plaid availability from Clarity filtering. Product target remains the maximum Plaid-permitted history for the connected Item; any 24-month expectation must be verified against Plaid product configuration and institution support.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_transaction_sync.py`
  - `docs/clarity/plaid/PLAID_MOBILE_REAL_ACCOUNT_QA_REPORT.md`
  - `docs/clarity/plaid/PLAID_REAL_BANK_TESTING_FIX_PLAN.md`
- **Acceptance Criteria:**
  - [x] Backend logs each sync completion with pages, stored counts, pending count, min date, and max date.
  - [x] QA can compare backend returned date coverage against mobile visible date coverage.
  - [x] The app documents that Clarity stores all Plaid-synced history returned by `/transactions/sync`, with no local month cap.
  - [ ] The QA report records whether same-day rows are pending, posted, unavailable from Plaid, or filtered by Clarity.
- **Completion Note:** Added a backend sync completion log with page count, added/modified/removed counts, pending count, and returned min/max transaction dates. The current device log already showed manual sync route success, so the remaining Jun 11 question is now a Phase 12 device QA check: compare the new backend date-range log against the visible mobile history range.

## Phase 11 - Plaid Merchant Categorization Coverage

- **Status:** Complete
- **Severity:** High
- **Current Problem:** Real-device transactions include obvious uncategorized rows: interest, Cursor AI, Hetzner/Hasner, 11labs, GOG.com, AMC, overdraft protection, and common restaurant rows. The AI assistant exists, but Plaid sync currently relies on deterministic Plaid/PFC and keyword mapping before any AI fallback.
- **Why it matters:** Budgets and category views are only useful if routine Plaid transactions land in sensible categories by default.
- **Proposed Solution:** Expand deterministic Plaid category mapping for common Plaid Personal Finance Categories and high-confidence merchant keywords first. Run a small post-sync backfill for existing Plaid rows that still have `category_id` null, because cursor sync may not resend already-stored transactions. Keep ambiguous rows uncategorized until user rules or an AI-assisted categorization queue exists, but remove the obvious misses called out by real-device QA.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_category_mapper.py`
  - `services/rex-api/tests/test_plaid_category_mapper.py`
  - `services/rex-api/tests/test_plaid_transaction_sync.py`
- **Acceptance Criteria:**
  - [x] Interest income and credit-card interest charges map to income/fee categories.
  - [x] Cursor, Hetzner/Hasner, 11labs, and common digital bills map to Subscriptions.
  - [x] GOG and AMC map to Shopping/Entertainment.
  - [x] Overdraft protection/account transfers map to transfer categories.
  - [x] Existing uncategorized Plaid rows are backfilled after sync when the deterministic mapper can classify them.
  - [x] Tests cover the exact real-device uncategorized examples.
- **Completion Note:** Expanded deterministic Plaid categorization for additional Plaid Personal Finance Categories and real-device merchant examples: interest, Cursor, Hetzner/Hasner, 11labs, GOG, AMC, overdraft/account transfers, and TST/Bom Dough rows. Added a post-sync backfill for existing Plaid rows without categories, plus focused mapper/backfill tests for the exact screenshot examples.

## Phase 12 - Physical Device Plaid QA

- **Status:** Ready after Phases 9-11 pass focused verification
- **Severity:** High
- **Current Problem:** The Plaid mobile plan cannot be closed until the real iOS flow proves account creation, sync, UI refresh, fallback behavior, Assistant truth, and disconnect/offboarding on device.
- **Why it matters:** Mocked tests and automated preflight cannot prove a real bank OAuth lifecycle, production callback behavior, or private-account UI behavior.
- **Proposed Solution:** Run the full real-device QA checklist and update the QA report with pass/fail evidence, timestamps, observed latency, sanitized counts, and any remaining defects.
- **Files Involved:**
  - `docs/clarity/plaid/PLAID_REAL_BANK_TESTING_FIX_PLAN.md`
  - `docs/clarity/plaid/PLAID_MOBILE_REAL_ACCOUNT_QA_REPORT.md`
  - `docs/clarity/plaid/PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
- **Acceptance Criteria:**
  - [ ] Real bank connection reaches Plaid success and backend `/plaid/exchange-token`.
  - [ ] Connected accounts show names, institutions, masks, status, balances, and last synced timestamps.
  - [ ] Transactions display across all available synced months.
  - [ ] Pending/posted behavior matches the UI rule.
  - [ ] Manual resync does not create duplicate UI noise.
  - [ ] Disconnect/offboarding flow behaves as documented.
  - [ ] CSV fallback remains available and warns about duplicate risk.
  - [ ] Assistant answers from the same Plaid-backed data visible in Clarity.
  - [ ] QA report records sanitized counts and any ship/no-ship decision.
- **Next Step:** After Phases 9-11 pass, install a fresh build and re-test Bank of America/Capital One connections while watching VPS logs for `/plaid/exchange-token`, account persistence, sync date coverage, webhook behavior, categorization, and disconnect behavior.

## Verification Commands

Backend:

```bash
cd services/rex-api
./.venv/bin/python -m pytest -q tests/test_plaid_*.py
git diff --check
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test test/plaid*
flutter test test/budget_cleanup_service_test.dart test/assistant_financial_context_service_test.dart test/financial_integration_contracts_test.dart
```

Device release:

```bash
VPS_SSH_TARGET=clarity ./scripts/mobile_release_run.sh
```

VPS live log:

```bash
ssh clarity
sudo journalctl -u clarity-rex -f
```

Expected successful Plaid log sequence:

```text
POST /plaid/link-token
POST /plaid/exchange-token
Plaid public token exchange completed ... accounts=...
```
