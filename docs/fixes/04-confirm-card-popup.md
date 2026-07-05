# 04 — Confirm Card Popup

**Branch:** `fix/voice-stability-july`  
**Symptom:** Goals / Open Threads confirm dialog missing after title/description changes  
**Status:** Planned — not yet implemented  
**Depends on:** [01-voice-turn-lifecycle.md](./01-voice-turn-lifecycle.md), [02-voice-transcript-dedup.md](./02-voice-transcript-dedup.md)

---

## Repro steps

Based on Jul 5, 2026 voice session:

1. Voice conversation about exercise equipment and daily workout accountability.
2. Say: *"Okay. Make me accountable of all that. So I can start exercising every day."*

**Expected:** Confirm card popup for Goals or Open Threads (or clear text offer → card on "yes").

**Observed:**
- Assistant: *"I can check in on your workouts if you want—how should we start?"*
- **No confirm popup** appears.
- Popup previously worked before title/description extraction from chat paste was changed.
- Turn may feel silent because assistant response text is empty when a card is the contract.

---

## Root cause

Multi-layer — backend routing, empty response contract, and mobile attachment.

### Backend

| Location | Issue |
|----------|-------|
| [`services/rex-api/app/services/open_thread_eligibility.py`](../../services/rex-api/app/services/open_thread_eligibility.py) | `should_propose_open_thread_confirm_card()` returns false for vague topics — text offer first, card only after user consent. |
| [`services/rex-api/app/services/open_thread_turn_service.py`](../../services/rex-api/app/services/open_thread_turn_service.py) | Immediate card vs text-offer routing; card after explicit "yes" via `propose_open_thread`. |
| [`services/rex-api/app/services/durable_write_service.py`](../../services/rex-api/app/services/durable_write_service.py) | `_propose()` sets assistant response empty — card is the confirmation contract. Silent turn if mobile misses card. |
| [`services/rex-api/app/services/conversational_plan_service.py`](../../services/rex-api/app/services/conversational_plan_service.py) | Clear measurable goals may route to `plan` instead of open thread. |
| [`services/rex-api/app/services/chat_turn_orchestrator_short_circuit.py`](../../services/rex-api/app/services/chat_turn_orchestrator_short_circuit.py) | Short-circuit order: open thread → conversational plan → goal command → memory. |

### Mobile

| Location | Issue |
|----------|-------|
| [`apps/mobile/lib/rex/chat/application/chat_memory_change_parser.dart`](../../apps/mobile/lib/rex/chat/application/chat_memory_change_parser.dart) | `clarityActionCardsFromMemoryChanges` parses `write_proposals` from `memory_changes`. |
| [`apps/mobile/lib/rex/chat/application/chat_controller.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller.dart) | `applyBackendMessages` attaches cards to last assistant message. |
| [`apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`](../../apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart) | `ref.listenManual` on `chatProvider` → `pendingClarityActions` → `showClarityActionConfirmationDialog`. |
| [`apps/mobile/lib/rex/chat/presentation/widgets/clarity_action_cards_strip.dart`](../../apps/mobile/lib/rex/chat/presentation/widgets/clarity_action_cards_strip.dart) | `pendingClarityActions()` scans last assistant message for pending cards. |
| [`apps/mobile/lib/rex/chat/presentation/widgets/chat_transcript.dart`](../../apps/mobile/lib/rex/chat/presentation/widgets/chat_transcript.dart) | Inline cards suppressed in chat mode (`suppressClarityActions: true`) — dialog is mandatory. |
| [`apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart) | `messages.updated` must pass `memoryChanges` to `applyBackendMessages`. |
| [`apps/mobile/lib/rex/voice/presentation/voice_clarity_action_listener.dart`](../../apps/mobile/lib/rex/voice/presentation/voice_clarity_action_listener.dart) | Dialog on non-chat tabs during voice; Chat tab uses chat page listener only. |

### Cross-cutting (Issues 01–02)

Duplicate or garbled user messages from voice may route to the wrong backend handler or prevent proposal attachment to the correct turn.

**End-to-end flow:**

```text
User message → ChatTurnOrchestrator short-circuit
  → write_proposals in memory_changes (or text offer only)
  → messages.updated / chat stream
  → applyBackendMessages → clarityActions on last assistant message
  → pendingClarityActions → showClarityActionConfirmationDialog
```

---

## Proposed minimal fix

1. **Verify backend emission**
   - Log whether `memory_changes.write_proposals` is emitted for accountability phrasing.
   - Adjust eligibility using **generic** accountability/plan signals (not topic-specific smoke phrases) OR ensure text-offer → card-on-yes flow is visible and tested.

2. **Mobile safety net for attachment**
   - If `write_proposals` pending but no assistant message exists, synthesize a local assistant placeholder row so cards attach.

3. **Voice parity**
   - Ensure `messages.updated` always passes `memoryChanges` to `applyBackendMessages`.
   - Verify `VoiceClarityActionListener` on non-chat tabs; chat page listener on Chat tab during active voice.

4. **UX fallback when response is empty**
   - When proposal pending and response empty, still show dialog.
   - Speak `confirmation_text` via existing `_streamingSpeakableText` in [`voice_call_controller_streaming_playback.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_playback.dart).

5. **Tests**
   - Backend: accountability phrasing → proposal or offer+card-on-yes (`test_open_thread_turn_service.py` or new case).
   - Mobile: dialog trigger on voice turn with `write_proposals` (`chat_controller_test.dart`, `voice_clarity_actions_test.dart`).

---

## Out of scope

- Rewriting title/description extraction (`open_thread_title.py`, `conversational_plan_candidate.py`) unless tests prove bad titles block proposals
- Voice turn lifecycle — fix Issues 01–02 first
- Latency — [05-voice-latency-retune.md](./05-voice-latency-retune.md)

---

## Acceptance criteria

- [ ] *"Make me accountable... exercising every day"* shows confirm card **or** clear text offer → card on "yes"
- [ ] Dialog appears on Chat tab during active voice call
- [ ] Card has sensible title/description (not raw chat paste)
- [ ] Empty assistant text still triggers popup when proposal exists
- [ ] Confirm → item appears in Goals or Open Threads without manual refresh

---

## Manual test steps

1. **Voice:** accountability request → expect popup or offer + card on "yes".
2. **Chat typed:** same phrase → same behavior as voice.
3. **Confirm card** → verify item in Goals (plan) or Open Threads as appropriate.
4. **Decline card** → verify no silent failure; assistant acknowledges.

---

## Key files to touch (implementation)

**Backend:**
- `services/rex-api/app/services/open_thread_eligibility.py`
- `services/rex-api/app/services/open_thread_turn_service.py`
- `services/rex-api/tests/test_open_thread_turn_service.py`

**Mobile:**
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller_streaming_events.dart`
- `apps/mobile/lib/rex/voice/presentation/voice_clarity_action_listener.dart`
