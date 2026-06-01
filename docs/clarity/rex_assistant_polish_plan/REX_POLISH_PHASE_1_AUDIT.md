# Rex Polish Phase 1 Audit

Status: Complete
Date: June 1, 2026

## Purpose

This audit documents the current Rex chat, voice, and memory implementation before the remaining polish work. The goal is to make the next phases concrete: fix memory reliability first, keep the new voice direction stable, then bring the main text chat up to the same product quality.

## Visual Direction: What "Premium" Means for Rex

Premium for Rex should mean calm, clear, and reliable. The interface should feel like a trusted financial and personal assistant, not a novelty chatbot.

Design goals:

- Use the existing Clarity theme, Material color scheme, typography, icon style, spacing, and surface treatments consistently.
- Prefer quiet hierarchy over decorative effects: fewer competing cards, fewer nested containers, clearer primary actions.
- Make every state feel intentional: empty, loading, listening, thinking, speaking, failed, retrying, saved, pending, and archived.
- Treat memory as "what Rex knows about me", not as a backend table. Labels, grouping, and confirmation states should reinforce trust.
- Keep voice and text chat visually related. Voice can have richer motion, but it should not feel like a separate experiment.
- Use restraint with elevation, borders, and filled surfaces. Important actions should be obvious without the screen feeling busy.

## Entry Point Map

Mobile Rex navigation:

- `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart`
  - Chat tab opens `ChatPage`.
  - Voice tab now opens the dedicated `VoiceChatPage`.
  - Memory tab opens `MemoryPage`.
  - Goals tab opens `AccountabilityPage`.
  - Chats tab opens `ConversationListPage`.

Text chat:

- `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_input_bar.dart`

Voice chat:

- `apps/mobile/lib/features/assistant/voice/presentation/pages/voice_chat_page.dart`
- `apps/mobile/lib/features/assistant/voice/presentation/widgets/voice_call_controls.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`

Memory UI and mobile state:

- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_api.dart`

Backend memory and prompt path:

- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/memory_service.py`
- `services/rex-api/app/services/memory_extraction_service.py`
- `services/rex-api/app/services/memory_candidate_service.py`
- `services/rex-api/app/services/memory_discipline_service.py`
- `services/rex-api/app/routes/memory.py`
- `services/rex-api/app/routes/memory_candidates.py`

Backend voice paths:

