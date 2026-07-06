# 01 — Voice Turn Lifecycle & Stability

**Status:** Complete — Steps 1–3 implemented (July 2026)  
**Replaces:** old 01 (Voice Turn Lifecycle) + old 05 (Voice Latency Retune)

---

## Generic failure class

**`StreamingTurnEndpointDesync`** — mobile treats remote `speech_final` as mandatory before advancing phase, but local VAD already stopped the mic. The turn pipeline has no deterministic join event.

---

## Canon compliance

- [`docs/PROJECT_STRUCTURE.md`](../PROJECT_STRUCTURE.md) §0: no artificial timeouts or fallback timers to fix race conditions; solve root causes
- [`docs/PROJECT_STRUCTURE.md`](../PROJECT_STRUCTURE.md) §10: voice uses same `ChatTurnOrchestrator` as chat
- [`docs/MASTER_PLAN.md`](../MASTER_PLAN.md) §2: voice must work reliably in background
- [`docs/CLARITY_RULES.md`](../CLARITY_RULES.md): voice and chat share the same brain

---

## Problem

- UI stuck on "Start talking" after the user finishes speaking
- Inconsistent responsiveness (fast first turn, slow or stuck later turns)
- Perceived "latency regression" that is actually endpoint stall, not backend slowness

---

## Root cause

Streaming path waits on network for `speech_final`; REST path finalizes on local capture end. Two authorities, one broken.

| Location | Issue |
| --- | --- |
| [`voice_call_controller_streaming_capture.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart) | `onSpeechEnded` arms a timer instead of finalizing; post-capture waits for `speech_final` |
| [`voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart) | `transcript.final` + `speech_final` is the sole gate to `_finalizeStreamingTurn` |
| [`voice_call_controller_timers.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart) | `_armSpeechFinalFallbackAfterCapture` / `_forceEndStreamingUtterance` are race-condition timers |
| REST fallback path | Already finalizes on local capture end — streaming diverges from the working pattern |

Backend contract ([`voice_stream_live_transcription.py`](../../services/rex-api/app/services/voice_stream_live_transcription.py)): `flutter_streaming` requires explicit `utterance.end`; server runs `finish()` server-side. Mobile does **not** need `speech_final` first.

---

## The fix — make streaming match REST

**Rule:** Local VAD endpoint is the **only** mobile turn boundary. `speech_final` is optional confirmation, never a gate.

### Exact behavior change

```text
BEFORE (broken):
  onSpeechEnded → arm 4s timer → maybe _forceEndStreamingUtterance
  speech_final  → _finalizeStreamingTurn (primary gate)
  capture done  → wait indefinitely

AFTER (fixed):
  onSpeechEnded → _endTurnFromLocalEndpoint()
  capture done (speech detected) → _endTurnFromLocalEndpoint()
  speech_final  → _endTurnFromLocalEndpoint() (idempotent — no-op if already done)
```

### `_endTurnFromLocalEndpoint()` — single function, three call sites

1. Read transcript: `_transcriptBuffer.visible.trim()` (only source; chat merge is Plan 03)
2. If empty → `_recoverFromEmptyVoiceTurn()` (existing recovery path)
3. Else → `_finalizeStreamingTurn(transcript, session, turnSequence)` (idempotency via `_streamingTurnFinalizedSequence`)
4. `_finalizeStreamingTurn` already: cancels timers, `startThinking`, sends `utterance.end`

### Delete — do not disable, do not retune

Remove entirely from [`voice_call_controller_timers.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart):

- `_armSpeechFinalFallbackAfterCapture`
- `_forceEndStreamingUtterance`
- `_armListeningEndpointTimeout` / `_cancelListeningEndpointTimeout` / `_listeningEndpointTimer`
- `voiceCallSpeechFinalFallbackTimeoutProvider` (provider + all references)

Remove post-capture timer arm and "wait for Deepgram speech_final" in [`voice_call_controller_streaming_capture.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart).

### Keep (recovery, not turn boundaries)

- `_armNoSpeechTimeout` — user spoke nothing
- `_armThinkingTimeout` — backend never responds
- `_recoverFromEmptyVoiceTurn` / `_recoverFromStuckThinking`

### Stability instrumentation (built in)

Record timestamps at **events**, not on timers:

| Event | Field |
| --- | --- |
| Local VAD `onSpeechEnded` | `capture_end_ms` |
| `_finalizeStreamingTurn` called | `finalize_ms` |
| `utterance.end` sent | `utterance_end_ms` |
| `assistant.started` received | `assistant_started_ms` |
| First audio chunk played | `first_audio_ms` |

One debug line per turn: `rex_voice_turn_timing turn=N capture_end=… finalize=… …`

Latency targets validate this fix, not a separate retune:

- listening → thinking on the same event loop tick as local VAD end (when transcript non-empty)
- 10-turn smoke: zero stuck-listen

---

## Key files

- [`voice_call_controller_streaming_capture.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart)
- [`voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart)
- [`voice_call_controller_timers.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart)
- [`voice_call_controller_chat_sync.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart)
- [`voice_call_controller.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller.dart)
- [`voice_call_controller_test.dart`](../../apps/mobile/test/voice_call_controller_test.dart)

---

## Acceptance criteria

- [x] Zero turn-boundary timer code remains
- [x] Phase leaves `listening` on local VAD end when transcript is non-empty
- [x] Duplicate `speech_final` / lifecycle resume → one `startThinking` per turn
- [x] 10-turn smoke: no indefinite listen stall
- [x] Per-turn timing log emitted

---

## Manual smoke steps

1. Start voice call → speak one sentence → wait without touching app → verify thinking/speaking starts immediately.
2. Repeat 10 turns without backgrounding — no stuck listen.
3. Interrupt mid-response (barge-in) → speak again → verify clean turn advance.
4. Check logs for `rex_voice_turn_timing` on each turn.

---

## Out of scope

- Transcript dedup and confirm cards — [03-transcript-proposal-integrity.md](./03-transcript-proposal-integrity.md)
- TTS playback — [02-voice-playback-authority.md](./02-voice-playback-authority.md)

---

## Coupling

Can ship independently. Recommended before Plan 02 and Plan 03 for lowest risk, but not a hard blocker.
