# P5 — Voice on Web

**Previous:** [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md), [P3_REX_CHAT_KNOWS.md](./P3_REX_CHAT_KNOWS.md)  
**Next:** [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md)

## Objective

Streaming voice on web uses the same `/voice/stream` Rex Brain path as mobile (`docs/VOICE_SOURCE_OF_TRUTH.md`).

## Status (code complete — manual smoke pending)

| Task | Status |
|------|--------|
| 1. Browser WebSocket adapter | Done — conditional IO/web split, query-param auth on web |
| 2. Browser audio capture | Done — `record` PCM16 stream + web REST fallback capture |
| 3. Audio playback | Done — `audioplayers` web data URIs, REST fallback tested |
| 4. Permissions UX | Done — HTTPS check, browser mic copy, capability gate enabled |
| 5. Disable mobile-only paths | Done — see capability matrix below |
| 6. Usage tracking | Done — Profile reads same Supabase `user_voice_summaries` on web |

## Web capability matrix

| Feature | Web | Mobile |
|---------|-----|--------|
| Streaming voice (`/voice/stream`) | Yes | Yes |
| REST fallback (`/voice/turn`) | Yes | Yes |
| Native iOS voice bridge | No | Optional (experimental) |
| Background voice when tab/app inactive | No | Yes (iOS/Android) |
| Profile voice usage charts | Yes | Yes |

`AppCapabilities` gates these honestly. Web voice sessions tag `client: flutter_streaming_web` in `session.start` for backend logs.

## PWA / browser limitations (document honestly)

- **HTTPS required** — microphone access and secure WebSocket auth require a secure context (`https://` or localhost dev).
- **Tab background** — browsers may pause or stop mic capture when the tab is hidden. Clarity does not run background voice on web; return to the tab and tap **Try again** if the call pauses.
- **Site permissions** — blocked mic access must be re-enabled in browser site settings (lock icon in the address bar).
- **No native settings deep link** — the failed-call Settings action shows browser guidance instead of iOS Settings.

## Usage tracking

Web voice minutes appear in **Profile → Voice usage** the same way as mobile:

1. Rex API records STT/TTS/LLM/voice-session events during `/voice/stream` (and `/voice/turn` fallback).
2. Supabase view `user_voice_summaries` aggregates daily totals per user (RLS scoped).
3. Flutter `UsageSummaryService` reads that view on all platforms — no web-specific fork.

After a web voice session, pull-to-refresh on the Voice usage screen to see updated charts.

## Prerequisites

- P1 complete (plugin guards, CORS)
- P3 complete (Rex chat UI works on web)
- rex-api voice stream endpoint reachable via WSS from browser
- Cloudflare/nginx allows WebSocket upgrade from `https://goclarity.app`

## Exit criteria

- [ ] Start voice from Rex chat on Chrome (HTTPS)
- [ ] Speak → transcript → Rex reply → audio plays
- [ ] Interrupt / end session works
- [ ] Usage visible in Profile after session (refresh Voice usage)
- [ ] No claim of completed memory save without backend confirmation

## Tests

```bash
# Flutter
flutter test test/streaming_voice_api_test.dart test/streaming_voice_client_test.dart \
  test/voice_playback_mime_test.dart test/voice_playback_service_test.dart \
  test/voice_call_controller_test.dart test/app_capabilities_test.dart \
  test/usage_summary_service_test.dart test/voice_microphone_context_test.dart

# Backend voice + usage
python -m pytest services/rex-api/tests/test_voice_stream_routes.py \
  services/rex-api/tests/test_usage_tracking_service.py -q
```

Manual smoke per `docs/VOICE_SOURCE_OF_TRUTH.md`.

## Key files

- `apps/mobile/lib/rex/voice/data/streaming_voice_api.dart` (+ `_io` / `_web`)
- `apps/mobile/lib/rex/voice/data/audio_capture_service_web.dart`
- `apps/mobile/lib/rex/voice/data/voice_microphone_context.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_providers.dart`
- `apps/mobile/lib/core/platform/app_capabilities.dart`
- `apps/mobile/lib/features/profile/application/usage_summary_service.dart`

## Out of scope (defer)

- Background voice when tab inactive (PWA limitation — documented above)
- Native desktop voice (P7)
