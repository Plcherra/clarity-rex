# Launch-day monitoring runbook (Plan 03 / A14)
# Archive only — not canon. Canon remains MASTER_PLAN / CLARITY_RULES / PROJECT_STRUCTURE.

## Purpose

Watch crashes and critical product failures for the first 48 hours after Saturday launch smoke.

## Sentry

| Surface | Where | Env |
| --- | --- | --- |
| Flutter mobile | Sentry project for Clarity mobile | `SENTRY_DSN` / `--dart-define=SENTRY_DSN=...` + optional `SENTRY_ENVIRONMENT` |
| FastAPI (`rex-api`) | Sentry project for Clarity API | `SENTRY_DSN` + `APP_ENVIRONMENT` (+ optional `SENTRY_TRACES_SAMPLE_RATE`) |

Leave DSN empty in local/dev to disable reporting. Never commit DSNs.

Suggested Sentry issues views:
- Unhandled exceptions / crashes (mobile + API)
- Breadcrumb category `product` around confirm / voice / Plaid failures

## Structured product events (no PII / no transcripts)

Logged as `product_event {...}` from `rex.product_events` (and mirrored as Sentry breadcrumbs when Sentry is enabled):

| Event | Meaning |
| --- | --- |
| `write_confirmation_result` | Confirm card applied / failed / rejected (`action_type` / `write_kind` only) |
| `durable_write_apply_failed` | Backend apply path failed (snapshot/action type + reason code) |
| `voice_stream_error` | Streaming voice error (`code`, `status_code`) |
| `api_5xx` | HTTP 5xx from API middleware or mobile client |
| `plaid_exchange_result` | Token exchange ok / config / api / sync error |
| `plaid_sync_degraded` | Initial sync deferred after exchange |
| `discipline_list_degraded` | Memory discipline list load failed (duplicate detection at risk) |

Owner usage access is audited separately as `owner_usage_access` (requester id + endpoint; emails redacted by default).

## What to watch (first 48h)

1. **Voice** — spikes in `voice_stream_error` (especially `transcription_failed`, `tts_failed`, generic `voice_stream_error`).
2. **Plaid** — `plaid_exchange_result` failures and any `plaid_sync_degraded`.
3. **Chat / confirm** — `write_confirmation_result` with `result=failed` and `durable_write_apply_failed`.
4. **API health** — `api_5xx` rate and Sentry unhandled exceptions.
5. **Discipline** — `discipline_list_degraded` (should be near zero; fail-closed already blocks silent duplicate creates).

## Alert thresholds (starting point)

Tune after baseline is known; start conservative:

| Signal | Warn | Page / wake |
| --- | --- | --- |
| Mobile or API crash rate | > 1% sessions / 15m | Sustained > 5% / 15m or new crash fingerprint exploding |
| `api_5xx` | > 10 events / 15m | > 50 / 15m or `/ready` degraded |
| `voice_stream_error` | > 20 / 15m | > 100 / 15m |
| `write_confirmation_result` failed | > 10 / 15m | > 40 / 15m |
| `plaid_exchange_result` non-ok | > 5 / 15m | > 20 / 15m |
| `discipline_list_degraded` | any sustained stream | > 10 / 15m |

## Owner / admin exposure (A13)

- `/usage/admin/*` access is audit-logged.
- Emails in `/usage/admin/users` are **redacted by default**; full emails require `include_emails=true`.
- **Ops requirement:** enforce MFA on the usage-owner Supabase account before launch (not code-enforced here).

## First-48h owners

| Area | Primary | Backup |
| --- | --- | --- |
| Sentry triage (crashes) | On-call eng | Second eng |
| Voice stream errors | Voice/backend owner | Mobile owner |
| Plaid exchange / sync | Finance/Plaid owner | Backend owner |
| Confirm / durable write | Memory/assistant owner | Backend owner |
| Owner usage access anomalies | Platform owner | Security-aware eng |

Update names in the team channel at go-live; keep this table role-based if staffing rotates.

## Quick checks

```bash
# API process up + dependency readiness
curl -sS https://api.goclarity.app/ready | jq .

# Grep host logs for product events (example)
journalctl -u clarity-rex.service -n 200 --no-pager | rg "product_event|owner_usage_access|durable_write_apply_failed"
```

## Privacy rules

Never put transcripts, chat bodies, memory content, full emails (unless explicitly requested by owner with MFA), or Plaid tokens into Sentry events or product logs.
