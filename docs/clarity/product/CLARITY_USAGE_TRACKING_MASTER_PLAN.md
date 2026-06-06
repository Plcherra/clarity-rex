# Clarity Usage Tracking Master Plan

Status: Draft

Last updated: June 6, 2026

## Purpose

Add safe, server-first per-user usage tracking so Clarity can understand usage, cost, latency, errors, voice duration, Plaid sync activity, and feature adoption without storing private content.

## Core Outcome

By the end of this plan:

- Usage can be tracked per user and per feature.
- Backend records sensitive cost/latency events.
- Mobile records only sanitized UI events.
- No raw prompts, transcripts, audio, Plaid tokens, account numbers, or transaction descriptions are stored in usage telemetry.

## Non-Goals

- Do not build a public billing dashboard in v1.
- Do not store raw user content for analytics.
- Do not let mobile spoof LLM, STT, TTS, or Plaid cost metrics.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Audit events | Financial audit events exist. | Useful precedent, but not full usage tracking. |
| LLM/voice cost | Not normalized per user. | Hard to understand cost and latency. |
| Feature usage | Mobile flows do not share one usage contract. | Adoption and friction are invisible. |
| Privacy | No explicit telemetry no-content rule. | Analytics can accidentally collect sensitive data. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Schema | `user_usage_events` and daily rollups. | Queryable usage by user and feature. |
| Backend | Central usage service. | Sensitive events are authoritative. |
| Mobile | Sanitized UI event service. | Product usage is visible without private data. |
| Privacy | No raw-content enforcement. | Safer multi-user launch. |

## Phase 1 - Usage Event Schema And RLS

Goal: Add the telemetry schema with strict user isolation and no raw-content fields.

Files to change:

- `supabase/migrations/*_create_user_usage_events.sql`
- `supabase/migrations/*_create_user_usage_daily_rollups.sql`
- `apps/mobile/lib/core/supabase/supabase_records.dart`

Steps:

1. Create `user_usage_events` with `user_id`, `event_type`, `surface`, `feature`, `channel`, `duration_ms`, `latency_ms`, `status`, `error_class`, `created_at`, and sanitized `metadata`.
2. Create daily rollup table or view for aggregated user usage.
3. Add RLS so users can read only their own summaries if exposed.
4. Restrict raw event writes to backend/service-role paths where needed.

Done looks like:

- Usage data has a durable schema.
- The schema cannot naturally hold raw private content.

Acceptance criteria:

- [ ] RLS blocks cross-user reads.
- [ ] No column stores prompt, transcript, audio, token, account number, or transaction description.
- [ ] Migration remains under 300 lines.

## Phase 2 - Backend Usage Tracking Service

Goal: Add one backend service for authoritative usage events.

Files to change:

- `services/rex-api/app/services/usage_tracking_service.py`
- `services/rex-api/app/models/usage_tracking.py`
- `services/rex-api/tests/test_usage_tracking_service.py`

Steps:

1. Define allowed event types and surfaces.
2. Add metadata sanitizer that rejects private-content keys.
3. Add service-role insert path.
4. Add helper methods for latency, model, voice, Plaid, and API events.

Done looks like:

- Backend metrics are recorded through one service.

Acceptance criteria:

- [ ] Sanitizer blocks raw content fields.
- [ ] Missing user id fails closed.
- [ ] Tests cover allowed and rejected metadata.

## Phase 3 - LLM/STT/TTS Usage Capture

Goal: Capture model and voice vendor usage without storing content.

