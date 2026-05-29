# File 01 Phase 1 Notes - Assistant Shell Audit

Status: Phase 1 audit complete.

Scope: current Assistant shell, tab state, header layout, shared composer, per-tab responsibilities, and screenshot-visible navigation issues. This phase intentionally makes no production behavior changes.

## Current Shell Contract

Entry point:

- `HomeShell` owns bottom navigation and keeps all root pages alive in an `IndexedStack`.
- The Assistant root page is the fourth destination and renders `AssistantScreen`.
- File reference: `apps/mobile/lib/features/shell/presentation/home_shell.dart:55`.

Assistant shell:

- `AssistantScreen` is currently a `StatelessWidget`.
- It creates a local `DefaultTabController(length: 5)`.
- It renders one title, one scrollable `TabBar`, and one `TabBarView`.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:18`.

Current tab order:

1. Chat
2. Voice
3. Memory
4. Goals
5. Chats

Current tab content:

- Chat -> `ChatPage(showAppBar: false)`.
- Voice -> `ChatPage(showAppBar: false)`.
- Memory -> `MemoryPage(showAppBar: false)`.
- Goals -> `AccountabilityPage(showAppBar: false)`.
- Chats -> `ConversationListPage(showAppBar: false)`.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:61`.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:78`.

Current selected-tab behavior:

- The selected tab is owned by Flutter's local `DefaultTabController`.
- No app-level provider or parent route currently stores the selected Assistant tab.
- The `HomeShell` keeps `AssistantScreen` alive while switching bottom-nav destinations because the root pages are inside an `IndexedStack`.
- A conversation selected in Chats calls `DefaultTabController.of(context).animateTo(0)`, returning the user to Chat.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:84`.

## Header And Action Contract

Assistant root header:

- `AssistantScreen` shows only the `Assistant` title and the tab row.
- There are no global Assistant header actions at the shell level.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:26`.

Standalone Chat header:

- `ChatPage(showAppBar: true)` has separate header actions for Call Rex, Memory, Accountability, and Conversations.
- These push standalone pages rather than switching Assistant tabs.
- The embedded Assistant version disables this app bar, so these actions are hidden inside `AssistantScreen`.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart:245`.

Standalone page headers:

- `MemoryPage(showAppBar: true)` has a refresh action.
- `AccountabilityPage(showAppBar: true)` has a refresh action.
- `ConversationListPage(showAppBar: true)` has a new-conversation action.
- Embedded Assistant versions hide these app bars and use page-local body actions instead where available.
- File reference: `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart:303`.
- File reference: `apps/mobile/lib/features/assistant/accountability/presentation/pages/accountability_page.dart:34`.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/conversation_list_page.dart:233`.

## Composer And Voice Contract

Composer placement:

- `ChatPage` owns the message controller, attachment picker, Deep Think toggle, voice entry, inline voice panel, and `ChatInputBar`.
- The composer is not owned by `AssistantScreen`.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart:390`.

Voice entry:

- Starting voice from the composer calls `voiceCallProvider.notifier.startCall(conversationId: chat.conversationId)`.
- If a voice call is active, tapping voice entry scrolls to the active inline voice panel.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart:195`.

Voice tab behavior:

- The Voice tab currently renders another `ChatPage(showAppBar: false)`.
- Because Chat and Voice each instantiate `ChatPage`, they each own a separate `TextEditingController` and `ScrollController`, while sharing Riverpod chat and voice state.
- This makes Voice feel like a duplicate Chat surface rather than a dedicated voice-first screen.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:80`.

Inline voice panel:

- The active voice call panel appears inside `ChatPage` above the composer.
- It shows listening/thinking/speaking/failed state and controls for retry, settings, mute, interrupt, and end.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart:379`.

## Per-Tab Responsibility Audit

Chat:

- Owns text conversation, attachments, Deep Think toggle, memory candidate cards, clarity action cards, inline voice controls, and composer.
- It is currently the richest and most overloaded Assistant tab.

Voice:

- Should own voice-first state and controls, but currently duplicates Chat.
- This is the biggest tab ownership ambiguity.

Memory:

- Owns durable and structured memory management.
- It currently exposes technical memory layers and filters directly.
- Further polish is scoped to `02_memory_system.md`.

Goals:

- UI label says Goals, but implementation is `AccountabilityPage`.
- It currently includes signals, rules, commitments, plans, milestones, and duplicate warnings.
- Goal-specific cleanup is scoped to `03_goals_module.md`.

Chats:

- Owns conversation history inside the Assistant tab row.
- Selecting or creating a conversation switches back to Chat.
- It still has its own in-body title and new-conversation action while embedded.

## Screenshot-Visible Navigation Bugs

1. Chats used to look detached from Chat / Voice / Memory / Goals.

- Current code now places Chats inside the same `TabBar`, which addresses the architectural source of the detached header icon.
- Remaining risk: `isScrollable: true` with large tab labels can still make the row feel uneven or clipped on smaller safe-area widths.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:43`.

