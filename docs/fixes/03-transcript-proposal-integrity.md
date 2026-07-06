# 03 — Transcript & Proposal Integrity

**Status:** Planned — not yet implemented  
**Replaces:** old 02 (Voice Transcript Dedup) + old 04 (Confirm Card Popup)

---

## Generic failure class

**`TurnArtifactCorruption`** — the user message and its downstream proposal are not one isolated, trustworthy turn artifact. Transcript text is merged from stale stores; proposals fail to attach or surface when the turn artifact is wrong or incomplete.

---

## Canon compliance

- [`docs/CLARITY_RULES.md`](../CLARITY_RULES.md) Truth Rule: confirm surfaces must be visible before Rex implies a save
- [`docs/CLARITY_RULES.md`](../CLARITY_RULES.md): voice and chat share the same memory and reasoning system
- [`docs/PROJECT_STRUCTURE.md`](../PROJECT_STRUCTURE.md) §7: durable writes require confirm card → `write_confirmation` → visible in Knows/Goals
- [`docs/MASTER_PLAN.md`](../MASTER_PLAN.md) §5: nothing saved secretly; user must see and control all saves

---

## Problem

- One utterance → multiple user chat bubbles, or prior-turn text in current bubble
- Durable write proposed by backend but confirm dialog never appears
- Voice speaks a confirm question with no visible confirm control (truth violation)

---

## Root cause (two faces, one class)

**Face A — transcript:** `_finalizeVoiceTranscriptInChat` merges buffer + chat read-back via `preferFullest`; local message ID resets mid-utterance.

**Face B — proposal:** Corrupted user message reaches `ChatTurnOrchestrator` with wrong text, or mobile drops `memoryChanges` / fails to surface `pendingClarityActions`.

Fixing A reduces B failures. B also has independent mobile attachment bugs.

| Location | Issue |
| --- | --- |
| [`voice_call_controller_chat_sync.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart) | `_finalizeVoiceTranscriptInChat` merges `finalTranscript`, buffer, and `_activeVoiceMessageContent()` |
| [`voice_call_controller_commands.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart) | `_activeVoiceMessageLocalId` reset mid-utterance in `startCapturingSpeech` |
| [`voice_transcript_buffer.dart`](../../apps/mobile/lib/rex/voice/application/voice_transcript_buffer.dart) | Buffer not cleared at turn start |
| [`chat_controller_voice.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller_voice.dart) | `removeStaleLocalVoiceUserMessages` only drops substring-related locals |
| [`open_thread_eligibility.py`](../../services/rex-api/app/services/open_thread_eligibility.py) | Text-offer path intentional (no card until consent) — must not confuse with delivery gap |
| [`chat_controller.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller.dart) | Cards attach to last assistant message only; no placeholder when row missing |
| [`voice_clarity_action_listener.dart`](../../apps/mobile/lib/rex/voice/presentation/voice_clarity_action_listener.dart) | Dialog on non-chat tabs only via shell bar |

---

## The fix — one turn artifact, end-to-end

### Part A: Turn-scoped transcript (mobile)

**Rule:** Each `_streamingTurnSequence` gets exactly one transcript source and one chat row.

| Lifecycle point | Action |
| --- | --- |
| Turn start (`++_streamingTurnSequence`) | Clear `_transcriptBuffer`; allocate `local-voice-{turnSequence}` ID |
| Interim updates | Upsert that single local row from buffer only |
| Finalize | Text = `finalTranscript ?? _transcriptBuffer.visible` — **never** read chat back |
| Finalize | Drop all other `local-voice-*` rows |
| Turn complete (`completeSpeaking`) | Reset local ID |

Concrete edits:

