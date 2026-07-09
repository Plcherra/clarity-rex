# 09 — Privacy, Legal, and Compliance

**Covers:** Subprocessor disclosure, consent alignment with product rules, encryption-at-rest documentation, third-party data flows, and audit-trail integrity from a compliance lens. Not all items block a private pilot; several block broad public marketing.

**Primary paths:** `apps/web` privacy page, durable-write confirm flows, `plaid_token_service.py`, usage event constraints, Grok/Deepgram/Google TTS integrations

---

## Phase 1 — Subprocessor disclosure

### Issue: Privacy policy omits named subprocessors (M2)

- **Severity:** Medium (compliance; maybe legal blocker for public launch)
- **Why it matters:** User data goes to Grok (x.ai), Deepgram, Google TTS, Plaid, and Supabase — generic “providers” language is weak for trust and regulation.
- **Estimated effort:** Small
- **Brief fix suggestion:** Update privacy policy to name subprocessors and purposes; confirm DPAs where required before public marketing.

### Issue: Third-party data flow inventory not user-facing (A52)

- **Severity:** Medium
- **Why it matters:** Support and legal need a clear map of what leaves the device/backend.
- **Estimated effort:** Small
- **Brief fix suggestion:** Maintain a short internal table (chat text → Grok; audio → Deepgram; TTS text → Google; bank link → Plaid; persistence → Supabase) and mirror essentials in privacy copy.

---

## Phase 2 — Consent vs product truth rules

### Issue: Memory/writes require confirm — verify UX matches policy (A53)

- **Severity:** Low–Medium (mostly positive)
- **Why it matters:** Product rules require visible, controllable saves; privacy claims must match confirm-card behavior.
- **Estimated effort:** Small (manual)
- **Brief fix suggestion:** Confirm no silent durable writes in chat/voice; Open Threads require explicit consent; Knows/Goals show saved items after apply.

### Issue: In-app consent vs privacy policy alignment (A54)

- **Severity:** Medium
- **Why it matters:** Policy may claim controls the UI does not yet expose (e.g. corrections history).
- **Estimated effort:** Small
- **Brief fix suggestion:** Align privacy wording with MVP surfaces (Knows, Goals, Open Threads, chat history search); avoid promising Corrections tab if not shipped.

---

## Phase 3 — Logging and prompt privacy (cross-link)

### Issue: Grok prompt logging privacy risk (C5 — implement in 03)

- **Severity:** Critical when enabled
- **Why it matters:** Full prompts in logs are a privacy incident waiting to happen.
- **Estimated effort:** Small
- **Brief fix suggestion:** Hard-disable in production (file 04 Phase 2); verify here as a compliance checkbox.

### Issue: Web voice JWT in URL (H3 — implement in 03)

- **Severity:** High
- **Why it matters:** Auth tokens in logs/history are a privacy and account-takeover risk.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Ticket endpoint + log redaction (file 04); treat as privacy gate for web voice.

---

## Phase 4 — Encryption and retention documentation

### Issue: Encryption at rest is platform-level only (A55)

- **Severity:** Low (industry standard)
- **Why it matters:** Chat/memory/finance lack app-layer field encryption; Plaid tokens use Fernet — users/legal may ask.
- **Estimated effort:** Small (docs)
- **Brief fix suggestion:** Document Supabase/Postgres at-rest encryption + Fernet for Plaid secrets on security/privacy page; only add field-level encryption if compliance requires it.

### Issue: Usage events correctly block sensitive metadata keys (A56)

- **Severity:** Low (positive — protect)
- **Why it matters:** DB constraints already block `prompt`, `transcript`, `plaid_access_token` in usage metadata — do not regress.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep constraint; add CI/test if missing; never log transcripts into usage.

---

## Phase 5 — Audit integrity for compliance

### Issue: Forgeable financial_audit_events (M5 — also in 01)

- **Severity:** Medium
- **Why it matters:** Self-inserted audit rows weaken dispute/compliance value.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Service-role-only inserts or validated server path (file 01 Phase 4).

### Issue: Assistant finance writes without audit (H6 — also in 01)

- **Severity:** High (trust/compliance gap)
- **Why it matters:** “Rex changed my budget” reports lack a trail.
- **Estimated effort:** Medium
- **Brief fix suggestion:** `source: 'assistant'` audit events on apply.

---

## Phase 6 — Owner PII and admin access

### Issue: Admin usage APIs + migration PII (A13, A22 — also in 02/03)

- **Severity:** High / Medium
- **Why it matters:** Owner endpoints list emails; migration notes may contain real email.
- **Estimated effort:** Small–Medium
- **Brief fix suggestion:** MFA, access audit logs, redact migration notes, consider email redaction in admin API.
