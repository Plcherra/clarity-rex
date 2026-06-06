# Clarity Usage Tracking Master Plan

Status: Draft

Last updated: June 6, 2026

## Purpose

Add safe, server-first per-user usage tracking so Clarity can understand user activity, voice minutes, provider costs, latency, errors, Plaid sync activity, feature adoption, and billing-relevant usage without storing private content.

## Core Outcome

By the end of this plan:

- Usage can be tracked per user and per feature.
- Voice usage can be measured per user by day, week, and month.
- Admin/internal reporting can answer how many users are active, how much each user uses voice/chat/goals/memory/Assistant, and how much vendor pipeline usage each user creates.
- Deepgram, Grok, Google TTS, Plaid, and API usage can be attributed to users for cost analysis.
- Admin access is controlled by a backend-verified allowlist, never by a mobile/client-side flag.
- Backend records sensitive cost/latency events.
- Mobile records only sanitized UI events.
- No raw prompts, transcripts, audio, Plaid tokens, account numbers, or transaction descriptions are stored in usage telemetry.

## Non-Goals

- Do not build a public billing dashboard in v1.
- Do not implement billing, payments, invoices, or subscription enforcement in this plan.
- Do not store raw user content for analytics.
- Do not let mobile spoof LLM, STT, TTS, or Plaid cost metrics.
- Do not expose cross-user usage through direct mobile Supabase reads.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Audit events | Financial audit events exist. | Useful precedent, but not full usage tracking. |
| LLM/voice cost | Not normalized per user. | Hard to understand cost and latency. |
| Voice minutes | Not aggregated by day/week/month per user. | Cannot price, limit, or explain voice usage. |
| User activity | No admin usage view contract. | Cannot tell who is using the app or where costs come from. |
| Feature usage | Mobile flows do not share one usage contract. | Adoption and friction are invisible. |
| Privacy | No explicit telemetry no-content rule. | Analytics can accidentally collect sensitive data. |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Schema | `user_usage_events` and daily rollups. | Queryable usage by user and feature. |
| Rollups | Daily, weekly, and monthly user summaries. | Admin can see active users, voice time, and cost drivers. |
| Backend | Central usage service. | Sensitive events are authoritative. |
| Mobile | Sanitized UI event service. | Product usage is visible without private data. |
| Admin | Internal query contract for user/provider usage. | Supports pricing, support, and operations. |
| Admin boundary | Backend-verified admin allowlist. | Prevents normal users from accessing cross-user usage. |
| Privacy | No raw-content enforcement. | Safer multi-user launch. |

## Phase 1 - Usage Event Schema And RLS

Goal: Add the telemetry schema with strict user isolation, no raw-content fields, and enough structure to calculate per-user voice/provider usage.

Status: Complete.

Files to change:

- `supabase/migrations/*_create_user_usage_events.sql`
- `supabase/migrations/*_create_user_usage_daily_rollups.sql`
- `supabase/migrations/*_create_user_usage_period_rollups.sql`
- `supabase/migrations/*_create_admin_users.sql`
- `apps/mobile/lib/core/supabase/supabase_records.dart`

Steps:

1. Create `user_usage_events` with `user_id`, `event_type`, `surface`, `feature`, `channel`, `provider`, `model`, `duration_ms`, `latency_ms`, `unit_count`, `estimated_cost_cents`, `status`, `error_class`, `created_at`, and sanitized `metadata`.
2. Create daily rollup table or view for aggregated user usage.
3. Define weekly and monthly rollup fields or views derived from daily usage.
4. Create an `admin_users` allowlist table keyed by Supabase `user_id`.
5. Add RLS so users can read only their own summaries if exposed.
6. Restrict cross-user usage reads to backend/admin authority.
7. Restrict raw event writes to backend/service-role paths where needed.

Done looks like:

- Usage data has a durable schema.
- The schema cannot naturally hold raw private content.

Acceptance criteria:

- [x] RLS blocks cross-user reads.
- [x] Admin allowlist exists and is not readable or writable by normal users.
- [x] Schema can represent voice minutes, LLM calls, STT duration, TTS audio duration, Plaid sync counts, and API latency per user.
- [x] No column stores prompt, transcript, audio, token, account number, or transaction description.
- [x] Migration remains under 300 lines.

Completion ledger:

- Added backend-owned `admin_users` allowlist with no direct authenticated-user policies.
- Added backend-owned `user_usage_events` raw telemetry table with provider, model, latency, duration, unit count, estimated cost, status, and sanitized metadata.
- Added user-readable daily usage rollups plus weekly and monthly views derived from daily rows.
- Added mobile Supabase record models for user-owned daily/period usage summaries only; no mobile admin record was added.
- Verified migration line count is 217 total lines across the three Phase 1 migrations.
- Verified active product code has no legacy pending-memory/Rex-product terminology matches.
- Verified Flutter analyze and focused backend chat/voice tests pass.

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
4. Add helper methods for latency, model, voice, Plaid, API, memory, goals, and chat events.
5. Make tracking best-effort: failures are logged but never block user flows.

