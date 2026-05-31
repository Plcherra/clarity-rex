# Rex Assistant Polish & Refactor Master Plan

Purpose: refactor and polish the full Rex Assistant module so Chat, Voice, Memory, Goals, Chats, and Deep Think feel like one premium personal AI co-pilot instead of separate feature experiments.

Working rule: implement one plan file and one phase at a time. Each phase must be small enough to complete, test, review, and safely ship without mixing unrelated refactors.

## Executive Summary

Rex is now functional: it can chat, use financial context, remember, route through the brain layer, stream voice, expose goals/accountability data, and show conversation history. The remaining issue is product quality. Several Assistant surfaces still feel uneven:

- Navigation has competing concepts: Chat, Voice, Memory, Goals, Chats, Deep Think, call state, and conversation state.
- Memory and Goals are structurally related but visually and conceptually blurred.
- Pending memory candidates can leak raw backend labels into user-facing UI.
- Voice works but needs better error recovery, route diagnostics, earbud/audio-session confidence, and latency polish.
- Chat and Deep Think are wired but need clearer UX contracts, routing visibility, and graceful fallback.
- Empty, loading, and error states are inconsistent across Assistant screens.
- The UI language is still utilitarian in places, and some controls feel attached after the fact.

This plan turns the Assistant module into a cohesive product area with clear ownership boundaries, predictable state flows, and a refined mobile experience. It keeps live behavior safe by preserving existing paths until each replacement is tested and reviewed.

## Risks & Dependencies

- Voice streaming is the highest-regression surface because it depends on mobile permissions, iOS audio sessions, Bluetooth routing, WebSocket stability, Deepgram, Grok, Google TTS, and backend conversation persistence.
- Memory and Goals share backend accountability/memory data, so UI cleanup must preserve durable memory persistence while preventing raw candidate records from leaking into Goals.
- Rex Brain rollout stages must be coordinated with VPS env flags; advanced routing should stay gated until chat and voice smoke tests pass on a real device.
- Real-device testing is required for Assistant release confidence, especially Voice + earbuds/Bluetooth, keyboard/composer behavior, safe-area layout, and background audio interruptions.

## Overall Architecture Vision

Rex Assistant should be organized around three layers:

1. **User Experience Layer**
   - One Assistant shell with stable top navigation.
   - Clear tabs: Chat, Voice, Memory, Goals, Chats.
   - Shared empty/loading/error components.
   - Deep Think presented as a capability inside Chat/Voice, not a disconnected mode.

2. **Assistant State Layer**
   - Chat state owns current conversation and message composition.
   - Voice state owns streaming call lifecycle, audio route, transcript, and recovery.
   - Memory state owns durable facts, pending memory review, and correction candidates.
   - Goals state owns plans, milestones, commitments, and progress.
   - Conversation history state owns search, archive, resume, and metadata.

3. **Backend Intelligence Layer**
   - Rex Brain remains behind rollout gates.
   - Backend routes expose safe response contracts, never raw internal labels.
   - Voice and chat share the same intelligence path but apply different latency budgets.
   - Memory writes and goal actions remain confirmed, observable, and reversible.

Text diagram:

```text
Assistant Shell
  -> Chat Tab
      -> ChatController
      -> ChatApi
      -> Rex Brain / ChatService
  -> Voice Tab
      -> VoiceCallController
      -> StreamingVoiceApi
      -> VoiceStreamSession -> ChatService -> Rex Brain
  -> Memory Tab
      -> MemoryApi
      -> Durable memories + pending memory review
  -> Goals Tab
      -> AccountabilityApi
      -> Plans + milestones + commitments only
  -> Chats Tab
      -> ConversationApi
      -> Search + resume + archive

Shared Support
  -> Assistant design components
  -> Empty/loading/error surfaces
  -> Observability + release checklist
```

## Plan Files

1. `01_navigation_structure.md`
   - Refactor Assistant shell navigation, tab layout, header behavior, conversation icon placement, and state ownership between Chat, Voice, Memory, Goals, and Chats.

