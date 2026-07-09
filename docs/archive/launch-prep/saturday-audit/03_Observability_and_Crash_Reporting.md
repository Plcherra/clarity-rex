# 03 — Observability and Crash Reporting

**Covers:** Production blindness — crash reporting, product analytics, and the minimum event set needed to diagnose Saturday failures. Do this immediately after truth-rule fixes so every subsequent smoke test is visible in telemetry.

**Primary paths:** `apps/mobile/lib/app/bootstrap.dart`, `apps/mobile/pubspec.yaml`, `services/rex-api/app/main.py`

---

## Phase 1 — Crash reporting baseline

### Issue: No crash reporting or analytics (C1)

- **Severity:** Critical
- **Why it matters:** Saturday crashes, ANRs, Plaid failures, and voice drop-offs are invisible without a SDK.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Add Sentry (or Firebase Crashlytics) to Flutter + FastAPI; wire `FlutterError.onError` and zone errors in `bootstrap.dart`; capture unhandled API exceptions server-side.

---

## Phase 2 — Critical product events

### Issue: No structured events for save / voice / API failures (A10)

- **Severity:** High
- **Why it matters:** Crashes alone do not explain “confirm failed” or “voice stream died” without breadcrumbs.
- **Estimated effort:** Medium
- **Brief fix suggestion:** Emit minimal events (no PII/transcripts): `write_confirmation_result`, `voice_stream_error`, `api_5xx`, `plaid_exchange_result`, `plaid_sync_degraded`.

### Issue: Apply failures lack ops signal (A11)

- **Severity:** Medium
- **Why it matters:** Backend `except Exception: return applied False` paths leave no alertable metric.
- **Estimated effort:** Small
- **Brief fix suggestion:** Log structured error codes for durable-write apply failures; optionally Sentry breadcrumb with action type (not content).

---

## Phase 3 — Discipline / silent-degrade alerts

### Issue: Memory discipline silent degrade has no metric (A12)

- **Severity:** Medium
- **Why it matters:** Empty-list fallbacks in discipline hide duplicate-detection outages.
- **Estimated effort:** Small
- **Brief fix suggestion:** Counter/metric when `_safe_list` fails; alert if rate spikes.

---

## Phase 4 — Owner / admin access audit

### Issue: Owner usage APIs expose all user emails (A13)

- **Severity:** High (insider / compromised owner)
- **Why it matters:** Compromised owner JWT = platform-wide email + usage exposure.
- **Estimated effort:** Small (ops) / Medium (code)
- **Brief fix suggestion:** MFA on owner account; audit-log admin endpoint access; consider redacting emails in admin responses.

---

## Phase 5 — Launch-day monitoring runbook

### Issue: No documented Saturday watch list (A14)

- **Severity:** Medium
- **Why it matters:** Telemetry without a watch plan still leaves the team reactive.
- **Estimated effort:** Small
- **Brief fix suggestion:** One-page runbook: Sentry project URLs, alert thresholds, who watches voice/Plaid/chat error rates for first 48 hours.