Done looks like:

- Backend metrics are recorded through one service.

Acceptance criteria:

- [ ] Sanitizer blocks raw content fields.
- [ ] Missing user id fails closed.
- [ ] Usage tracking failures do not break chat, voice, Plaid, memory, goals, or UI flows.
- [ ] Tests cover allowed and rejected metadata.

## Phase 3 - LLM/STT/TTS Usage Capture

Goal: Capture model and voice vendor usage without storing content, especially voice minutes by user.

Files to change:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/voice_*`
- `services/rex-api/app/services/usage_tracking_service.py`

Steps:

1. Record one usage event per normal LLM turn.
2. Record Deepgram STT audio duration, latency, status, and error class.
3. Record Google TTS latency, output audio duration, status, and error class when available.
4. Record Grok provider/model, latency, status, and token counts if available without storing text.
5. Record voice session start/stop duration so total voice minutes can be rolled up.
6. Record model name, channel, latency, status, and error class.
7. Never store prompt, response, transcript, or audio bytes.

Done looks like:

- Voice and chat cost/latency are measurable per user.

Acceptance criteria:

- [ ] Normal chat/voice still uses one LLM call per turn.
- [ ] Usage events include latency/status but no raw text.
- [ ] Voice minutes are attributable to the user by day, week, and month.
- [ ] Deepgram, Grok, and Google TTS usage can be separated in admin queries.
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
2. Track navigation, Connect Bank tap, CSV fallback tap, Assistant open, goals open/create/update, memory/info view open/edit, chat open, voice start/stop, and screen-level errors.
3. Do not track typed messages, transcripts, account numbers, or transaction names.
4. Make the service fail quietly if network is unavailable.

Done looks like:

- Product flow usage is visible without content capture.

Acceptance criteria:

- [ ] Client events are sanitized.
- [ ] Mobile can report feature usage counts for chats, goals, memory/info, Assistant, Plaid connect, and CSV fallback.
- [ ] Offline or failed tracking does not block UX.
- [ ] Flutter tests cover sanitizer behavior.

## Phase 6 - Daily, Weekly, And Monthly User Usage Rollups

Goal: Aggregate raw usage events into queryable daily, weekly, and monthly summaries.

Files to change:

- `supabase/migrations/*_create_user_usage_daily_rollups.sql`
- `supabase/migrations/*_create_user_usage_period_rollups.sql`
- `services/rex-api/app/services/usage_rollup_service.py`

Steps:

1. Define daily rollup fields by user, feature, channel, provider, model, and event type.
2. Define weekly and monthly rollup queries from daily rows.
3. Add safe aggregation for counts, latency averages, duration totals, voice minutes, provider unit counts, estimated cost, and failures.
4. Track counts for chats, goals, memory/info records, voice sessions, Plaid syncs, and mobile feature events where available.
5. Keep raw event retention policy documented.
6. Add tests for rollup aggregation.

Done looks like:

- Internal reporting can answer who uses what, how much voice time each user consumes, and where provider costs or latency are growing.

Acceptance criteria:

- [ ] Rollups aggregate without private content.
- [ ] Rollups are scoped by user id.
- [ ] Admin can query day/week/month voice minutes and provider usage per user.
- [ ] Retention policy is documented.

## Phase 7 - Admin/Internal Usage Query Contract

Goal: Define how internal tools can query usage safely for operations, support, pricing, and cost monitoring.

Files to change:

- `docs/clarity/product/CLARITY_USAGE_QUERY_CONTRACT.md`
- `services/rex-api/app/routes/usage.py`

Steps:

1. Define internal-only query shapes for active users, per-user usage, provider usage, voice minutes, feature counts, errors, and estimated cost.
2. Add optional admin route only if needed for operational checks.
3. Verify admin access by checking the authenticated user's id against the backend-owned `admin_users` allowlist.
4. Require service-role/admin access for cross-user aggregate views.
5. Define user-owned summary reads if exposed in app later.
6. Define future user-facing usage summary shape for billing transparency without implementing billing UI yet.

Done looks like:

- Usage data can support operations without becoming a privacy leak.

Acceptance criteria:

- [ ] Cross-user usage requires backend/admin authority.
- [ ] Admin access is based on backend verification against `admin_users`, not hidden UI or client claims.
- [ ] Admin queries can answer: active users, daily/weekly/monthly voice minutes, chats, goals, memory/info counts, provider usage, failures, and estimated cost by user.
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
