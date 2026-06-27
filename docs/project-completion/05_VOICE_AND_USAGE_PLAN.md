# Voice And Usage Completion Plan

## Goal

Ship one reliable Rex voice experience that uses the same Rex Brain as chat, tracks usage accurately, and degrades clearly when speech, TTS, or backend services are unavailable.

## Current State

- MVP code status: Complete for Plan 5. Remaining validation is real-device
  runtime smoke because microphone capture, audio route behavior, WebSocket
  network conditions, and usage totals require a real app session.
- Backend supports REST voice:
  - `/voice/transcribe`
  - `/voice/turn`
  - `/voice/synthesize`
- Backend supports WebSocket streaming voice:
  - `/voice/stream`
- Mobile has multiple possible voice paths:
  - Streaming cloud voice.
  - Cloud multipart voice turn.
  - Local/on-device interim speech.
  - Native iOS voice session path.
- Usage tracking exists through backend events and Supabase `user_voice_summaries`.
- Started:
  - Streaming cloud voice is the primary production path.
  - REST `/voice/turn` remains a fallback when streaming is disabled or fails.
  - Native iOS voice requires the explicit experimental flag and is not a normal
    production path.
  - Startup logging reports the active voice flags.
  - `docs/VOICE_SOURCE_OF_TRUTH.md` now records the production path, fallback
    path, experimental paths, runtime flags, usage source, and failure states.

## Work Plan

### 1. Choose Production Voice Path

Pick one primary path per platform:

- Preferred: streaming cloud voice through `/voice/stream`.
- Fallback: REST `/voice/turn` if streaming fails or is disabled.
- Local speech should only be interim UX or fallback, not a separate Rex Brain.
- Native iOS path should be hidden, removed, or clearly marked experimental.
- Status: Confirmed. Streaming is enabled by default, REST cloud voice remains
  enabled as fallback, and native iOS is gated behind
  `REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED`.

### 2. One Brain For Chat And Voice

- Voice turns must call the same production `ChatService` path as chat.
- Voice must follow the same memory truth rules.
- Voice must follow the same finance context rules.
- Voice must not save anything without backend confirmation.
- Status: Confirmed for MVP. Both `/voice/stream` and `/voice/turn` call
  `ChatService` with the voice channel instead of using a separate brain.

### 3. Runtime Configuration

- Define release defaults:
  - `REX_CLOUD_VOICE_ENABLED`
  - `REX_STREAMING_VOICE_ENABLED`
  - any native legacy flags
- Add startup logging that clearly reports the active voice mode.
- Keep unavailable modes out of the UI.
- Status: Confirmed. Startup logging reports backend, cloud voice, streaming
  voice, experimental native iOS, and ignored legacy native iOS flag state.

### 4. User Experience

- Inline voice panel should show:
  - Listening.
  - Thinking.
  - Speaking.
  - Interrupted.
  - Reconnecting.
  - Degraded/unavailable.
- Add clear retry behavior for:
  - Microphone permission denied.
  - WebSocket connect failure.
  - STT failure.
  - TTS failure.
  - Expired auth token.
- Completed in this pass:
  - Inline voice panel now gives a specific session/auth recovery message for
    expired token or unauthorized voice failures.
  - Inline voice panel now gives specific recovery copy for microphone capture
    failures and TTS/playback failures.

### 5. Usage Tracking

- Backend records:
  - STT turns.
  - TTS turns.
  - LLM turns.
  - Voice session duration.
- Profile usage screen reads current-user totals.
- Decide whether mobile should use Rex `/usage/me` or direct Supabase `user_voice_summaries`.
- Keep one canonical user-facing usage source.
- Current MVP decision: Profile voice usage reads Supabase
  `user_voice_summaries` directly as the user-facing usage source.
- Status: Confirmed. The Supabase view uses `security_invoker = true` and RLS
  on `user_usage_events`, while Rex API `/usage/me` remains available but is not
  the current mobile source.

### 6. Performance And Reliability

- Add timeouts and reconnect limits.
- Avoid infinite reconnect loops.
- Ensure barge-in/interruption does not leave stale audio playing.
- Confirm backgrounding and app resume behavior.
- Completed in this pass:
  - Consecutive empty/no-speech voice turns are capped so a silent microphone
    eventually stops in a clear Try again state instead of auto-retrying forever.

