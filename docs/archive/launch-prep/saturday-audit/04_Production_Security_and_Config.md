# 04 — Production Security and Config

**Covers:** Auth fail-closed behavior, prompt logging, secrets validation, Plaid encryption key separation, WebSocket JWT exposure, input limits, readiness disclosure, and RLS residual notes. Misconfiguration here can be worse than a product bug.

**Primary paths:** `supabase_auth.py`, `config.py`, `grok_prompt_logging.py`, `plaid_token_service.py`, `streaming_voice_api_web.dart`, `main.py` (`/ready`), Supabase migrations

---

## Phase 1 — Auth fail-closed

### Issue: Dev auth bypass if `APP_ENVIRONMENT` ≠ production (C4)

- **Severity:** Critical
- **Why it matters:** Missing Supabase config + typo env (e.g. `prod`) yields a fixed fake user on all authenticated routes.
- **Estimated effort:** Small
- **Brief fix suggestion:** Fail closed on any non-development environment; reject unknown `APP_ENVIRONMENT` values at startup; verify prod uses exact `production`.

### Issue: Auth smoke — unauthenticated and cross-user isolation (A15)

- **Severity:** Critical (verification)
- **Why it matters:** Confirms RLS + JWT path actually protect data in the deployed environment.
- **Estimated effort:** Small (manual)
- **Brief fix suggestion:** Unauthenticated `/chat` → 401; user A cannot read user B conversation/memory via API.

---

## Phase 2 — Prompt and sensitive logging

### Issue: `REX_LOG_GROK_PROMPT` can log full user prompts (C5)

- **Severity:** Critical (when enabled)
- **Why it matters:** Up to 12k chars of chat/memory/finance context can land in logs — privacy breach.
- **Estimated effort:** Small
- **Brief fix suggestion:** Hard-disable when `APP_ENVIRONMENT=production` regardless of env var; verify unset/false in prod.

### Issue: Sensitive data in logs — residual risk (A16)

- **Severity:** Low (mostly disciplined)
- **Why it matters:** Plaid/usage paths are careful; Grok prompt logging and JWT query params remain the real leaks.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep Plaid `_safe_user_label` patterns; ban prompt/transcript keys in usage metadata (already constrained); re-audit after Phase 2–3.

---

## Phase 3 — Secrets and boot validation

### Issue: Plaid encryption secret not required at startup (H2)

- **Severity:** High
- **Why it matters:** Tokens may encrypt with `PLAID_SECRET` fallback — bad key separation; missing secret not caught at deploy.
- **Estimated effort:** Small
- **Brief fix suggestion:** Require dedicated `PLAID_TOKEN_ENCRYPTION_SECRET` when Plaid enabled; never fall back to `PLAID_SECRET` in production.

### Issue: `SUPABASE_SERVICE_ROLE_KEY` not validated at boot (H7 partial)

- **Severity:** High
- **Why it matters:** Plaid persistence and usage inserts fail at runtime instead of deploy time.
- **Estimated effort:** Small
- **Brief fix suggestion:** Add to `production_validation_errors()` when Plaid and/or usage tracking are enabled.

### Issue: `/ready` allows Plaid unset (`required_for_ready: false`) (A17)

- **Severity:** High (ops)
- **Why it matters:** API can report ready with zero Plaid config while marketing bank connect.
- **Estimated effort:** Small
- **Brief fix suggestion:** In production, warn loudly or fail ready when Plaid is a launch feature but unset.

---

## Phase 4 — WebSocket / web token exposure

### Issue: Web voice puts JWT in WebSocket query string (H3)

- **Severity:** High
- **Why it matters:** Tokens hit proxy/CDN/access logs, referrers, and history; native uses Authorization header correctly.
- **Estimated effort:** Medium (ticket) / Small (mitigate)
- **Brief fix suggestion:** Prefer short-lived single-use WS ticket endpoint; until then, redact `access_token` query params on `/voice/stream` logs and consider deferring web voice.

### Issue: Redact `/voice/stream` query params in access logs (A18)

- **Severity:** High
- **Why it matters:** Even with tickets later, current JWT-in-URL must not be logged.
- **Estimated effort:** Small
- **Brief fix suggestion:** Configure reverse proxy / app logging to strip or hash query strings on voice WS routes.

---

## Phase 5 — Input validation and abuse limits

### Issue: Unbounded chat message length (M4)

- **Severity:** Medium
- **Why it matters:** Authenticated users can send huge payloads → Grok cost and latency DoS.
- **Estimated effort:** Small
- **Brief fix suggestion:** Pydantic `max_length` on chat message (e.g. 8–16k); cap `financial_context` / insight JSON size.

### Issue: `/ready` exposes stack config unauthenticated (L1)

- **Severity:** Medium
- **Why it matters:** Helps attackers map Grok model, TTS voice, Plaid status.
- **Estimated effort:** Small
- **Brief fix suggestion:** Public `{status: ok}`; keep detailed readiness on an internal/auth-gated endpoint.

---

## Phase 6 — RLS residual and service-role hygiene

### Issue: RLS residual — `open_threads` / `user_insights` initplan style (A19)

- **Severity:** Low (performance, not security hole)
- **Why it matters:** `auth.uid()` without initplan wrapper can hurt query plans at scale.
- **Estimated effort:** Small
- **Brief fix suggestion:** Align with lint remediation pattern `(select auth.uid())` post-launch if slow.

### Issue: `SupabaseMemoryTransport` service-role fallback if misused (A20)

- **Severity:** Low in API path / High in careless ops scripts
- **Why it matters:** Constructor without user token falls back to service role and bypasses RLS.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Require explicit `user_id`+token or `service_role=True` flag; never implicit fallback.

### Issue: Mobile secrets regression guard (A21)

- **Severity:** Low (positive today)
- **Why it matters:** Prevents future commits from shipping Grok/Plaid/service_role into Flutter.
- **Estimated effort:** Small
- **Brief fix suggestion:** CI grep for `service_role`, `PLAID_SECRET`, `GROK`, `sk-` under `apps/mobile/lib`.

---

## Phase 7 — Owner account lockdown

### Issue: Seeded owner UUID / email in migration notes (A22)

- **Severity:** Medium
- **Why it matters:** Real email in migration notes + powerful admin APIs increase insider risk.
- **Estimated effort:** Small
- **Brief fix suggestion:** Remove PII from migration comments; rotate/lock owner account with MFA (ties to file 03 Phase 4).
