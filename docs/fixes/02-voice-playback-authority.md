# 02 — Voice Playback Authority

**Status:** Planned — not yet implemented  
**Replaces:** old 03 (Voice TTS Playback)

---

## Generic failure class

**`SharedPlayerContention`** — multiple code paths call the same `AudioPlayer` for one assistant response; fallback is decided before the streaming queue finishes, using "has audio started playing" instead of "has streaming claimed this response."

---

## Canon compliance

- [`docs/PROJECT_STRUCTURE.md`](../PROJECT_STRUCTURE.md) §0: no artificial timeouts to fix race conditions; no 500ms grace periods or deferred fallback timers
- [`docs/MASTER_PLAN.md`](../MASTER_PLAN.md) §2: voice is the primary experience — audible replies must be reliable
- [`docs/CLARITY_RULES.md`](../CLARITY_RULES.md): never fake success; if Rex speaks, the user must hear it

---

## Problem

- Assistant reply spoken twice
- Assistant text visible in chat but silent when not muted

---

## Root cause

`assistant.done` chooses fallback inline using `hasPlayedChunks`, while chunks may already be enqueued but not yet audible.

Four paths share [`audio_playback_service.dart`](../../apps/mobile/lib/rex/voice/data/audio_playback_service.dart):

```text
streaming chunks → StreamingAudioPlaybackQueue
fallback synth   → _playSynthesizedStreamingFallback
REST turn        → playBase64Audio
typed chat       → speakTypedAssistantResponse
```

| Issue | Location |
| --- | --- |
| Fallback gates on `hasPlayedChunks` / `firstAudioChunkAt`, not chunk acceptance | [`voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart) |
| No cancel-before-play on new response | [`voice_call_controller_streaming_playback.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart), [`voice_call_controller_commands.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart) |
| Queue error aborts with no fallback handoff | [`streaming_audio_playback_queue.dart`](../../apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart) |
| Web background cancels queue on `assistant.done` | streaming events |
| `_streamingSpeakableText` can return empty for non-empty assistant text | streaming playback |

---

## The fix — one rule, no enum

**Rule:** The streaming queue owns playback if it accepted any chunk. Fallback runs only once, in the queue's drain callback, when zero chunks were accepted.

Use existing `hasAcceptedChunks` on [`StreamingAudioPlaybackQueue`](../../apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart). No playback mode enum.

### Exact behavior change

```text
BEFORE (broken):
  assistant.done → waitUntilIdle → if !hasPlayedChunks → fallback inline

AFTER (fixed):
  assistant.started → cancel any in-flight REST/typed playback
  assistant.audio_chunk → enqueue (sets hasAcceptedChunks)
  assistant.done → finishResponse() → wait for onQueueDrained
  onQueueDrained:
    if hasAcceptedChunks → completeSpeaking (queue handled audio)
    else if speakText non-empty && !muted → fallback synth once
    else → completeSpeaking (empty or muted)
```

### Three concrete edits

1. **Move fallback out of `assistant.done` inline block** into `onQueueDrained` callback. Delete the `playbackStarted = firstAudioChunkAt || hasPlayedChunks` check.

2. **Cancel-before-play on `assistant.started`** — stop `AudioPlaybackService` and cancel queue before new response begins.

3. **Queue error handoff** — if `onError` fires with `!hasPlayedChunks` and speak text exists, call fallback from error callback (same single fallback function).

### Speakable text

Fallback text = `completedText` if non-empty; else first pending proposal's `confirmation_text`. Non-empty assistant bubble must never reach drain with no audio and no fallback attempt.

### Web background

Do not cancel queue on `assistant.done` when backgrounded. Pause/resume via lifecycle events, or let drain complete — lifecycle-driven, not timer-driven.

---

## Key files

- [`voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart)
- [`voice_call_controller_streaming_playback.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart)
- [`streaming_audio_playback_queue.dart`](../../apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart)
- [`audio_playback_service.dart`](../../apps/mobile/lib/rex/voice/data/audio_playback_service.dart)
- [`voice_call_controller_commands.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart)
- [`voice_call_controller_test.dart`](../../apps/mobile/test/voice_call_controller_test.dart)

---

## Acceptance criteria

- [ ] Each assistant reply audible at most once
- [ ] Non-empty assistant text produces audio (streaming or fallback) when not muted
- [ ] Test: chunks enqueued but not yet playing → no fallback (no double-speak)
- [ ] Test: zero chunks, non-empty text → fallback once in drain callback

---

## Manual smoke steps

1. Run a 5-turn voice conversation — count audible replies vs assistant text bubbles (must match 1:1).
2. Mute/unmute mid-turn — verify expected behavior, no ghost audio.
3. Optional (web): background app during speaking — verify no double-play on return.

---

## Out of scope

- Backend TTS generation quality or chunk payload fixes
- Turn boundaries — [01-voice-turn-lifecycle-stability.md](./01-voice-turn-lifecycle-stability.md)
- Transcript and confirm cards — [03-transcript-proposal-integrity.md](./03-transcript-proposal-integrity.md)

---

## Coupling

Can ship independently. Self-contained playback logic. Cleaner phases from Plan 01 help but are not required.
