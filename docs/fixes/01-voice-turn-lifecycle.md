# 01 — Voice Turn Lifecycle

**Branch:** `fix/voice-stability-july`  
**Symptom:** Stuck on "Start talking" / listen phase  
**Status:** Planned — not yet implemented

---

## Repro steps

Based on Jul 5, 2026 screenshots and session:

1. Open Assistant → Chat tab and start a voice call.
2. Speak a full sentence (e.g. about a pull-up bar / exercises).
3. Stop speaking and wait without touching the app.

**Expected:** Phase moves from listening → thinking → speaking within a few seconds.

**Observed:**
- UI stays on **"Start talking"** (`VoiceCallPhase.listening`) long after speech ends.
- Phase only advances to thinking/processing when the app is backgrounded (e.g. taking a screenshot) or a lifecycle refresh fires.
- Sometimes the first message is fast; later turns stall in listen.

---

## Root cause

Specific files and functions:

| Location | Issue |
|----------|-------|
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart) | `_armTranscriptIdleEndpointTimeout`, `_armSpeechStartedEndpointTimeout`, and `_forceEndStreamingUtterance` are no-ops — local endpoint timers were disabled in favor of Deepgram `speech_final` only. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart) | After local mic capture completes, code waits indefinitely for `transcript.final` + `speech_final`. Mic may stop while UI still shows "Start talking". |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart) | `_finalizeStreamingTurn` has **no idempotency guard** — repeated `speech_final` or lifecycle resume can call `startThinking` multiple times per turn. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart) | Late `transcript.final` during `thinking` re-enters `startThinking` (lines 87–88). |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_lifecycle.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_lifecycle.dart) | App resume can call `_finalizeStreamingTurn` again on pending transcript. |

**Turn boundary today:**

```text
User speaks → local capture ends → wait for Deepgram speech_final → _finalizeStreamingTurn → startThinking
```

If `speech_final` never arrives (network stall, WS delay, classification edge case), the turn never finalizes.

---

## Proposed minimal fix

1. **Per-turn idempotency guard**
   - Add `_streamingTurnFinalized` (or match on `_streamingTurnSequence`).
   - In `_finalizeStreamingTurn`, return early if this turn sequence was already finalized.

2. **Bounded local fallback**
   - When capture ends (`onSpeechEnded` / capture future completes) and no `speech_final` within **3–5 seconds**, force `_finalizeStreamingTurn` with best available transcript (`_transcriptBuffer.visible` or last interim).
   - Re-implement `_forceEndStreamingUtterance` in `voice_call_controller_timers.dart` for this safety path only — not as primary boundary.

3. **Ignore stale transcript events**
   - Do not call `startThinking` from `transcript.final` when phase is `thinking` or `speaking` unless it belongs to a new turn (after `completeSpeaking`).

4. **Regression tests** in [`apps/mobile/test/voice_call_controller_test.dart`](../../apps/mobile/test/voice_call_controller_test.dart):
   - Capture ends, no `speech_final` → forced finalize within timeout.
   - Two `speech_final` events same turn → one `startThinking`.

---

## Out of scope

- Transcript text merging (`preferFullest`) — see [02-voice-transcript-dedup.md](./02-voice-transcript-dedup.md)
- TTS playback — see [03-voice-tts-playback.md](./03-voice-tts-playback.md)
- Latency tuning beyond safety timeout — see [05-voice-latency-retune.md](./05-voice-latency-retune.md)
- Confirm cards — see [04-confirm-card-popup.md](./04-confirm-card-popup.md)

---

## Acceptance criteria

- [ ] After speaking, phase leaves `listening` within **5 seconds** even if `speech_final` is delayed
- [ ] No indefinite "Start talking" stall in a 5-turn smoke test
- [ ] Each utterance triggers at most **one** transition to `thinking`
- [ ] Automated tests above pass

---

## Manual test steps

1. Start voice call → speak one sentence → wait 5s without touching app → verify thinking/speaking starts.
2. Repeat 5 turns without backgrounding the app.
3. Interrupt mid-response (barge-in) → speak again → verify no stuck listen.

---

## Key files to touch (implementation)

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart` (guard state)
- `apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`
- `apps/mobile/test/voice_call_controller_test.dart`