2. `02_memory_system.md`
   - Clean Memory UX, pending memory review, candidate copy, type labels, correction flows, and backend/frontend contracts for memory data.

3. `03_goals_module.md`
   - Separate Goals from Memory internals, refine plans/milestones/commitments UI, remove raw candidate leakage, and make goals feel actionable.

4. `04_conversations_history.md`
   - Polish Chats/history tab with search, resume behavior, archive/delete copy, empty states, timestamps, and conversation-topic previews.

5. `05_deep_think_brain_routing.md`
   - Integrate Deep Think and Rex Brain routing cleanly across Chat and Voice, with safe rollout stages, fallback behavior, debug boundaries, and user-facing affordances.

6. `06_voice_stability_ux.md`
   - Stabilize voice streaming, call lifecycle, audio routing, earbuds/speaker behavior, transcript visibility, latency, recovery, and diagnostics.

7. `07_chat_experience_polish.md`
   - Improve message bubbles, composer, attachments, voice entry, memory/clarity action cards, scrolling, keyboard behavior, and response readability.

8. `08_empty_loading_error_states.md`
   - Create consistent Assistant states for loading, degraded backend, missing permissions, empty content, retryable failures, offline/network issues, and partial data.

9. `09_design_system_consistency.md`
   - Align Assistant typography, icon sizes, chips, cards, spacing, color roles, button styles, nav states, and accessibility semantics.

10. `10_testing_release_readiness.md`
    - Build the final release gate: automated tests, manual phone scenarios, backend readiness, VPS rollout, rollback, observability, and acceptance signoff.

## Global Definition Of Done

The Assistant polish project is done when:

- Assistant navigation feels intentional on every tab and no icon appears detached from the UI.
- Chat, Voice, Memory, Goals, and Chats each have one clear job and no screen leaks raw backend implementation labels.
- Goals shows goals/plans/commitments, not memory-candidate internals.
- Memory shows memory review and correction work with clear, human labels and safe approve/reject/edit flows.
- Voice can recover from stream errors without trapping the user, logs useful backend diagnostics, and preserves visible transcript state.
- Voice respects mobile audio-session expectations as much as Flutter/iOS APIs allow, including Bluetooth/earbud routing checks.
- Deep Think is understandable to the user, controllable, and safe behind backend rollout stages.
- Empty, loading, and error states use shared components and consistent copy.
- Backend errors never expose private internals to the app, but logs are useful enough to debug production failures.
- All new phases include focused tests or a documented reason why manual phone testing is required.
- `flutter analyze`, relevant Flutter tests, backend pytest, and `git diff --check` pass before phone release.
- Release instructions are clear: git push, VPS pull/restart, mobile release script, phone smoke test, rollback path.
- Success metric: no raw backend labels such as `long_term_memory`, `entity`, `candidate_type`, or route metadata are visible in user-facing Assistant screens.
- Success metric: a user can complete a Chat -> Voice -> Memory -> Goals -> Chats flow on device without losing context or seeing a confusing state.
- Success metric: voice testing shows recovery from common failures in at least 85% of manual retry scenarios, with useful backend logs for the remaining failures.

## Execution Order

Recommended order:

1. Navigation and structure first, because it defines where each feature belongs.
2. Memory and Goals next, because their current boundary is the most visibly confusing.
3. Conversations and Chat polish after the shell is stable.
4. Deep Think and Voice after UX ownership is clear.
5. Empty/error states and design consistency near the end to normalize all surfaces.
6. Final release readiness last.

## Non-Goals

- Do not redesign the entire app outside the Assistant module.
- Do not add unconfirmed financial or memory mutation features.
- Do not enable advanced Rex Brain rollout stages by default.
- Do not introduce a new state-management framework.
- Do not replace the existing backend service architecture unless a phase explicitly proves the need.

## Current Cursor

Current cursor: `01_navigation_structure.md` is complete through automated verification, and `02_memory_system.md` Phases 1-9 plus the Phase 10 automated gate are complete after review fixes. Complete the Memory phone smoke test in `docs/clarity/device_release_checklist.md`, then continue with `03_goals_module.md` Phase 1.