1. [`voice_call_controller_chat_sync.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart) — remove `_activeVoiceMessageContent()` from `_finalizeVoiceTranscriptInChat`
2. [`voice_call_controller_commands.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart) — stop resetting `_activeVoiceMessageLocalId` in `startCapturingSpeech`
3. [`voice_call_controller_streaming_capture.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart) — clear buffer + assign local ID at turn start
4. [`chat_controller_voice.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller_voice.dart) — `removeStaleLocalVoiceUserMessages`: drop all other locals, not substring-only

### Part B: Proposal delivery (backend + mobile)

**Rule:** If backend emits `write_proposals` with `confirmation_required: 1`, mobile must attach cards and show dialog. Voice and chat use identical path.

Backend (only if eligibility genuinely blocks valid intents):

- Audit [`open_thread_eligibility.py`](../../services/rex-api/app/services/open_thread_eligibility.py) / [`open_thread_turn_service.py`](../../services/rex-api/app/services/open_thread_turn_service.py) with **generic** accountability/continuity signals — not phrase-specific triggers
- Preserve intentional text-offer → card-on-consent path (document as valid, not a bug)
- Voice/chat parity tests in [`test_open_thread_voice_parity.py`](../../services/rex-api/tests/test_open_thread_voice_parity.py)

Mobile invariants:

1. `messages.updated` always passes `memoryChanges` to `applyBackendMessages` ([`voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart))
2. If proposals pending and no assistant row → synthesize placeholder assistant message before attaching cards ([`chat_controller.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller.dart))
3. `pendingClarityActions` non-empty → dialog on Chat tab ([`chat_page.dart`](../../apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart)) and shell bar ([`voice_clarity_action_listener.dart`](../../apps/mobile/lib/rex/voice/presentation/voice_clarity_action_listener.dart))
4. Empty assistant `response` + pending proposal is valid **only when** dialog appears; TTS uses `confirmation_text` ([`voice_call_controller_streaming_playback.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart))

### Internal implementation order

1. Part A first (clean user message)
2. Part B second (attachment + surfacing)
3. Backend eligibility audit last (only if tests show routing gap)

---

## Key files

**Mobile:**

- `apps/mobile/lib/rex/voice/application/voice_call_controller_chat_sync.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_commands.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_capture.dart`
- `apps/mobile/lib/rex/voice/application/voice_transcript_buffer.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller_voice.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`
- `apps/mobile/lib/rex/voice/presentation/voice_clarity_action_listener.dart`

**Backend:**

- `services/rex-api/app/services/open_thread_eligibility.py`
- `services/rex-api/app/services/open_thread_turn_service.py`
- `services/rex-api/app/services/durable_write_service.py`
- `services/rex-api/tests/test_open_thread_voice_parity.py`

**Tests:**

- `apps/mobile/test/voice_call_controller_test.dart`
- `apps/mobile/test/chat_controller_voice_test.dart`
- `apps/mobile/test/voice_clarity_actions_test.dart`

---

## Acceptance criteria

- [ ] One utterance → one finalized user bubble; no prior-turn bleed
- [ ] Pending durable write → confirm dialog visible on voice (Chat tab and other tabs)
- [ ] Voice and typed chat produce same proposal behavior for same intent class
- [ ] Confirm → item in Knows/Goals without manual refresh
- [ ] Empty assistant text + proposal still shows popup

---

## Manual smoke steps

1. Multi-turn voice conversation — each turn produces exactly one user bubble.
2. Request accountability or save intent via voice — expect confirm dialog or text-offer → card on "yes".
3. Same intent via typed chat — identical behavior.
4. Confirm card → verify item in Goals or Open Threads; decline → no silent failure.

---

## Out of scope

- STT model accuracy / Deepgram mishears at source
- Turn endpoint timing — [01-voice-turn-lifecycle-stability.md](./01-voice-turn-lifecycle-stability.md)
- TTS playback — [02-voice-playback-authority.md](./02-voice-playback-authority.md)

---

## Coupling

Can ship independently — includes its own turn-scoped transcript rules. Plan 01 makes turn boundaries deterministic (soft benefit, not a hard blocker).
