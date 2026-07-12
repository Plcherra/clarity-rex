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
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Known envs are only `development` | `production` (`KNOWN_APP_ENVIRONMENTS`). Auth fake user only when `allows_unauthenticated_dev_user` (development). Unknown values (e.g. `prod`, `staging`) → 503 on auth + boot `RuntimeError` via `startup_validation_errors()`. Deploy template already uses `APP_ENVIRONMENT=production`.

### Issue: Auth smoke — unauthenticated and cross-user isolation (A15)

- **Severity:** Critical (verification)
- **Why it matters:** Confirms RLS + JWT path actually protect data in the deployed environment.
- **Estimated effort:** Small (manual)
- **Brief fix suggestion:** Unauthenticated `/chat` → 401; user A cannot read user B conversation/memory via API.
- **Status:** ⬜ Manual smoke (pre-launch)
- **Notes:** Code path: missing token with Supabase configured → 401. Cross-user isolation relies on RLS + user-scoped repositories.

**VPS smoke (run after deploy with `APP_ENVIRONMENT=production`):**

```bash
# 1) Unauthenticated chat must be 401
curl -sS -o /tmp/chat_noauth.json -w "%{http_code}\n" \
  -X POST https://api.goclarity.app/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}'
# expect: 401

# 2) Ready is public status-only (no model/Plaid details)
curl -sS https://api.goclarity.app/ready
# expect: {"status":"ok","service":"clarity-rex"}

# 3) Cross-user: with user A access token, try user B conversation id
curl -sS -o /tmp/cross_user.json -w "%{http_code}\n" \
  -H "Authorization: Bearer $USER_A_ACCESS_TOKEN" \
  "https://api.goclarity.app/conversations/$USER_B_CONVERSATION_ID"
# expect: 404 or empty/forbidden — never user B content
```

---

## Phase 2 — Prompt and sensitive logging

### Issue: `REX_LOG_GROK_PROMPT` can log full user prompts (C5)

- **Severity:** Critical (when enabled)
- **Why it matters:** Up to 12k chars of chat/memory/finance context can land in logs — privacy breach.
- **Estimated effort:** Small
- **Brief fix suggestion:** Hard-disable when `APP_ENVIRONMENT=production` regardless of env var; verify unset/false in prod.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** `grok_prompt_logging_enabled()` returns False when `is_production`, even if `REX_LOG_GROK_PROMPT=true`. Covered by `tests/test_grok_prompt_logging.py`.

### Issue: Sensitive data in logs — residual risk (A16)

- **Severity:** Low (mostly disciplined)
- **Why it matters:** Plaid/usage paths are careful; Grok prompt logging and JWT query params remain the real leaks.
- **Estimated effort:** Small
- **Brief fix suggestion:** Keep Plaid `_safe_user_label` patterns; ban prompt/transcript keys in usage metadata (already constrained); re-audit after Phase 2–3.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Re-audit: product events remain metadata-only; prompt logging hard-disabled in prod; Phase 4 redacts JWT/ticket query params in access logs + nginx `$uri` (no query) for `/voice/stream`.

---

## Phase 3 — Secrets and boot validation

### Issue: Plaid encryption secret not required at startup (H2)

- **Severity:** High
- **Why it matters:** Tokens may encrypt with `PLAID_SECRET` fallback — bad key separation; missing secret not caught at deploy.
- **Estimated effort:** Small
- **Brief fix suggestion:** Require dedicated `PLAID_TOKEN_ENCRYPTION_SECRET` when Plaid enabled; never fall back to `PLAID_SECRET` in production.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Production boot requires `PLAID_TOKEN_ENCRYPTION_SECRET` when any Plaid credential is present. `PlaidTokenService` never falls back to `PLAID_SECRET` in production (dev-only fallback remains).

### Issue: `SUPABASE_SERVICE_ROLE_KEY` not validated at boot (H7 partial)

- **Severity:** High
- **Why it matters:** Plaid persistence and usage inserts fail at runtime instead of deploy time.
- **Estimated effort:** Small
- **Brief fix suggestion:** Add to `production_validation_errors()` when Plaid and/or usage tracking are enabled.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Production always requires `SUPABASE_SERVICE_ROLE_KEY` (usage + Plaid persistence).

### Issue: `/ready` allows Plaid unset (`required_for_ready: false`) (A17)

- **Severity:** High (ops)
- **Why it matters:** API can report ready with zero Plaid config while marketing bank connect.
- **Estimated effort:** Small
- **Brief fix suggestion:** In production, warn loudly or fail ready when Plaid is a launch feature but unset.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Detailed readiness moved to auth-gated `/ready/details`; in production Plaid is `required_for_ready=true` so status is `degraded` when unset.

