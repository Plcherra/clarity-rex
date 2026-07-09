# 06 — Plaid and Finance Ops

**Covers:** Plaid production readiness, update-mode re-auth, sync/degraded states, finance assistant QA, and ops checklist. Money path failures are high-trust damage even when auth is solid.

**Primary paths:** `plaid_api_client.py`, `plaid.py` routes, `plaid_link_service.dart`, `plaid_account_header.dart`, `clarity_control_service.py`, archived finance manual test

---

## Phase 1 — Production Plaid smoke (non-negotiable)

### Issue: Production Plaid + voice infra must be verified manually (A31 / H7)

- **Severity:** High
- **Why it matters:** Code can be correct while prod keys, webhooks, or redirect URIs are wrong — users connect banks and see zero transactions.
- **Estimated effort:** Small–Medium (ops)
- **Brief fix suggestion:** Checklist: Plaid production keys; webhook URL live; iOS/Android/web redirect URIs registered; `PLAID_TOKEN_ENCRYPTION_SECRET` set; E2E link → exchange → sync → transactions on dashboard; Deepgram + Google TTS verified for voice.

### Issue: Exchange succeeds but initial sync degraded (A32)

- **Severity:** High
- **Why it matters:** Users may believe connect worked while `status: degraded` and 0 transactions.
- **Estimated effort:** Small (UX) / Medium (root cause)
- **Brief fix suggestion:** Surface degraded messaging prominently after connect; offer Resync; log sync failure reason for ops (no secrets).

---

## Phase 2 — login_required re-auth

### Issue: No update-mode re-auth for `login_required` (H1)

- **Severity:** High
- **Why it matters:** Credential expiry dead-ends users; full `connectBank()` risks duplicate institutions/accounts.
- **Estimated effort:** Large
- **Brief fix suggestion:** Plaid Link update mode (`access_token` on link token) + dedicated “Fix connection” CTA per item; test with forced `login_required`.

### Issue: Resync enabled for loginRequired without repair path (A33)

- **Severity:** Medium
- **Why it matters:** Resync button stays enabled but cannot fix auth — confusing failure loop.
- **Estimated effort:** Small
- **Brief fix suggestion:** Disable resync for `loginRequired`; replace with Fix connection CTA once update mode exists.

---

## Phase 3 — Finance assistant end-to-end QA

### Issue: Finance assistant path not proven in-repo (A34)

- **Severity:** High
- **Why it matters:** Confirm cards + truth policy exist, but archived manual checklist is unchecked.
- **Estimated effort:** Medium (manual)
- **Brief fix suggestion:** Run `docs/archive/launch-prep/07-assistant-response-finance-manual-test.md` on a real Plaid account: recategorize, budget create/update, stale-sync honesty, finance-edits toggle, voice parity.

### Issue: Assistant finance writes skip audit events (H6 — also in 01)

- **Severity:** High
- **Why it matters:** No audit trail for Rex-driven finance mutations.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Insert audit rows with `source: 'assistant'` on applied clarity actions (implement under file 01 Phase 4; verify here).

---

## Phase 4 — Web / OAuth edge cases

### Issue: Plaid OAuth fallback is static HTML (A35)

- **Severity:** Low–Medium
- **Why it matters:** Acceptable fallback, but not a full in-app resume — some banks use OAuth redirects.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Confirm web redirect `https://goclarity.app/app/` works; document OAuth resume steps for support.

### Issue: Stale l10n says web bank connect coming soon (A36)

- **Severity:** Medium
- **Why it matters:** Web Plaid JS is implemented; stale copy confuses QA and marketing.
- **Estimated effort:** Small
- **Brief fix suggestion:** Update `plaidConnectWebUnavailableMessage` usage so it only shows when `supportsAnyPlaidLink == false`; document real web limits (CSV no, background voice no).

---

## Phase 5 — Boot validation for Plaid secrets

### Issue: Plaid encryption secret + service role at startup (H2, H7 — also in 03)

- **Severity:** High
- **Why it matters:** Deploy can “succeed” without secrets needed for token storage and sync.
- **Estimated effort:** Small
- **Brief fix suggestion:** Enforce in `production_validation_errors()`; fail `/ready` or warn when Plaid is launch-critical but unset.

---

## Phase 6 — Post-connect FTUE handoff

### Issue: No bank-connect prompt in onboarding (A37 — detail in 07)

- **Severity:** Medium
- **Why it matters:** Empty dashboard after name-only onboarding increases drop-off.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Optional post-name prompt: Connect bank or Import CSV (mobile); coordinate with file 08 FTUE phases.
