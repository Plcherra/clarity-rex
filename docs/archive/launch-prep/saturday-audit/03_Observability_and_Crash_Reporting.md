# 03 — Observability and Crash Reporting

**Status:** DONE (code + automated tests 2026-07-12). Ops still must set `SENTRY_DSN` in prod and enable MFA on the usage-owner account.

**Covers:** Production blindness — crash reporting, product analytics, and the minimum event set needed to diagnose Saturday failures. Do this immediately after truth-rule fixes so every subsequent smoke test is visible in telemetry.

**Primary paths:** `apps/mobile/lib/app/bootstrap.dart`, `apps/mobile/pubspec.yaml`, `services/rex-api/app/main.py`

**Runbook:** [`03_Observability_Launch_Runbook.md`](./03_Observability_Launch_Runbook.md)

---

## Phase 1 — Crash reporting baseline — DONE

### Issue: No crash reporting or analytics (C1) — DONE

- **Severity:** Critical
- **Why it matters:** Saturday crashes, ANRs, Plaid failures, and voice drop-offs are invisible without a SDK.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Add Sentry (or Firebase Crashlytics) to Flutter + FastAPI; wire `FlutterError.onError` and zone errors in `bootstrap.dart`; capture unhandled API exceptions server-side.
- **Done in:**
  - Flutter: `sentry_flutter` + `ClarityCrashReporting` (env/`--dart-define` DSN); `bootstrap.dart` runs via Sentry/`PlatformDispatcher` handlers.
  - FastAPI: `sentry-sdk[fastapi]` + `sentry_setup.init_sentry`; HTTP middleware captures unhandled exceptions and emits `api_5xx`.
  - Optional DSN documented in both `.env.example` files; `/ready` reports Sentry configured (non-blocking).

---

## Phase 2 — Critical product events — DONE

### Issue: No structured events for save / voice / API failures (A10) — DONE

- **Severity:** High
- **Why it matters:** Crashes alone do not explain “confirm failed” or “voice stream died” without breadcrumbs.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Emit minimal events (no PII/transcripts): `write_confirmation_result`, `voice_stream_error`, `api_5xx`, `plaid_exchange_result`, `plaid_sync_degraded`.
- **Done in:** `product_events.py` + wiring in durable-write results, voice stream errors, API middleware, Plaid exchange route; mobile mirrors via `ClarityProductEvents` (confirm / voice fail / API 5xx).

### Issue: Apply failures lack ops signal (A11) — DONE

- **Severity:** Medium
- **Why it matters:** Backend `except Exception: return applied False` paths leave no alertable metric.
- **Estimated effort:** Small
- **Brief fix suggestion:** Log structured error codes for durable-write apply failures; optionally Sentry breadcrumb with action type (not content).
- **Done in:** `durable_write_apply_failures.py` → `emit_durable_write_apply_failed` (action/snapshot type + reason only) + Sentry breadcrumb.

---

## Phase 3 — Discipline / silent-degrade alerts — DONE

### Issue: Memory discipline silent degrade has no metric (A12) — DONE

- **Severity:** Medium
- **Why it matters:** Empty-list fallbacks in discipline hide duplicate-detection outages.
- **Estimated effort:** Small
- **Brief fix suggestion:** Counter/metric when `_safe_list` fails; alert if rate spikes.
- **Done in:** `safe_discipline_list` emits `discipline_list_degraded` + in-process counter (fail-closed path from plan 01 retained).

---

## Phase 4 — Owner / admin access audit — DONE

### Issue: Owner usage APIs expose all user emails (A13) — DONE

- **Severity:** High (insider / compromised owner)
- **Why it matters:** Compromised owner JWT = platform-wide email + usage exposure.
- **Estimated effort:** Small (ops) / Medium (code)
- **Brief fix suggestion:** MFA on owner account; audit-log admin endpoint access; consider redacting emails in admin responses.
- **Done in:** `owner_usage_privacy.py` + `/usage/admin/*` audit logs; emails redacted by default (`include_emails=true` opt-in). **Ops:** MFA on usage-owner account required (documented in runbook).

---

## Phase 5 — Launch-day monitoring runbook — DONE

### Issue: No documented Saturday watch list (A14) — DONE

- **Severity:** Medium
- **Why it matters:** Telemetry without a watch plan still leaves the team reactive.
- **Estimated effort:** Small
- **Brief fix suggestion:** One-page runbook: Sentry project URLs, alert thresholds, who watches voice/Plaid/chat error rates for first 48 hours.
- **Done in:** `docs/archive/launch-prep/saturday-audit/03_Observability_Launch_Runbook.md` (archive only; no new canon under `docs/` root).