Files to change:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/voice_*`
- `services/rex-api/app/services/usage_tracking_service.py`

Steps:

1. Record one usage event per normal LLM turn.
2. Record STT duration/latency and TTS latency/audio duration when available.
3. Record model name, channel, latency, status, and error class.
4. Never store prompt, response, transcript, or audio bytes.

Done looks like:

- Voice and chat cost/latency are measurable per user.

Acceptance criteria:

- [ ] Normal chat/voice still uses one LLM call per turn.
- [ ] Usage events include latency/status but no raw text.
- [ ] Focused chat and voice tests pass.

## Phase 4 - Plaid Sync Usage Capture

Goal: Track Plaid sync events and failures safely.

Files to change:

- `services/rex-api/app/services/plaid_sync_service.py`
- `services/rex-api/app/services/usage_tracking_service.py`
- `services/rex-api/tests/test_plaid_usage_tracking.py`

Steps:

1. Track link token creation.
2. Track public token exchange outcome.
3. Track account sync and transaction sync counts.
4. Track webhook and resync failures by error class only.

Done looks like:

- Plaid usage and reliability are visible without exposing financial details.

Acceptance criteria:

- [ ] Metadata may include counts and item status, not tokens or transaction descriptions.
- [ ] Failed sync emits sanitized error class.
- [ ] Cross-user data is not exposed.

## Phase 5 - Mobile Feature Usage Events

Goal: Add sanitized client-side UI usage events.

Files to change:

- `apps/mobile/lib/core/usage/usage_tracking_service.dart`
- `apps/mobile/lib/features/*`

Steps:

1. Add a mobile usage service that sends event names and non-private metadata.
2. Track navigation, Connect Bank tap, CSV fallback tap, Assistant open, voice start/stop, and screen-level errors.
3. Do not track typed messages, transcripts, account numbers, or transaction names.
4. Make the service fail quietly if network is unavailable.

Done looks like:

- Product flow usage is visible without content capture.

Acceptance criteria:

- [ ] Client events are sanitized.
- [ ] Offline or failed tracking does not block UX.
- [ ] Flutter tests cover sanitizer behavior.

## Phase 6 - Daily User Usage Rollups

Goal: Aggregate raw usage events into queryable daily summaries.

Files to change:

- `supabase/migrations/*_create_user_usage_daily_rollups.sql`
- `services/rex-api/app/services/usage_rollup_service.py`

Steps:

1. Define daily rollup fields by user, feature, channel, and event type.
2. Add safe aggregation for counts, latency averages, duration totals, and failures.
3. Keep raw event retention policy documented.
4. Add tests for rollup aggregation.

Done looks like:

- Internal reporting can answer who uses what and where latency/cost is growing.

Acceptance criteria:

- [ ] Rollups aggregate without private content.
- [ ] Rollups are scoped by user id.
- [ ] Retention policy is documented.

## Phase 7 - Admin/Internal Usage Query Contract

Goal: Define how internal tools can query usage safely.

Files to change:

- `docs/clarity/product/CLARITY_USAGE_QUERY_CONTRACT.md`
- `services/rex-api/app/routes/usage.py`

Steps:

1. Define internal-only query shapes.
2. Add optional admin route only if needed for operational checks.
3. Require service-role/admin access for cross-user aggregate views.
4. Define user-owned summary reads if exposed in app later.

Done looks like:

- Usage data can support operations without becoming a privacy leak.

Acceptance criteria:

- [ ] Cross-user usage requires backend/admin authority.
- [ ] User-facing usage, if exposed, only shows the current user.
- [ ] Query contract lists allowed filters and fields.

## Phase 8 - Privacy And No-Raw-Content Verification

Goal: Prove telemetry is safe before release.

Files to change:

- `services/rex-api/tests/test_usage_privacy_contract.py`
- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Add automated tests rejecting raw-content metadata keys.
2. Search code for direct usage event inserts outside approved services.
3. Verify no prompt/transcript/audio/Plaid-token field is stored.
4. Add usage privacy to release gate.

Done looks like:

- Telemetry is useful, scoped, and privacy-safe.

Acceptance criteria:

- [ ] Tests reject private-content metadata.
- [ ] Release checklist includes usage tracking privacy.
- [ ] No direct unsafe inserts exist.

## Verification Commands

```bash
rg -n "user_usage|usage_tracking|track_usage" services/rex-api apps/mobile/lib supabase/migrations
rg -n "prompt|transcript|audio|access_token|account_number|transaction_description" services/rex-api/app/services/usage* apps/mobile/lib/core/usage supabase/migrations
cd services/rex-api && pytest tests/test_usage_tracking_service.py tests/test_usage_privacy_contract.py
cd apps/mobile && flutter test test
```

## Execution Order

1. Phase 1 - Usage Event Schema And RLS
2. Phase 2 - Backend Usage Tracking Service
3. Phase 3 - LLM/STT/TTS Usage Capture
4. Phase 4 - Plaid Sync Usage Capture
5. Phase 5 - Mobile Feature Usage Events
6. Phase 6 - Daily User Usage Rollups
7. Phase 7 - Admin/Internal Usage Query Contract
8. Phase 8 - Privacy And No-Raw-Content Verification

## Release Gate

Ship only when usage tracking answers operational questions without storing private user content.
