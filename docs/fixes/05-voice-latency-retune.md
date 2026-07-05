# 05 — Voice Latency Retune

**Branch:** `fix/voice-stability-july`  
**Symptom:** Latency regression — sometimes fast, sometimes slow think/process, sometimes stuck listening  
**Status:** Planned — not yet implemented  
**Depends on:** [01-voice-turn-lifecycle.md](./01-voice-turn-lifecycle.md) through [04-confirm-card-popup.md](./04-confirm-card-popup.md)

---

## Repro steps

Based on Jul 5, 2026 session:

1. Morning latency fix felt great on the **first message**.
2. After subsequent voice fixes, behavior became inconsistent:
   - Sometimes fast (like the first message).
   - Sometimes long think/process delays.
   - Sometimes stuck in listening / "Start talking" (overlaps Issue 01).

**Expected:** Consistent responsive turns without stuck listen regressions.

**Do not start this issue until Issues 01–04 pass manual smoke tests.**

---

## Root cause

| Location | Issue |
|----------|-------|
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart) | Latency work removed local endpoint timers in favor of `speech_final`-only boundary — improved best-case latency but removed safety net (addressed in Issue 01). |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart) | Turn boundary waits on network/backend for `speech_final`. |
| Provider timeouts | `voiceCallThinkingTimeoutProvider`, `voiceCallNoSpeechTimeoutProvider` — may need review after stability fixes. |
| No structured metrics | Missing per-turn timing: capture end → speech_final → utterance.end → assistant.started → first audio chunk. |

**Timeline today (no unified metrics):**

```text
speech_end → [?] speech_final → utterance.end → assistant.started → first_audio_chunk → speaking
```

---

## Proposed minimal fix

**Only after Issues 01–04 pass.**

1. **Hybrid turn boundary**
   - **Prefer** `speech_final` for fast path (keep when it arrives quickly).
   - **Fallback** local endpoint at **2–3s** after capture end (Issue 01 safety net becomes tuned default, not emergency-only).

2. **Review timeout providers**
   - `voiceCallThinkingTimeoutProvider` — stuck thinking recovery without false positives.
   - `voiceCallNoSpeechTimeoutProvider` — empty turn recovery without conflicting with active capture.

3. **Per-turn timing logs**
   - Debug line per turn: `capture_end_ms`, `speech_final_ms`, `utterance_end_ms`, `assistant_started_ms`, `first_audio_ms`.
   - Use existing `rex_voice_playback` / add `rex_voice_turn_timing` prefix.

4. **Targets (manual + log review)**
   - p50: turn leaves listening within **2s** of speech end under normal network.
   - p95: within **5s** (fallback boundary).
   - Zero stuck-listen regressions in 10-turn test.

---

## Out of scope

- New WebSocket protocol changes
- Backend LLM latency optimization
- Re-disabling safety timeouts for speed
- Re-breaking Issues 01–04 for marginal latency gains

---

## Acceptance criteria

- [ ] Issues 01–04 manual tests still pass
- [ ] 5-turn smoke: majority of turns feel responsive (< 3s to first assistant audio)
- [ ] Zero stuck-listen regressions in 10-turn test
- [ ] Timing logs available for diagnosis per turn

---

## Manual test steps

1. Run a **10-turn** voice session; note per-turn responsiveness (subjective + log timestamps if available).
2. Compare to baseline tagged `broken-voice-jul5` if available on the branch.
3. Re-run Issues 01–04 manual checklists — all must still pass.

---

## Key files to touch (implementation)

- `apps/mobile/lib/rex/voice/application/voice_call_controller_timers.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart` (timing state)
- Provider definitions for voice timeouts (where `voiceCallThinkingTimeoutProvider` is defined)

---

## Execution note

This is intentionally **last** in the fix sequence. Latency was the first thing touched on Jul 5 and destabilized turn lifecycle. Re-tune only on a stable base from Issues 01–04.