---

## Phase 4 — WebSocket / web token exposure

### Issue: Web voice puts JWT in WebSocket query string (H3)

- **Severity:** High
- **Why it matters:** Tokens hit proxy/CDN/access logs, referrers, and history; native uses Authorization header correctly.
- **Estimated effort:** Medium (ticket) / Small (mitigate)
- **Brief fix suggestion:** Prefer short-lived single-use WS ticket endpoint; until then, redact `access_token` query params on `/voice/stream` logs and consider deferring web voice.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Added `POST /voice/stream/ticket` (60s single-use). Web client (`streaming_voice_api_web.dart`) fetches ticket over HTTPS with Authorization header, then connects WS with `ticket` only — JWT stays server-side in the ticket store. Legacy `access_token` query still accepted for compatibility but should not be used by web.

### Issue: Redact `/voice/stream` query params in access logs (A18)

- **Severity:** High
- **Why it matters:** Even with tickets later, current JWT-in-URL must not be logged.
- **Estimated effort:** Small
- **Brief fix suggestion:** Configure reverse proxy / app logging to strip or hash query strings on voice WS routes.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** `SensitiveQueryLogFilter` installed on uvicorn loggers; nginx template logs `$uri` (path only) for `/voice/stream`.

---

## Phase 5 — Input validation and abuse limits

### Issue: Unbounded chat message length (M4)

- **Severity:** Medium
- **Why it matters:** Authenticated users can send huge payloads → Grok cost and latency DoS.
- **Estimated effort:** Small
- **Brief fix suggestion:** Pydantic `max_length` on chat message (e.g. 8–16k); cap `financial_context` / insight JSON size.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Chat message max 16k; financial_context 32k serialized; write_confirmation 8k; insights sync payloads capped similarly.

### Issue: `/ready` exposes stack config unauthenticated (L1)

- **Severity:** Medium
- **Why it matters:** Helps attackers map Grok model, TTS voice, Plaid status.
- **Estimated effort:** Small
- **Brief fix suggestion:** Public `{status: ok}`; keep detailed readiness on an internal/auth-gated endpoint.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** Public `GET /ready` → `{status, service}` only. `GET /ready/details` requires auth.

---

## Phase 6 — RLS residual and service-role hygiene

### Issue: RLS residual — `open_threads` / `user_insights` initplan style (A19)

- **Severity:** Low (performance, not security hole)
- **Why it matters:** `auth.uid()` without initplan wrapper can hurt query plans at scale.
- **Estimated effort:** Small
- **Brief fix suggestion:** Align with lint remediation pattern `(select auth.uid())` post-launch if slow.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** `user_insights` already had initplan migration. Added `20260712000100_open_threads_rls_initplan.sql`.

### Issue: `SupabaseMemoryTransport` service-role fallback if misused (A20)

- **Severity:** Low in API path / High in careless ops scripts
- **Why it matters:** Constructor without user token falls back to service role and bypasses RLS.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Require explicit `user_id`+token or `service_role=True` flag; never implicit fallback.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** `SupabaseMemoryService` requires `access_token` or `use_service_role=True`. Transport no longer falls back implicitly. Ops scripts updated to pass `use_service_role=True`.

### Issue: Mobile secrets regression guard (A21)

- **Severity:** Low (positive today)
- **Why it matters:** Prevents future commits from shipping Grok/Plaid/service_role into Flutter.
- **Estimated effort:** Small
- **Brief fix suggestion:** CI grep for `service_role`, `PLAID_SECRET`, `GROK`, `sk-` under `apps/mobile/lib`.
- **Status:** ✅ Done (2026-07-12)
- **Notes:** CI mobile job greps `apps/mobile/lib` for `service_role|PLAID_SECRET|GROK_API_KEY|GROK_API|sk-…` and fails on match.

---

## Phase 7 — Owner account lockdown

### Issue: Seeded owner UUID / email in migration notes (A22)

- **Severity:** Medium
- **Why it matters:** Real email in migration notes + powerful admin APIs increase insider risk.
- **Estimated effort:** Small
- **Brief fix suggestion:** Remove PII from migration comments; rotate/lock owner account with MFA (ties to file 03 Phase 4).
- **Status:** ✅ Done (2026-07-12) — code/notes; MFA already confirmed on accounts
- **Notes:** Scrubbed PII from `20260626000200_seed_usage_owner.sql`; added `20260712000200_scrub_owner_admin_note_pii.sql` for live DB. Owner UUID retained (required for access). MFA: verify-only — already done on accounts per Plan 03.