2. Voice tab is not a real voice tab.

- The Voice tab is currently a second `ChatPage`, so the same chat composer appears in both Chat and Voice.
- This can confuse users because voice call controls may appear as chat UI rather than a voice-owned surface.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:81`.

3. Header actions are split across embedded tabs and standalone pushed pages.

- Standalone Chat has Memory / Accountability / Conversations header actions, while embedded Assistant uses tabs.
- This creates two navigation models for the same modules.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart:249`.

4. Conversations has duplicate creation entry points.

- Embedded Chats has a top in-body new-conversation icon and a floating action button when conversations exist.
- Later phases should decide whether a tab-local header action, primary empty-state button, or FAB is the canonical create entry.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/conversation_list_page.dart:131`.
- File reference: `apps/mobile/lib/features/assistant/chat/presentation/pages/conversation_list_page.dart:247`.

5. Assistant tab selection is local and implicit.

- The current tab controller is not addressable from outside `AssistantScreen`.
- Future entry points such as composer voice, conversation resume, or bottom-nav Assistant reopen will need a small explicit tab ownership model if they should select a specific tab.
- File reference: `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart:18`.

## Existing Test Coverage

Current coverage:

- `app_routing_test.dart` verifies signed-in routing to `HomeShell`.
- It verifies sign out lives in Accounts, not a floating action.
- It verifies the Assistant destination exposes Chat, Voice, Memory, Goals, and Chats labels.
- File reference: `apps/mobile/test/app_routing_test.dart:108`.

Coverage gaps:

- No test asserts exact Assistant tab order.
- No test asserts selecting each Assistant tab updates content.
- No test asserts Chats is not rendered as a detached header action.
- No test asserts conversation selection returns to Chat.
- No test asserts Chat and Voice are intentionally separate surfaces.

## Phase Handoff

Phase 2 should define the typed tab ownership contract before any layout work:

- Stable tab ids: `chat`, `voice`, `memory`, `goals`, `chats`.
- Human labels and semantic labels.
- One owner widget per tab.
- Explicit rule that Goals does not show pending memory review.
- Explicit rule that Chats owns conversation history.

Phase 3 should then rebuild the top navigation from that contract:

- One shared nav surface for all five tabs.
- Stable spacing on iPhone SE, iPhone 13/14 class, and iPhone 16/Pro class.
- No detached header action for conversations.

Phase 4 should map every existing standalone header action to one of:

- Assistant tab.
- Tab-local action.
- Standalone page-only action.
- Removed duplicate.

Phase 4 result:

- Call Rex remains a Chat-local action in the standalone Chat app bar.
- Memory was removed from the standalone Chat app bar and is owned by the Memory tab.
- Accountability / Goals was removed from the standalone Chat app bar and is owned by the Goals tab.
- Conversations was removed from the standalone Chat app bar and is owned by the Chats tab.
- Embedded Assistant continues to expose no detached header actions.

Phase 5 should decide how much Assistant tab state is preserved outside the local `DefaultTabController`.

Phase 5 result:

- `ChatPage` uses `AutomaticKeepAliveClientMixin` so local composer, attachment, scroll, inline voice panel, and transcript UI state are not recreated during normal Assistant tab switches.
- `ConversationListPage` uses `AutomaticKeepAliveClientMixin` so the conversation list state and scroll position are not recreated during normal Assistant tab switches.
- Chat/conversation identity remains provider-owned through `chatProvider`.
- Chats still returns to Chat through `DefaultTabController.animateTo(AssistantTab.chat.index)` after selecting or creating a conversation.
- Focused widget tests cover chat draft preservation and returning from Chats to the selected conversation in Chat.

Phase 6 result:

- `AssistantScreen` now owns the tab controller directly instead of relying on a local implicit `DefaultTabController`.
- Bottom-nav entry remains stable because `HomeShell` keeps the Assistant root alive inside its `IndexedStack`; first entry defaults to Chat.
- Conversation resume from Chats calls back into the Assistant shell, then the shell switches back to Chat.
- The Voice tab starts voice with the same active-conversation rule as the Chat composer: `voiceCallProvider.notifier.startCall(conversationId: chatProvider.conversationId)`.
- Deep Think remains a Chat/Voice composer capability and is not represented as an Assistant navigation destination.
- Focused widget coverage asserts that selecting a conversation, then tapping Voice, starts Rex with that conversation id.

Phase 7 result:

- Added `assistant_navigation_test.dart` as the focused guardrail suite for the Assistant shell.
- The suite asserts all five tabs render in the stable `AssistantTab` contract order.
- The suite asserts tapping each tab updates the owned `TabController` selection.
- The suite asserts Chats is present as a tab and not as a detached `Conversations` header action.
- The suite asserts unrelated global actions such as sign out, account menu, and floating action buttons are absent from Assistant navigation.
