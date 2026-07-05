# 02 — Voice Transcript Dedup

**Branch:** `fix/voice-stability-july`  
**Symptom:** Multiple user bubbles from one utterance; garbled or old text in messages  
**Status:** Planned — not yet implemented  
**Depends on:** [01-voice-turn-lifecycle.md](./01-voice-turn-lifecycle.md)

---

## Repro steps

Based on Jul 5, 2026 screenshots:

1. Have a multi-turn voice conversation (pull-up bar → exercise combo → accountability).
2. Speak only: *"Okay. Make me accountable of all that. So I can start exercising every day."*

**Expected:** One user chat bubble with that utterance (allow normal STT variance).

**Observed:**
- **Three user bubbles** sent for one spoken intent:
  - *"Okay. Make me accountable of all that. So I can start exercising every day."*
  - *"Something like this. Yes. That that's exactly the a pull pull up window pull up..."* (old pull-up bar transcript)
  - *"Yeah. Make me a combo with the Yeah. Make me a con"* (fragment / misheard)
- Accountability request appears mixed with unrelated prior-turn text.
- User said "make me accountable" but chat shows *"Yeah. Make me a combo with the"*.

---

## Root cause

Specific files and functions:

| Location | Issue |
|----------|-------|
| [`apps/mobile/lib/rex/voice/application/voice_transcript_buffer.dart`](../../apps/mobile/lib/rex/voice/application/voice_transcript_buffer.dart) | `preferFullest` and `_appendSegment` concatenate segments; buffer may not be cleared between turns. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart) | `_finalizeVoiceTranscriptInChat` merges `finalTranscript`, buffer, **and existing chat message content** via `preferFullest` — stale chat text gets appended to new turns. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart) | `startCapturingSpeech` resets `_activeVoiceMessageLocalId` when transcript is empty and no active chat row → new `local-voice-*` bubble mid-session. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller.dart) | `completeSpeaking` also resets `_activeVoiceMessageLocalId` — correct timing, but combined with mid-utterance resets creates duplicate bubbles. |
| [`apps/mobile/lib/rex/chat/application/chat_controller_voice.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller_voice.dart) | `mergeBackendMessagesPreservingLocalVoice` keeps local rows not covered by backend normalized content — slight differences → duplicate user messages. |
| [`apps/mobile/lib/rex/chat/application/chat_controller_voice.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller_voice.dart) | `removeStaleLocalVoiceUserMessages` may not drop all interim locals from prior turns. |

**Message lifecycle today:**

```text
Interim: upsertVoiceUserMessage(local-voice-*)
Finalize: preferFullest(final + buffer + chat content) → finalizeVoiceUserMessage
Backend: mergeBackendMessagesPreservingLocalVoice → may keep extra local rows
```

---

## Proposed minimal fix

1. **Clear buffer at turn start**
   - Clear `_transcriptBuffer` when `_streamingTurnSequence` increments or at start of a fresh capture turn.

2. **Stop merging stale chat content**
   - Change `_finalizeVoiceTranscriptInChat` to use only `finalTranscript ?? _transcriptBuffer.visible`.
   - Remove `_activeVoiceMessageContent()` from `preferFullest` inputs.

3. **Stable local message ID per turn**
   - Do not reset `_activeVoiceMessageLocalId` in `startCapturingSpeech` mid-utterance.
   - Reset only when turn is fully complete (`completeSpeaking` or explicit turn boundary from Issue 01).

4. **Tighten stale local cleanup**
   - Extend `removeStaleLocalVoiceUserMessages` to drop interim `local-voice-*` rows from prior turns.

5. **Regression tests**
   - One spoken sentence → exactly one finalized user message.
   - Prior turn text not present in next turn's bubble.
   - Extend [`apps/mobile/test/chat_controller_voice_test.dart`](../../apps/mobile/test/chat_controller_voice_test.dart) for merge dedup edge cases if needed.

---

## Out of scope

- STT accuracy / Deepgram model quality (mishears like "combo" vs "accountable" at source)
- Turn boundary timing — [01-voice-turn-lifecycle.md](./01-voice-turn-lifecycle.md)
- TTS — [03-voice-tts-playback.md](./03-voice-tts-playback.md)

---

## Acceptance criteria

- [ ] One spoken utterance → **one** finalized user chat bubble
- [ ] No prior-turn transcript text in new messages
- [ ] `mergeBackendMessagesPreservingLocalVoice` does not leave duplicate user rows for same normalized content
- [ ] New tests pass

---

## Manual test steps

1. Run a 3-turn voice conversation: pull-up bar → combo recommendation → accountability request.
2. Confirm each turn produces **one** user bubble only.
3. Confirm accountability message text matches what was spoken (normal STT variance OK; prior-turn bleed is not).

---

## Key files to touch (implementation)

- `apps/mobile/lib/rex/voice/application/voice_transcript_buffer.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller_voice.dart`
- `apps/mobile/test/voice_call_controller_test.dart`
