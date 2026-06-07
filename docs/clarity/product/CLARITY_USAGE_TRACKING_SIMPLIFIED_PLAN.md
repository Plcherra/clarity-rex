#2 Usage Tracking

Status: Complete

Last updated: June 7, 2026

## Summary

This plan keeps usage tracking intentionally small.

The goal is to track:

- How much each user uses Deepgram, Grok, Google TTS, and voice.
- Voice minutes for each user: today, this week, and this month.
- Owner-only visibility into all users' usage.

This plan does not calculate dollar cost, store private content, build a public billing dashboard, or track broad product analytics.

## Non-Negotiable Rules

- No raw prompts, responses, transcripts, audio, Plaid tokens, account numbers, or transaction descriptions.
- Normal users can only see their own usage.
- Owner access must be verified by the backend, not by a mobile flag or client-side secret.
- Provider cost is calculated later from provider pricing, not stored per event.

## Phase 1: Simple Usage Events

Status: Complete

### Goal

Create one clean usage event contract for provider and voice usage.

### Exact Files To Change

- `supabase/migrations/*_create_user_usage_events.sql`
- `services/rex-api/app/models/usage_tracking.py`
- `services/rex-api/app/services/usage_tracking_service.py`
- `services/rex-api/tests/test_usage_tracking_service.py`

### Specific Steps

1. Treat these as the only canonical event types:
   - `stt`
   - `llm`
   - `tts`
   - `voice_session`
2. Store only safe usage data:
   - `user_id`
   - `event_type`
   - `provider`
   - `duration_seconds` or stored duration equivalent
   - `created_at`
3. Keep existing migrated table columns only as compatibility if already pushed.
4. Stop using estimated cost, complex metadata, feature analytics, and broad event types.
5. Add tests proving private content cannot be stored.

### Done Looks Like

- Usage events are simple and provider-focused.
- No active code writes raw content or estimated cost.
- Invalid event types are rejected.
- Existing migrations do not need destructive rollback.

### Completion Ledger

- Canonical event types are limited to `stt`, `llm`, `tts`, and `voice_session`.
- Active usage inserts no longer write estimated cost, unit count, or metadata payloads.
- Existing pushed table columns are treated as compatibility only, not the product contract.
- Focused tests cover invalid event rejection and private metadata rejection.

## Phase 2: Track Real Provider Usage

Status: Complete

### Goal

Record real usage at the actual backend boundaries where Deepgram, Grok, Google TTS, and voice sessions run.

### Exact Files To Change

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/routes/voice.py`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/services/voice_stream_response_writer.py`
- `services/rex-api/tests/test_chat_usage_tracking_flow.py`
- `services/rex-api/tests/test_voice_routes.py`
- `services/rex-api/tests/test_voice_stream_routes.py`

### Specific Steps

1. Record one `llm` event for every real Grok call, whether the user typed or spoke.
2. Record `stt` for Deepgram with actual audio duration when available.
3. Record `tts` for Google TTS with audio duration when available.
4. Record `voice_session` separately for actual voice/speaking duration.
5. Do not create fake `llm` events for direct memory or goal turns that do not call Grok.
6. Keep usage tracking best-effort so tracking failures never block chat or voice.

### Done Looks Like

- Normal chat creates one Grok usage event.
- Voice creates STT, LLM, TTS, and voice-session events when the full pipeline runs.
- No prompt, transcript, response, or audio data is stored.
- Focused chat and voice tests pass.

### Completion Ledger

- Chat records one `llm` usage event only after a real Grok call succeeds or fails.
- Direct memory/goal turns return before Grok and do not create fake `llm` events.
- Non-streaming voice records Deepgram `stt`, Google `tts`, and `voice_session` usage.
- Streaming voice records Deepgram `stt`, Google `tts`, and session usage while delegating Grok usage to the shared chat path.
- TTS usage records estimated duration with `len(text) / 15` seconds when provider duration is unavailable.
- Usage tracking remains best-effort and does not block chat or voice when tracking fails.

