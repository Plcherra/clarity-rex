# P5 — Voice on Web

**Previous:** [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md), [P3_REX_CHAT_KNOWS.md](./P3_REX_CHAT_KNOWS.md)  
**Next:** [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md)

## Objective

Streaming voice on web uses the same `/voice/stream` Rex Brain path as mobile (`docs/VOICE_SOURCE_OF_TRUTH.md`).

## Prerequisites

- P1 complete (plugin guards, CORS)
- P3 complete (Rex chat UI works on web)
- rex-api voice stream endpoint reachable via WSS from browser

## Tasks

### 1. Browser WebSocket adapter

Refactor `streaming_voice_api.dart`:

- Conditional import: `dart:io` WebSocket (mobile/desktop IO) vs browser WebSocket (`package:web` or `dart:html`)
- Same `VoiceWebSocket` interface for `StreamingVoiceSession`

Verify rex-api allows WebSocket upgrade from web origin (CORS / proxy).

### 2. Browser audio capture

Web-safe mic streaming:

- Evaluate `record` package web support or MediaRecorder wrapper
- Stream linear16 chunks to match existing `sampleRate: 16000` contract
- Stub MethodChannel-only capture services on web

### 3. Audio playback

Verify on Chrome:

- `streaming_audio_playback_queue.dart`
- `audioplayers` for MPEG chunks from stream
- Fallback REST `/voice/turn` if WebSocket fails (same as mobile policy)

### 4. Permissions UX

- Browser mic permission prompt
- Clear error when denied or insecure context (non-HTTPS)
- Inline panel in chat (`inline_voice_call_panel.dart`) works on web width

### 5. Disable mobile-only paths

On web, keep off:

- `MethodChannelBackgroundVoiceService`
- `MethodChannelNativeVoiceSessionService`
- `REX_NATIVE_IOS_VOICE_ENABLED` / experimental native bridge

Set `AppCapabilities.supportsStreamingVoice = true` when done.

### 6. Usage tracking

Profile voice usage charts should reflect web sessions (same API as mobile).

## Exit criteria

- [ ] Start voice from Rex chat on Chrome (HTTPS)
- [ ] Speak → transcript → Rex reply → audio plays
- [ ] Interrupt / end session works
- [ ] Usage visible in Profile after session
- [ ] No claim of completed memory save without backend confirmation

## Tests

- Extend voice regression tests where possible
- Manual smoke per `docs/VOICE_SOURCE_OF_TRUTH.md`
- WebSocket fallback to REST path tested

## Files likely touched

- `apps/mobile/lib/rex/voice/data/streaming_voice_api.dart`
- `apps/mobile/lib/rex/voice/data/streaming_voice_api_web.dart` (new, conditional)
- `apps/mobile/lib/rex/voice/data/audio_capture_service.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming.dart`
- `apps/mobile/lib/core/platform/app_capabilities.dart`

## Out of scope (defer)

- Background voice when tab inactive (PWA limitation — document honestly)
- Native desktop voice (P7)