- `services/rex-api/app/routes/voice.py`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/app/services/voice_stream_session.py`

## Current Text Chat Audit

The text chat works, but still reads as a traditional chatbot surface rather than the polished Rex experience.

Issues:

- `chat_message_bubble.dart` is 811 lines and combines message bubbles, assistant avatar treatment, memory candidate cards, action cards, painters, and helper UI. This makes polish risky and encourages inconsistent local styling.
- Message bubbles use a custom tail painter and strong user bubble fill. It is functional, but it feels more like an older messenger UI than a premium assistant surface.
- Memory candidate cards are embedded inside bubbles and can become visually dense. They need to feel like trusted review requests, not cramped metadata cards.
- `chat_input_bar.dart` uses a persistent elevated composer with a visible Deep Think chip above the row. The result is useful, but visually heavy for a default chat state.
- Attach, voice, and send actions compete for weight in the composer. Voice should feel connected to the dedicated Voice tab, while send remains the obvious primary action.
- Empty, loading, and error states are present, but should be more designed and consistent with the new Voice page state language.
- The inline voice call panel in `chat_page.dart` is now secondary to `VoiceChatPage`. It should be harmonized or simplified during Phase 4 so text chat does not carry two competing voice concepts.

## Current Voice Chat Audit

Phase 3 has already upgraded voice from a primitive tab action into a dedicated screen.

Strengths:

- `VoiceChatPage` separates idle and active voice states.
- REST voice turns in `routes/voice.py` call `chat_service.send_message(..., channel=RexBrainChannel.VOICE)`.
- Streaming voice in `voice_stream_session.py` calls `chat_service.stream_message(..., channel=RexBrainChannel.VOICE)`.
- Because both voice paths share `ChatService`, voice should use the same memory-enriched prompt context as text chat.
- `VoiceCallControls` is now a reusable control strip with explicit start, retry, mute, end, interrupt, and settings actions.

Remaining issues:

- `VoiceChatPage` is 633 lines and contains multiple private visual components. It is acceptable for the Phase 3 implementation, but should be componentized after phone validation.
- The call duration label watches `voiceCallNowProvider`, which returns `DateTime.now`. Unless another state change rebuilds the widget, the visible timer may not tick every second.
- The voice meter uses static phase-based heights. It gives clear visual feedback, but it is not actually audio-level reactive.
- The "Pause" label for interrupting Rex may be ambiguous. "Interrupt" or "Listen" may be clearer after manual testing.
- Small iPhone layout, long transcript overflow, permission failure, reconnect, and real audio state transitions still need manual phone validation.

## Current Memory System Audit

Memory now has a safer architecture than a direct auto-save table, but that safety can make the experience feel like memory is broken unless the product explains it clearly.

Observed flow:

1. Chat builds prompt context with recent conversation, relevant long-term memory, profile memory, and structured memory in `ChatService._fetch_prompt_context`.
2. Relevant memories are fetched with `memory_service.get_relevant_memories(query=message, limit=8)`.
3. After a successful chat response, `ChatService._schedule_memory_extraction` starts best-effort background extraction.
4. Extraction creates pending memory candidates rather than always writing durable memory immediately.
5. A candidate only becomes durable after approval through `MemoryCandidateService.approve_candidate`.
6. Approval applies the candidate, writes the durable record, and verifies that the applied record exists.
7. Mobile `MemoryController` loads saved memory and pending candidates together for the Memory page.

Strengths:

- Durable writes are explicit and verified.
- High-risk corrections require confirmation.
- Pending candidate editing is real and updates the candidate payload before approval.
- Mobile memory loading uses parallel fetches for saved memory and pending candidates.
- Saved memory and pending memory are separated in the Memory page, which supports the "what Rex knows about me" direction.

Root-cause hypotheses for "memories are not saving":

- The memory extraction task is best effort and backgrounded. If extraction fails, the chat response still succeeds and the user may never see why no memory appeared.
- New memory is candidate-based. If the user has not approved the candidate, nothing durable has been saved yet. This can feel like failure unless the UI makes "pending review" obvious.
- Candidate approval can fail if the payload is incomplete, for example a long-term memory candidate without `memory_type` or `content`.
- Chat confirmations only look at pending candidates for the current `source_conversation_id`. If the conversation id changes or a candidate is detached, "save that" may not find it.
- Durable recall is term-ranked from scanned memory records. If a saved memory uses different wording than the next user query, Rex may not include it in prompt context.
- The prompt only receives the top merged memory set. Important but lexically distant memories can be crowded out.

Root-cause hypotheses for "memories are not recalled":

- `get_relevant_memories` uses expanded term matching and ranking, not semantic retrieval. This is predictable but limited.
- Structured memory and long-term memory are fetched separately, then prompt budget trimming can remove lower-ranked items.
- Voice should share the same memory path through `ChatService`, but there is no explicit end-to-end test proving an approved memory appears in both text and voice prompt context.
- The mobile Memory page can show saved data correctly while the chat prompt still omits it due to retrieval ranking. These are separate success criteria.

## Test Coverage Notes

Existing useful coverage:

- Mobile memory page tests cover saved vs pending separation, approve, edit, archive, filters, and safe error copy.
- Mobile assistant navigation tests cover that the Voice tab opens without auto-starting a call.
- Backend memory route tests cover listing, patching, deactivation, validation, and error mapping.
- Backend prompt service tests cover memory injection into prompt content.
- Backend voice stream route tests cover streaming turn flow and voice events.

Gaps to close in Phase 2:

- End-to-end backend test: chat creates candidate, user approves it, durable memory is written, next text chat prompt receives it.
- End-to-end backend test: approved memory is available to a voice turn through `RexBrainChannel.VOICE`.
- Failure visibility test: candidate approval failure returns a user-safe, actionable message.
- Retrieval quality test: profile/preferences should be recalled for related queries even when wording differs.

## Reusable Components to Create or Update

Create or extract:

- `RexSurface`: shared bounded surface for assistant panels and review cards.
- `RexStateHeader`: title, subtitle, icon, tone, optional trailing status.
- `RexStatusPill`: small consistent state label for pending, saved, listening, thinking, failed.
- `RexActionRow`: consistent primary/secondary/destructive action layout.
- `RexReviewCard`: shared visual treatment for memory candidate and in-chat review items.
- `RexEmptyState`: quiet empty state with optional action.
- `RexErrorState`: user-safe error display with retry action.
- `RexComposer`: polished chat input surface with attachments, Deep Think, voice entry, and send hierarchy.

Update:

- `ChatMessageBubble`: reduce visual weight, remove or soften tail treatment, split memory/action cards out.
- `ChatInputBar`: make the composer quieter and more consistent with the Voice tab controls.
- `VoiceCallControls`: refine naming and disabled state behavior after phone testing.
- `MemoryPage`: gradually split the 2,196-line page into smaller components once behavior is stable.

## Prioritized Fix List

P0: Memory reliability verification

- Prove an approved memory is durably written and loaded by the next text chat turn.
- Prove the same approved memory is available to voice turns.
- Add tests for candidate approval failure and user-safe error copy.

P1: Memory recall quality

- Improve retrieval so important profile facts and preferences are recalled even when the query wording changes.
- Add focused tests for profile/preference recall.
- Make pending vs saved memory status unmistakable in chat and Memory.

P2: Voice follow-up polish

- Add a real ticking duration source or remove the live timer.
- Validate long transcripts, permission failures, reconnect states, and small iPhone layouts on device.
- Refine interrupt control copy.

P2: Text chat visual polish

- Redesign bubbles, composer, and memory candidate cards around the new visual direction.
- Extract shared Rex components before additional visual changes.
- Align inline voice state with the dedicated Voice tab.

P3: Refactor and scale

- Split large UI files after behavior is locked.
- Add server-side search/pagination for memory if the memory list grows.
- Consider semantic retrieval later if term-ranked recall remains weak.

## Acceptance Criteria for Next Phases

Phase 2 is complete when:

- A memory-worthy text conversation creates a pending candidate or safe visible status.
- Approving that candidate writes a durable memory.
- The saved memory appears in Memory.
- Rex recalls it in a later text chat.
- Rex recalls it in a voice turn.
- Backend and mobile tests cover the fixed path.

Phase 3 is complete when:

- The dedicated Voice page passes manual phone validation.
- Idle, active, failed, muted, listening, thinking, and speaking states look coherent.
- Voice controls are understandable without extra explanation.

Phase 4 is complete when:

- Text chat feels visually aligned with Voice.
- Bubbles, composer, memory cards, empty state, and errors feel like one system.
- Chat remains ergonomic with keyboard, streaming, attachments, memory review, and tab switching.

## Recommended Execution Order From Here

1. Finish Phase 2 memory verification and fixes.
2. Run the manual phone smoke test for the already-implemented Phase 3 voice UI.
3. Use the voice visual direction to execute Phase 4 text chat polish.
4. Refactor large files only after the behavior and visual direction are stable.
