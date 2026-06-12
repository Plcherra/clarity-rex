# File 07 - Chat Experience Polish

Goal: make Rex Chat feel refined, readable, and capable while preserving the existing conversation, memory, financial context, and Deep Think behavior.

Working rule: Chat polish must not break message persistence, memory extraction, financial context, or voice entry. Visual changes should be backed by widget tests when practical.

## Phase 1 - Audit Chat Surface And Message Contracts

Goal: document the current Chat page, composer, message model, memory cards, clarity action cards, and backend response shape.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/chat/domain/chat_message.dart`
- `services/rex-api/app/models/chat.py`
- Optional: `docs/clarity/rex_assistant_polish_plan/07_chat_experience_polish_notes.md`

Acceptance criteria:

- Current message states, card types, composer controls, and error states are documented.
- Known readability/layout issues are listed.
- Backend response fields used by Chat are mapped.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: mixing Chat polish with Memory or Deep Think logic.
- Mitigation: document dependencies but keep feature-specific changes in their dedicated files.

Effort: Small.

## Phase 2 - Improve Message Bubble Readability

Goal: make user and Rex messages easier to read and visually balanced.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/test/` chat bubble tests

Acceptance criteria:

- Long messages wrap cleanly without clipping.
- User and assistant bubbles have distinct but restrained styling.
- Typography matches Assistant design direction.
- Links/code-like text do not break layout.
- Tests cover long user and assistant messages.

Risks & mitigations:

- Risk: making bubbles too decorative.
- Mitigation: prioritize readable text and stable spacing over visual novelty.

Effort: Medium.

## Phase 3 - Refine Composer Controls

Goal: make the composer feel intentional with clear attachment, voice, Deep Think, and send controls.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/test/chat_input_bar_test.dart`

Acceptance criteria:

- Send button state is obvious when enabled/disabled.
- Voice button launches the same voice path as the Voice tab.
- Deep Think toggle is understandable and does not crowd the composer.
- Attachment button has clear semantics even if attachment flow is limited.
- Tests cover enabled/disabled send, Deep Think, and voice entry.

Risks & mitigations:

- Risk: composer becomes too tall or crowded.
- Mitigation: keep controls compact and move secondary options into a menu if needed.

Effort: Medium.

## Phase 4 - Stabilize Keyboard And Scroll Behavior

Goal: prevent keyboard, new messages, and streaming updates from making Chat feel jumpy.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- Widget tests where practical

Acceptance criteria:

- Composer remains visible when keyboard opens.
- New outgoing message scrolls into view.
- Streaming response does not constantly yank the list if user scrolls up.
- Manual checks cover small and large iPhone safe areas.

Risks & mitigations:

- Risk: scroll logic becomes complex.
- Mitigation: define simple rules: auto-scroll only when user is near bottom or just sent a message.

Effort: Medium.

## Phase 5 - Polish Memory And Action Cards In Chat

Goal: make memory candidates and clarity actions understandable inside conversation without overwhelming the message.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- Tests for card states

Acceptance criteria:

- Memory cards use human labels from File 02.
- Clarity action cards clearly say preview, pending, confirmed, or failed.
- Approve/reject/edit actions are visually distinct.
- Cards collapse or group when many candidates exist.

Risks & mitigations:

- Risk: duplicating full Memory review inside Chat.
- Mitigation: show quick actions in Chat and link to Memory for full review when needed.

Effort: Medium.

## Phase 6 - Improve Chat Empty And Starter States

Goal: make a new chat inviting without feeling like a landing page.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- Starter prompt data/widget if useful
- Widget tests

Acceptance criteria:

- Empty state offers practical starter prompts for finance, plans, memory, and decisions.
- Starter prompts send or populate clear user messages.
- Empty state does not duplicate global navigation.
- Tests cover tapping a starter prompt.

Risks & mitigations:

- Risk: starter prompts feel generic.
- Mitigation: use Clarity-specific prompts tied to money, goals, and coaching.

Effort: Small.

## Phase 7 - Chat Error And Retry UX

Goal: make failed messages recoverable and understandable.

Files to modify / create:

- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- Tests for failure/retry states

Acceptance criteria:

- Network/backend failure shows retry without losing user text.
- AI failure does not create duplicate user messages on retry.
- Memory extraction failure does not block the chat response.
- Error copy is concise and non-technical.

Risks & mitigations:

- Risk: retry duplicates persisted messages.
- Mitigation: define retry idempotency or local retry semantics before implementation.

Effort: Medium.

## Phase 8 - Conversation Context Indicators

Goal: make it clear which conversation the user is in without adding clutter.

Files to modify / create:

- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/conversations/` if shared metadata is needed
- Widget tests

Acceptance criteria:

- Current conversation topic/title appears when useful.
- New chat state is clear.
- Switching from Chats updates the visible topic.
- Long titles truncate gracefully.

Risks & mitigations:

- Risk: header becomes crowded with nav.
- Mitigation: use compact inline context below nav or inside Chat content.

Effort: Small.

## Phase 9 - Chat Release Gate

Goal: verify Chat polish is safe before final empty-state/design/release consolidation.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/07_chat_experience_polish.md`
- `docs/clarity/device_release_checklist.md`

Acceptance criteria:

- `flutter analyze` passes.
- Chat controller, input bar, and bubble tests pass.
- Backend chat tests pass if response contracts changed.
- Manual phone test covers new chat, existing chat, Deep Think, voice entry, keyboard, retry, and memory cards.
- Follow-up items are assigned to later files.

Risks & mitigations:

- Risk: visual polish hides behavior regressions.
- Mitigation: include persistence and retry checks in the manual test.

Effort: Small.
