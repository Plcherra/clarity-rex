# Voice And Usage Completion Plan

## Goal

Ship one reliable Rex voice experience that uses the same Rex Brain as chat, tracks usage accurately, and degrades clearly when speech, TTS, or backend services are unavailable.

## Current State

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

## Work Plan

### 1. Choose Production Voice Path

Pick one primary path per platform:

- Preferred: streaming cloud voice through `/voice/stream`.
- Fallback: REST `/voice/turn` if streaming fails or is disabled.
- Local speech should only be interim UX or fallback, not a separate Rex Brain.
- Native iOS path should be hidden, removed, or clearly marked experimental.

### 2. One Brain For Chat And Voice

- Voice turns must call the same production `ChatService` path as chat.
- Voice must follow the same memory truth rules.
- Voice must follow the same finance context rules.
- Voice must not save anything without backend confirmation.

### 3. Runtime Configuration

- Define release defaults:
  - `REX_CLOUD_VOICE_ENABLED`
  - `REX_STREAMING_VOICE_ENABLED`
  - any native legacy flags
- Add startup logging that clearly reports the active voice mode.
- Keep unavailable modes out of the UI.

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

### 5. Usage Tracking

- Backend records:
  - STT turns.
  - TTS turns.
  - LLM turns.
  - Voice session duration.
- Profile usage screen reads current-user totals.
- Decide whether mobile should use Rex `/usage/me` or direct Supabase `user_voice_summaries`.
- Keep one canonical user-facing usage source.

### 6. Performance And Reliability

- Add timeouts and reconnect limits.
- Avoid infinite reconnect loops.
- Ensure barge-in/interruption does not leave stale audio playing.
- Confirm backgrounding and app resume behavior.

## Acceptance Criteria

- Chat and voice produce consistent Rex behavior.
- User can complete a full voice turn in the release build.
- Voice failure states are understandable.
- Usage totals update after voice sessions.
- Only one production voice path is visible to the user.

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
