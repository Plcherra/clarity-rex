# Clarity Usage Tracking Master Plan

Status: In progress

Last updated: June 6, 2026

## Executive Summary

This plan replaces the earlier broad analytics direction with a narrow usage system focused on provider usage and voice minutes.

Clarity only needs to know:

- How much each user uses Deepgram, Grok, Google TTS, and voice.
- How many voice minutes a user has used today, this week, and this month.
- What the owner needs to inspect user-level provider usage internally.

This plan does not calculate dollars, build a public billing dashboard, store private content, or track broad product analytics.

## Locked Rules

- Canonical event types are `stt`, `llm`, `tts`, and `voice_session`.
- Store safe usage data only: `user_id`, `event_type`, `provider`, `duration_seconds`/duration equivalent, and `created_at`.
- Existing compatibility columns may remain in the database, but product code must not rely on estimated cost, complex metadata, or feature analytics.
- No raw prompts, responses, transcripts, audio, Plaid tokens, account numbers, or transaction descriptions.
- Owner access is backend-verified through `USAGE_OWNER_USER_ID` or the `admin_users` allowlist.
- Normal users can only read their own usage summaries.
- Provider cost is calculated later from provider pricing, not stored per event.

## Phase 1: Simplify Usage Contract

Goal: Replace the bloated event semantics with the four canonical provider/voice events.

Files to change:

- `services/rex-api/app/models/usage_tracking.py`
- `services/rex-api/app/services/usage_tracking_service.py`
- `supabase/migrations/*_create_user_voice_summaries.sql`

Done looks like:

- Usage writes use only `stt`, `llm`, `tts`, and `voice_session`.
- Extra columns remain only as compatibility with the already-pushed table.
- No product code emits estimated cost or broad feature analytics events.

Acceptance criteria:

- [x] `llm` rows represent real Grok calls.
- [x] `stt` rows represent real Deepgram transcription usage.
- [x] `tts` rows represent real Google TTS synthesis usage.
- [x] `voice_session` rows represent voice duration.
- [x] No fake usage events for direct memory/goal turns that skip Grok.

## Phase 2: Track Real Usage

Goal: Record real provider usage from the existing chat and voice boundaries.

Files to change:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/routes/voice.py`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/services/voice_stream_response_writer.py`
- `services/rex-api/app/services/voice_stream_usage_tracking.py`

Done looks like:

- Chat and voice record one `llm` event per actual Grok call.
- Voice records Deepgram STT duration when available.
- Voice records Google TTS duration when parseable, otherwise records a safe TTS event without duration.
- Voice session duration is separate from LLM calls.

Acceptance criteria:

- [x] Chat creates one Grok usage event per normal LLM turn.
- [x] Voice creates STT, LLM, TTS, and voice-session events when the full pipeline runs.
- [x] Direct memory/goal turns that do not call Grok do not create fake LLM rows.
- [x] No raw content is stored in usage events.

## Phase 3: Simple Daily Voice Summary

Goal: Provide simple daily per-user rows that can power today/week/month totals.

Files to change:

- `supabase/migrations/*_create_user_voice_summaries.sql`
- `services/rex-api/app/services/usage_tracking_service.py`
- `apps/mobile/lib/core/supabase/supabase_records.dart`

Done looks like:

- `user_voice_summaries` exposes `user_id`, `usage_date`, `voice_seconds`, `llm_calls`, `stt_seconds`, and `tts_seconds`.
- Weekly and monthly totals are computed from daily rows.
- Users can read only their own summaries through RLS.

Acceptance criteria:

- [x] Daily rows aggregate voice seconds.
- [x] Daily rows count LLM calls.
- [x] Daily rows aggregate STT and TTS seconds.
- [x] Backend summary methods compute today/week/month.
- [x] Mobile has a typed record for the simple summary.

## Phase 4: User Usage Screen And Owner View

Goal: Show users simple voice usage and give the owner safe internal all-user usage visibility.

Files to change:

- `services/rex-api/app/routes/usage.py`
- `services/rex-api/app/main.py`
- `apps/mobile/lib/features/profile/application/usage_summary_service.dart`
- `apps/mobile/lib/features/profile/application/usage_summary_controller.dart`
- `apps/mobile/lib/features/profile/presentation/usage_summary_screen.dart`
- `apps/mobile/lib/features/profile/presentation/profile_screen.dart`

Done looks like:

- Users can see voice minutes today, this week, and this month.
- Backend owner route shows all users with monthly voice seconds, LLM calls, STT seconds, and TTS seconds.
- Owner access is backend verified; normal users cannot query other users’ usage.

Acceptance criteria:

- [x] Profile includes a Voice usage screen.
- [x] Owner route does not depend on client-side flags or mobile secrets.
- [x] Non-owner access to all-user usage returns 403.
- [x] Normal users never query other users’ usage directly.

## Completion Ledger

- Simplified backend event names to `stt`, `llm`, `tts`, and `voice_session`.
- Stopped writing estimated cost, unit counts, and metadata from active usage code.
- Added `user_voice_summaries` as a simple daily summary view over safe events.
- Added backend `/usage/me` and owner-only `/usage/admin/users` routes.
- Added mobile Profile > Voice usage for today/week/month voice minutes.
- Kept the existing migrated tables intact to avoid destructive database churn.
