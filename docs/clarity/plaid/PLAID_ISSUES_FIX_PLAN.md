# Plaid Issues Fix Plan

This plan captures the remaining Plaid integration findings from the latest review. Issues are ordered by severity so the highest-risk production blockers are handled first.

Reference: Plaid's official webhook verification docs describe `Plaid-Verification` as a JWT header value and require retrieving the matching JWK with `/webhook_verification_key/get`, validating the JWT, enforcing freshness, and comparing the request-body SHA-256 hash.

## Issue #1: Official Plaid Webhook Verification Flow

- **Status:** Complete
- **Severity:** High
- **Current Problem:** Plaid webhook verification currently accepts any non-empty `Plaid-Verification` header.
- **Why it matters:** A spoofed webhook could incorrectly mark Plaid Items as sync requested, degraded, or disconnected.
- **Proposed Solution:** Implement Plaid's official webhook verification flow: extract the JWT from the `Plaid-Verification` header, decode the JWT header, require `alg = ES256`, fetch the matching JWK using `/webhook_verification_key/get`, verify the JWT signature and freshness, compute the SHA-256 hash of the raw webhook body, and compare it against `request_body_sha256` before processing the webhook.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `services/rex-api/app/services/plaid_webhook_service.py`
  - `services/rex-api/app/routes/plaid_webhooks.py`
  - `services/rex-api/app/services/plaid_api_client.py`
  - `services/rex-api/tests/test_plaid_webhook_routes.py`
- **Next Step:** Add a focused failing test proving that a missing, malformed, expired, or body-mismatched `Plaid-Verification` JWT is rejected.
- **Completion Note:** Added a dedicated Plaid webhook verifier, wired the webhook route to verify the exact raw request body, added `/webhook_verification_key/get` support to the Plaid client, removed the old header-presence placeholder, and covered valid JWTs, missing headers, bad signatures, expired JWTs, and body-hash mismatches in tests.

## Issue #2: Physical Device Plaid QA Still Pending

- **Status:** Ready for Pedro physical-device validation; automated preflight complete
- **Severity:** High
- **Current Problem:** Phase 7 is marked ready for Pedro physical-device validation, not complete.
- **Why it matters:** The Plaid mobile plan cannot be closed until the real iOS flow proves account creation, sync, UI refresh, and fallback behavior on device.
- **Proposed Solution:** Run the full real-device QA checklist and update the QA report with pass/fail evidence, timestamps, observed latency, and any remaining defects.
- **Files Involved:**
  - `docs/clarity/plaid/PLAID_REAL_BANK_TESTING_FIX_PLAN.md`
  - `docs/clarity/plaid/PLAID_MOBILE_REAL_ACCOUNT_QA_REPORT.md`
  - `docs/clarity/plaid/PLAID_MOBILE_AND_ACCOUNT_CONNECTION_MASTER_PLAN.md`
- **Next Step:** Re-test Bank of America connection while watching VPS logs for `/plaid/exchange-token`, account persistence, and initial sync results.
- **Completion Note:** Automated readiness was rechecked on June 10, 2026: backend Plaid tests passed, Flutter analyze passed, focused Plaid/budget/assistant truth tests passed, and the mobile release helper resolved the physical-device release command. This issue remains open until Pedro completes the real iPhone bank login and records the production lifecycle results.

## Issue #3: Plaid Disconnect And Offboarding Flow Missing

- **Severity:** Medium
- **Current Problem:** The backend has Plaid Item removal support in the API client, but no safe user-facing disconnect route or UI flow is exposed.
- **Why it matters:** Users need a reliable way to revoke bank connections, stop sync, and cleanly remove Plaid-linked account data before launch.
- **Proposed Solution:** Add an authenticated disconnect route that verifies Item ownership, calls Plaid Item remove, marks local Plaid records disconnected, and updates the Accounts UI with a calm disconnect action.
- **Files Involved:**
  - `services/rex-api/app/routes/plaid.py`
  - `services/rex-api/app/services/plaid_api_client.py`
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `apps/mobile/lib/features/accounts/presentation/`
  - `apps/mobile/lib/features/accounts/data/plaid_account_service.dart`
- **Next Step:** Define the disconnect contract and add backend route tests for owner-scoped Plaid Item removal.

## Issue #4: Plaid Webhook Sync Processing After Verified Events

- **Severity:** Medium
- **Current Problem:** `SYNC_UPDATES_AVAILABLE` currently marks metadata as sync requested but does not enqueue or run a transaction sync.
- **Why it matters:** Production data freshness would depend on manual or app-triggered sync instead of Plaid's event-driven update path.
- **Proposed Solution:** After Issue #1 is complete, process only verified Plaid webhooks and add a safe background sync path for verified `SYNC_UPDATES_AVAILABLE` events, with retry protection, rate-limit handling, and Item ownership safeguards.
- **Files Involved:**
  - `services/rex-api/app/services/plaid_sync_service.py`
  - `services/rex-api/app/services/plaid_webhook_service.py`
  - `services/rex-api/app/routes/plaid_webhooks.py`
  - `services/rex-api/tests/test_plaid_webhook_routes.py`
  - `services/rex-api/tests/test_plaid_sync_service.py`
- **Next Step:** Add a webhook test proving that a verified `SYNC_UPDATES_AVAILABLE` event schedules or invokes `sync_item` without blocking the webhook response.

## Issue #5: Exchange Token Response Does Not Return Sanitized Accounts

- **Severity:** Medium/Low
- **Current Problem:** `/plaid/exchange-token` returns account and transaction counts but returns `accounts: []`.
- **Why it matters:** The mobile app relies on a follow-up Supabase refresh, so a refresh miss can make a successful connection look empty.
- **Proposed Solution:** Return sanitized account summaries from the exchange response, including safe fields like account id, institution name, account name, mask, subtype, balance, and sync status.
- **Files Involved:**
  - `services/rex-api/app/routes/plaid.py`
  - `services/rex-api/app/services/plaid_account_service.py`
  - `services/rex-api/tests/test_plaid_exchange_route.py`
  - `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
  - `apps/mobile/lib/features/accounts/presentation/`
- **Next Step:** Update the backend exchange route test to expect sanitized account summaries after a successful initial sync.

## Issue #6: Mobile OAuth Redirect Is Hard-Coded To Production

- **Severity:** Low
- **Current Problem:** The mobile Plaid OAuth redirect detection is hard-coded to `https://api.goclarity.app/plaid/oauth`.
- **Why it matters:** Hard-coding production makes staging, local QA, and future environment changes fragile.
- **Proposed Solution:** Move the Plaid OAuth redirect URI into mobile configuration and compare incoming links against the configured value.
- **Files Involved:**
  - `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
  - `apps/mobile/lib/app/app_config.dart`
  - `apps/mobile/lib/main.dart`
  - `apps/mobile/test/plaid_link_service_test.dart`
- **Next Step:** Add a mobile config field for the Plaid redirect URI and update the Plaid link service tests to cover a configured redirect.