## Phase 3: Daily Voice Summary

Status: Complete

### Goal

Create a simple daily summary users can read safely, then compute weekly and monthly totals from those rows.

### Exact Files To Change

- `supabase/migrations/*_create_user_voice_summaries.sql`
- `services/rex-api/app/services/usage_tracking_service.py`
- `apps/mobile/lib/core/supabase/supabase_records.dart`
- `apps/mobile/test/usage_summary_service_test.dart`

### Specific Steps

1. Create `user_voice_summaries` with:
   - `user_id`
   - `usage_date`
   - `voice_seconds`
   - `llm_calls`
   - `stt_seconds`
   - `tts_seconds`
2. Make weekly and monthly values computed from daily rows.
3. Add RLS so users can read only their own summaries.
4. Add backend aggregation methods for today, week, and month.
5. Add mobile record parsing for the summary rows.

### Done Looks Like

- Daily rows can power user usage stats.
- Users cannot read another user's summary.
- Backend can calculate today/week/month totals.
- Mobile has a typed record for the summary data.

### Completion Ledger

- `user_voice_summaries` is implemented as a security-invoker daily view over canonical events, not a stale rollup table.
- The summary exposes `user_id`, `usage_date`, `voice_seconds`, `llm_calls`, `stt_seconds`, and `tts_seconds`.
- The summary view uses only `stt`, `llm`, `tts`, and `voice_session`; old event aliases are not counted.
- Backend user totals query the current month with an explicit `user_id` filter and compute today/week/month totals from daily rows.
- Mobile has a typed `UserVoiceSummaryRecord` and focused tests for daily aggregation and numeric parsing.

## Phase 4: User Usage Screen And Owner View

Status: Complete

### Goal

Show each user their own voice usage and give Pedro an internal owner-only usage view.

### Exact Files To Change

- `services/rex-api/app/routes/usage.py`
- `services/rex-api/app/main.py`
- `services/rex-api/app/config.py`
- `apps/mobile/lib/features/profile/application/usage_summary_service.dart`
- `apps/mobile/lib/features/profile/application/usage_summary_controller.dart`
- `apps/mobile/lib/features/profile/presentation/usage_summary_screen.dart`
- `apps/mobile/lib/features/profile/presentation/profile_screen.dart`
- `services/rex-api/tests/test_usage_routes.py`

### Specific Steps

1. Add `/usage/me` for the current user's usage totals.
2. Add `/usage/admin/users` for owner-only all-user usage.
3. Verify owner access through backend config or the `admin_users` allowlist.
4. Add a Profile screen entry for "Voice usage."
5. Show:
   - Voice minutes today
   - Voice minutes this week
   - Voice minutes this month
6. Keep owner usage internal; do not expose all-user usage through normal mobile reads.

### Done Looks Like

- Normal users see only their own voice minutes.
- Pedro can access all-user usage through a backend-verified owner path.
- Non-owner access to all-user usage returns 403.
- The mobile usage screen stays simple and does not show billing math.

### Completion Ledger

- `/usage/me` returns the current user's today/week/month usage totals from the backend summary path.
- `/usage/admin/users` returns all-user monthly voice, LLM, STT, and TTS usage only after backend owner verification.
- Non-owner all-user usage requests return 403 and do not include user rows.
- Owner allowlist access is restricted to `owner` and `admin` roles.
- Profile includes a simple "Voice usage" entry.
- The mobile usage screen shows voice minutes today, this week, and this month, with Grok call counts as supporting context.
- The user-facing screen does not show cost estimates or billing math.

## Final Cleanup Ledger

- Added a cleanup migration that removes unused `unit_count`, `estimated_cost_cents`, and `metadata` columns from `user_usage_events`.
- Added the same cleanup migration to retire the old daily/weekly/monthly usage rollup objects from the overbuilt plan.
- Removed unused backend usage metadata sanitizer code because usage events no longer accept metadata.
- Tightened owner usage lookup so `support` rows in `admin_users` do not get all-user usage access.
