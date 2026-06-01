# Rex Polish and Memory Master Plan

Purpose: fix the parts of Rex that currently make the experience feel primitive, unreliable, or visually unfinished. This plan has exactly four execution phases: audit, memory fix, voice UI modernization, and main chat polish.

### Visual Direction & Design Goals

- Use the existing Clarity design system consistently (colors, typography, spacing, surfaces, elevation).
- Aim for a **premium, calm, and trustworthy** feeling — not flashy or overly playful.
- Voice chat should feel like a natural extension of the main chat, not a separate experimental feature.
- Reduce visual noise and improve hierarchy.
- All states (empty, loading, error, success) must be properly designed.

Scope rules:

- Do not redesign unrelated Clarity areas.
- Do not add new assistant features until memory saving/retrieval is reliable.
- Keep memory mutations explicit, validated, and observable.
- Verify each phase before moving to the next.

## Phase 1: Full Audit & Analysis

Goal: understand the current Rex text chat, voice chat, and memory system before changing behavior or UI.

Status: Complete. Audit captured in `REX_POLISH_PHASE_1_AUDIT.md`.

1. Map the current Rex entry points and navigation paths for Chat, Voice, Memory, and conversation history.
2. Audit the text chat UI: message bubbles, spacing, colors, typography, composer, loading states, streaming states, memory cards, and error states.
3. Audit the voice chat UI: idle state, active call state, transcript display, controls, visual hierarchy, empty states, permissions, and disconnect/error states.
4. Audit the current memory save path from chat extraction through pending candidates, approval, durable persistence, retrieval, and prompt-context injection.
5. Identify why memories are not saving or not being recalled properly, separating frontend display bugs from backend persistence or retrieval bugs.
6. Review existing tests and logs for memory candidate creation, approval, rejection, correction, retrieval, and prompt context usage.
7. Produce a concise issue list grouped by severity: memory reliability blockers, primitive UI issues, confusing copy, missing states, and refactor risks.
8. Define the minimum acceptance criteria for Phases 2-4 so each phase can be verified without scope creep.

Deliverables:

- Audit notes with file references.
- Root-cause hypothesis for memory save/retrieval failures.
- Prioritized fix list for Memory, Voice UI, and Chat UI.
- Visual direction document defining what "premium" means for Rex.
- List of reusable components that should be created or updated.

## Phase 2: Fix Memory System

Goal: make Rex memory save, persist, retrieve, and appear in future conversations reliably.

Status: Code complete; manual phone validation pending. Implementation notes captured in `REX_POLISH_PHASE_2_MEMORY.md`.

1. Reproduce the memory failure with a real or seeded conversation: create a memory-worthy message, confirm whether a candidate is created, approve it, and verify durable storage.
2. Trace backend memory flow: extraction, candidate creation, approval, durable write, verification, and returned response payloads.
3. Trace mobile memory flow: candidate display, approve/edit/reject actions, API calls, state refresh, saved memory grouping, and user-facing error copy.
4. Fix save logic where needed, including candidate payload validation, approval behavior, durable write handling, and failure reporting.
5. Fix retrieval logic where needed, including saved memory list loading, active/inactive filtering, unknown type handling, and prompt-context recall across conversations.
6. Add defensive validation and user-safe errors for missing payload fields, stale candidate ids, failed writes, unavailable sessions, and backend response shape changes.
7. Add or update focused tests for candidate creation, approval, durable persistence, retrieval, prompt-context recall, and mobile state refresh.
8. Run backend and Flutter verification, then document the exact manual phone smoke test for memory saving and recall.
9. After fixing memory, verify that saved memories actually appear in both text chat and voice chat.

Deliverables:

- Reliable memory save and retrieval path.
- Tests covering the fixed path.
- Manual phone checklist for memory recall across conversations.

## Phase 3: Modernize Voice Chat UI

Goal: make voice chat feel modern, premium, and consistent with Clarity instead of experimental.

Status: Implemented in mobile UI; manual phone validation pending.

1. Review the existing Clarity visual system: colors, typography, surfaces, buttons, spacing, icons, and bottom navigation behavior.
2. Design and implement a modern voice idle state.
3. Design and implement a modern active voice conversation state with clear visual feedback.
4. Improve all voice controls and state transitions using Clarity design tokens.
5. Add polished state transitions for connecting, listening, thinking, speaking, interrupted, disconnected, and failed states.
6. Improve responsive behavior for small iPhones, dynamic island/notch safe areas, keyboard avoidance where relevant, and bottom navigation spacing.
7. Replace primitive visual elements with consistent Clarity styling, restrained motion, premium surfaces, and accessible contrast.
8. Add widget or golden-adjacent tests where practical, then verify on device with at least one multi-turn voice session.

Deliverables:

- Modern voice chat screen.
- Clear active/idle/error states.
- Device-verified voice UI smoke test.

## Phase 4: Polish Main Rex Chat Interface

Goal: make text chat feel like the same premium product as the redesigned voice experience.

1. Audit the current chat screen after Phase 3 so text and voice share the same visual language.
2. Redesign message bubbles and chat layout to match the new visual direction.
3. Update the composer/input area to feel consistent with the rest of Clarity.
4. Polish memory candidate cards and all in-chat UI elements.
5. Improve empty, loading, reconnecting, failed-send, and retry states so the chat never feels blank or broken.
6. Tighten spacing and hierarchy across mobile widths, including safe areas, bottom navigation, transcript/chat overlap, and scroll-to-bottom behavior.
7. Align colors, icons, and motion with the Voice UI redesign so Rex feels like one coherent assistant experience.
8. Add focused widget tests and run a phone smoke test covering normal chat, memory candidate review, keyboard input, streaming, and navigation between Chat and Voice.

Deliverables:

- Polished Rex text chat UI.
- Consistent Chat and Voice visual system.
- Tests and phone smoke verification for core chat flows.

## Execution Order

1. Phase 1: Full Audit & Analysis
2. Phase 2: Fix Memory System
3. Phase 3: Modernize Voice Chat UI
4. Phase 4: Polish Main Rex Chat Interface

Do not start Phase 3 until Phase 2 is verified. Do not start Phase 4 until the Voice UI direction is stable, because the text chat polish should inherit the same visual language.