## Acceptance Criteria

- Chat and voice produce consistent Rex behavior: Confirmed by shared
  `ChatService` path and backend voice parity tests.
- User can complete a full voice turn in the release build: Ready for manual
  smoke on a real device/build.
- Voice failure states are understandable: Covered for auth/session, mic,
  empty/no-audio, stream, transcript, and TTS/playback failures.
- Usage totals update after voice sessions: Backend events and Supabase summary
  reads are covered by automated tests; final confirmation needs runtime smoke.
- Only one production voice path is visible to the user: Confirmed. Streaming is
  default, REST is fallback, native iOS remains experimental.

## Deferred After MVP

- Native iOS voice bridge as a production path.
- Advanced live reconnection UI beyond the current retry/fallback states.
- Push/local notifications for voice/accountability follow-up.
- Admin or owner usage dashboards in the mobile app — see [`09_CHARTS_USAGE_AND_FINANCE_VIZ_PLAN.md`](09_CHARTS_USAGE_AND_FINANCE_VIZ_PLAN.md) Phase 1.
- Full real-device audio route matrix across Bluetooth, speaker, background,
  and OS interruptions.

## Verification Log

- `flutter analyze lib/rex/chat/presentation/widgets/inline_voice_call_panel.dart test/inline_voice_call_panel_test.dart`
  - No issues found.
- `flutter test test/inline_voice_call_panel_test.dart`
  - Covers expired/unauthorized voice session recovery copy.
  - Covers microphone capture and TTS/playback recovery copy.
  - Covers repeated no-speech recovery copy.
- `flutter test test/inline_voice_call_panel_test.dart test/usage_summary_service_test.dart test/streaming_voice_api_test.dart`
  - 7 tests passed.
- `flutter analyze lib/rex/voice/application/voice_call_controller.dart lib/rex/voice/application/voice_call_controller_commands.dart lib/rex/voice/application/voice_call_controller_timers.dart lib/rex/chat/presentation/widgets/inline_voice_call_panel.dart test/voice_call_controller_test.dart test/inline_voice_call_panel_test.dart`
  - No issues found.
- `flutter test test/inline_voice_call_panel_test.dart test/voice_call_controller_test.dart`
  - 29 tests passed.
- `flutter analyze lib/rex/voice/application/voice_call_controller.dart lib/rex/voice/application/voice_call_controller_commands.dart lib/rex/voice/application/voice_call_controller_timers.dart lib/rex/chat/presentation/widgets/inline_voice_call_panel.dart lib/features/profile/application/usage_summary_service.dart test/voice_call_controller_test.dart test/inline_voice_call_panel_test.dart test/usage_summary_service_test.dart test/streaming_voice_api_test.dart`
  - No issues found.
- `flutter test test/inline_voice_call_panel_test.dart test/voice_call_controller_test.dart test/usage_summary_service_test.dart test/streaming_voice_api_test.dart test/voice_playback_service_test.dart`
  - 35 tests passed.
- `python -m pytest tests/test_usage_tracking_service.py tests/test_usage_routes.py -q`
  - 10 tests passed.
- `python -m pytest tests/test_voice_routes.py tests/test_voice_stream_routes.py tests/test_voice_stream_reliability.py tests/test_voice_memory_parity.py tests/test_voice_goal_command_flow.py tests/test_rex_brain_voice_integration.py tests/test_google_tts_service.py tests/test_deepgram_service.py tests/test_usage_tracking_service.py tests/test_usage_routes.py -q`
  - 91 tests passed.

## Suggested Tests

- Backend:
  - voice route tests
  - voice stream route tests
  - voice memory parity tests
  - usage tracking service tests
- Flutter:
  - voice call controller tests
  - streaming voice API tests
  - inline voice panel widget tests
  - usage summary controller tests

## Manual Smoke

1. Start voice from Chat.
2. Speak a normal assistant question.
3. Speak a memory save request.
4. Speak a finance question.
5. Interrupt Rex while speaking.
6. Background and resume the app.
7. Confirm usage totals update.
8. Disable backend voice config and confirm degraded UI.
