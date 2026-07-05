# 03 — Voice TTS Playback

**Branch:** `fix/voice-stability-july`  
**Symptom:** Assistant replies spoken twice, or text-only with no audio  
**Status:** Planned — not yet implemented  
**Depends on:** [01-voice-turn-lifecycle.md](./01-voice-turn-lifecycle.md), [02-voice-transcript-dedup.md](./02-voice-transcript-dedup.md)

---

## Repro steps

Based on Jul 5, 2026 voice session:

**Not spoken (text only):**
- *"Sounds like you want a door or window pull-up bar? What exercises are you going for exactly?"*
- *"A simple door-mounted pull-up bar like the Iron Gym should fit your needs for pull-ups, back work, and abs."*

**Spoken twice:**
- *"Sure, pair the Iron Gym bar with pull-ups for your back, hanging knee raises for abs, and pike push-ups to build on what you already do."*
- *"I can check in on your workouts if you want—how should we start?"*

**Expected:** Each assistant reply is spoken exactly once when not muted.

---

## Root cause

Specific files and functions:

| Location | Issue |
|----------|-------|
| [`apps/mobile/lib/rex/voice/data/audio_playback_service.dart`](../../apps/mobile/lib/rex/voice/data/audio_playback_service.dart) | Single `AudioPlayer` shared by all playback paths. |
| [`apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart`](../../apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart) | Chunked streaming TTS queue for `assistant.audio_chunk` events. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart) | On `assistant.done`, checks `playbackStarted` before late chunks may arrive → may trigger fallback while queue also plays. Web background cancels queue immediately. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart) | `_playSynthesizedStreamingFallback` uses separate `playBase64Audio` path — can race with streaming queue. `_streamingSpeakableText` handles empty response + pending proposals. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart) | `beginTypedTextTurn` can start parallel synth while streaming session is active. |
| [`apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`](../../apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart) | Typed message during voice → `speakTypedAssistantResponse` — second TTS path. |

**Playback paths (all share one player):**

```text
Streaming: assistant.audio_chunk → StreamingAudioPlaybackQueue
Fallback:  assistant.done + no chunks → _playSynthesizedStreamingFallback
REST:      cloudVoiceApi.sendVoiceTurn → playBase64Audio
Typed:     speakTypedAssistantResponse → synthesize → playBase64Audio
```

**Double-speak race:**

```text
assistant.done fires → playbackStarted=false → fallback starts
Late audio_chunk arrives → queue also plays → user hears reply twice
```

**Silent reply causes:**
- All `assistant.audio_chunk` payloads empty → queue never plays
- Fallback synth fails or returns empty audio
- Web tab backgrounded → queue cancelled on `assistant.done`
- Mute state skips fallback
- `waitUntilIdle` timeout → cancel before user hears audio

---

## Proposed minimal fix

1. **Explicit playback mode per response**
   - Enum: `streamingChunks` | `fallbackSynth` | `none`
   - Only one mode active per assistant response.

2. **Lock streaming when chunks are enqueued**
   - On first accepted chunk enqueue, lock to streaming mode.
   - Suppress fallback if any chunk was enqueued (even if not yet played).

3. **Defer fallback decision**
   - Wait for queue idle **or** 500ms grace after last chunk enqueue before choosing fallback.

4. **Cancel parallel paths**
   - Cancel typed-path / fallback playback when streaming response begins (`assistant.started`).
   - Ensure `beginTypedTextTurn` stops active streaming playback cleanly.

5. **Debug logging**
   - Extend `rex_voice_playback` logs with path taken per turn: `chunk`, `fallback`, `none`, `cancelled`.

6. **Regression tests**
   - `assistant.done` before chunks, chunks arrive late → single playback.
   - Empty chunks + non-empty text → fallback speaks once.

---

## Out of scope

- Backend TTS generation quality or chunk payload fixes
- Turn lifecycle — [01-voice-turn-lifecycle.md](./01-voice-turn-lifecycle.md)
- Confirm card spoken text via `_streamingSpeakableText` — coordinate but primary fix is mutual exclusion

---

## Acceptance criteria

- [ ] Each assistant reply spoken **at most once**
- [ ] Non-empty assistant text always has audible output (streaming or fallback) when not muted
- [ ] No double audio on the two repro messages listed above
- [ ] New tests pass

---

## Manual test steps

1. Run a 5-turn voice conversation — count audible replies vs assistant text bubbles (must match 1:1).
2. Mute/unmute mid-turn — verify expected behavior, no ghost audio.
3. Optional (web): background app during speaking — document expected degradation, no crash.

---

## Key files to touch (implementation)

- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart`
- `apps/mobile/lib/rex/voice/data/streaming_audio_playback_queue.dart`
- `apps/mobile/lib/rex/voice/data/audio_playback_service.dart`
- `apps/mobile/test/voice_call_controller_test.dart`
