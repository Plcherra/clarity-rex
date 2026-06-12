# File 04 - Conversations / History Tab

Goal: make Chats feel like a polished conversation history surface where users can find, resume, archive, and understand prior Rex conversations without confusion.

Working rule: history polish must preserve existing conversations and message data. Archive/delete behavior must be explicit, reversible where possible, and never triggered by accidental navigation.

## Phase 1 - Audit Conversation History Contracts

Goal: document current conversation list data, resume behavior, message previews, timestamps, and any archive/delete routes.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/chat/data/chat_api.dart`
- `services/rex-api/app/routes/conversations.py`
- `services/rex-api/app/services/chat_service.py`
- Optional: `docs/clarity/rex_assistant_polish_plan/04_conversations_history_notes.md`

Acceptance criteria:

- Current history fields, sorting, empty state, and resume behavior are documented.
- Missing fields needed for a premium list are identified.
- Archive/delete capabilities are classified as existing, missing, or unsafe.
- No production behavior changes unless limited to docs or read-only notes.

Risks & mitigations:

- Risk: treating conversation history as disposable.
- Mitigation: assume all conversation records are user data and require explicit confirmation for destructive actions.

Effort: Small.

## Phase 2 - Define Conversation List UX Contract

Goal: establish what each conversation row should communicate at a glance.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/presentation/`
- `apps/mobile/lib/rex/conversations/data/`
- `apps/mobile/test/` conversation history tests

Acceptance criteria:

- Each row has a title/topic, last message preview, last updated time, and optional state marker.
- Empty title fallback is human-readable, not an id or backend placeholder.
- Voice-originated and chat-originated conversations can share the same list treatment.
- Tests cover title fallback and row rendering.

Risks & mitigations:

- Risk: generating misleading titles.
- Mitigation: use existing conversation metadata first; fallback to first useful user message.

Effort: Small.

## Phase 3 - Improve Search And Filtering

Goal: let users find prior conversations quickly without turning history into a heavy admin table.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/presentation/`
- `apps/mobile/lib/rex/conversations/data/`
- Backend search route only if local search cannot support current data size
- Widget tests

Acceptance criteria:

- Search filters title/topic and recent preview text.
- Empty search state says no matching chats, not no chats exist.
- Search input does not overlap safe areas or bottom navigation.
- Search state clears predictably when leaving the history tab or tapping clear.

Risks & mitigations:

- Risk: local search misses older server-side conversations.
- Mitigation: document when server-side search is needed and keep first implementation honest.

Effort: Medium.

## Phase 4 - Add Archive Flow Copy And Guardrails

Goal: support conversation cleanup with clear archive semantics and safe confirmation.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/presentation/`
- `apps/mobile/lib/rex/chat/data/chat_api.dart`
- `services/rex-api/app/routes/conversations.py`
- Backend/mobile tests if archive route exists or is added

Acceptance criteria:

- Archive action is available from row overflow or detail, not accidental swipe by default.
- Confirmation copy explains that archived chats leave the main list.
- Archived conversations can be viewed or restored if backend support exists.
- If restore does not exist, copy avoids promising reversibility.

Risks & mitigations:

- Risk: accidental loss of important conversations.
- Mitigation: require confirmation and avoid hard delete in this phase.

Effort: Medium.

## Phase 5 - Make Resume Behavior Predictable

Goal: ensure tapping a conversation always opens Chat with the selected conversation and preserves the expected context.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/conversations/presentation/`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/test/assistant_navigation_test.dart`

Acceptance criteria:

- Tapping a conversation switches to Chat and loads that conversation.
- Current conversation indicator updates correctly.
- Returning to Chats preserves history scroll position when practical.
- Tests cover selecting a conversation and landing in Chat.

Risks & mitigations:

- Risk: clearing current draft text unexpectedly.
- Mitigation: define whether drafts are preserved, cleared, or prompted before switching.

Effort: Medium.

## Phase 6 - Conversation Metadata And Time Copy

Goal: make timestamps and metadata feel polished and understandable.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/data/`
- `apps/mobile/lib/rex/conversations/presentation/`
- Shared time formatting helper if one exists
- Tests for formatting

Acceptance criteria:

- Recent conversations use friendly relative time.
- Older conversations use concise dates.
- Missing timestamps fall back gracefully.
- Metadata such as message count or voice call marker is optional and never noisy.

Risks & mitigations:

- Risk: inconsistent date formatting across the app.
- Mitigation: reuse existing date/time helpers or create a small Assistant-local helper for later consolidation.

Effort: Small.

## Phase 7 - History Empty, Loading, And Error States

Goal: make Chats resilient when history is empty, loading, offline, or degraded.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/presentation/`
- `apps/mobile/lib/rex/conversations/data/`
- Widget tests

Acceptance criteria:

- Empty state invites starting a new Rex conversation.
- Loading state is calm and does not jump layout.
- Error state offers retry and does not imply data was lost.
- Partial loaded state can still show cached/local items if available.

Risks & mitigations:

- Risk: duplicating shared state components before File 08.
- Mitigation: keep local implementation simple and mark consolidation for File 08.

Effort: Medium.

## Phase 8 - Conversation Row Interaction Polish

Goal: make row taps, long press, overflow menus, and accessibility feel deliberate.

Files to modify / create:

- `apps/mobile/lib/rex/conversations/presentation/`
- `apps/mobile/test/` interaction tests

Acceptance criteria:

- Primary tap resumes the chat.
- Overflow exposes secondary actions.
- Long press, if used, mirrors overflow actions and is not required.
- Rows have semantic labels for screen readers.
- Tap targets meet mobile size expectations.

Risks & mitigations:

- Risk: too many row actions clutter the list.
- Mitigation: keep one primary action and move secondary actions into overflow.

Effort: Small.

## Phase 9 - Conversations Release Gate

Goal: verify history polish is safe before Deep Think, Voice, and Chat polish continue.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/04_conversations_history.md`
- `docs/clarity/device_release_checklist.md` if manual conversation checks need updating

Acceptance criteria:

- `flutter analyze` passes.
- Conversation/history widget tests pass.
- Backend conversation route tests pass if routes changed.
- Manual phone check confirms search, resume, archive copy, empty state, and no detached history icon.
- Follow-up items are assigned to later files rather than left as vague TODOs.

Risks & mitigations:

- Risk: approving history without real conversation data.
- Mitigation: test with empty history, one chat, several chats, and a voice-originated conversation.

Effort: Small.
