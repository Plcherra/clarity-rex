# File 01 - Navigation & Overall Structure

Goal: make the Assistant shell feel intentional, unified, and premium before deeper Memory, Goals, Voice, Chat, and Chats refactors begin.

Working rule: implement one phase at a time. Each phase must preserve current behavior unless the acceptance criteria explicitly call for a visible UX change.

## Phase 1 - Audit Current Assistant Shell Contract

Goal: document the current Assistant shell, tab state, header layout, shared composer, and per-tab responsibilities so refactors start from facts.

Status: Complete. Audit notes are captured in `01_navigation_structure_notes.md`.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- `apps/mobile/test/app_routing_test.dart`
- Optional: `docs/clarity/rex_assistant_polish_plan/01_navigation_structure_notes.md`

Acceptance criteria:

- Current tab list, selected-tab behavior, header actions, and composer placement are documented.
- Navigation bugs visible in screenshots are listed with file references.
- No production behavior changes unless limited to harmless comments/docs.

Risks & mitigations:

- Risk: accidentally starting implementation during audit.
- Mitigation: keep this phase read-only unless adding notes or tests that describe current behavior.

Effort: Small.

## Phase 2 - Define Assistant Tab Ownership

Goal: create a clear ownership contract for Chat, Voice, Memory, Goals, and Chats so each tab has one job.

Status: Complete. `AssistantTab` now defines stable tab ids, labels, icons, semantic labels, keys, and order.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/presentation/assistant_tab.dart` if a new typed tab model is useful
- `apps/mobile/test/app_routing_test.dart`

Acceptance criteria:

- Each tab has a stable id, label, icon, semantic label, and target content.
- Goals does not own pending memory review.
- Chats owns conversation history, not a detached floating action.
- Tests assert all five tabs are present and ordered correctly.

Risks & mitigations:

- Risk: tab model over-engineering.
- Mitigation: add a tiny typed model only if it removes duplication in the existing shell.

Effort: Small.

## Phase 3 - Rebuild Top Navigation Layout

Goal: make the top Assistant navigation visually aligned so the Chats icon sits with Chat, Voice, Memory, and Goals instead of looking detached.

Status: Complete. Assistant tabs now render through one fixed-width shared navigation component instead of a scrollable row.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- Shared Assistant nav widget file if extraction is warranted
- `apps/mobile/test/app_routing_test.dart`

Acceptance criteria:

- Chat, Voice, Memory, Goals, and Chats use one shared nav row/grid.
- Selected state, icon size, label position, tap target, and spacing are consistent.
- No tab icon overlaps the dynamic island, page title, or content on common iPhone sizes.
- Manual/screenshot checks cover iPhone SE, iPhone 13/14 class, and iPhone 16/Pro class safe areas.
- Widget tests cover tab switching and the presence of the Chats tab in the shared nav.

Risks & mitigations:

- Risk: layout regressions on small screens.
- Mitigation: use responsive constraints, stable tap targets, and run screenshot/manual checks on the test phone.

Effort: Medium.

## Phase 4 - Normalize Assistant Header Actions

Goal: separate global Assistant actions from tab navigation so actions feel deliberate and never collide with tab icons.

Status: Complete. Chat's standalone app bar now keeps only the tab-local Call Rex action; Memory, Goals/Accountability, and Conversations are owned by Assistant tabs.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- Chat/voice/conversation action widgets if currently embedded in page bodies
- `apps/mobile/test/app_routing_test.dart`

Acceptance criteria:

- Header actions are tab-aware and limited to actions that belong to the active tab.
- Conversation/history entry is a tab, not a stray header icon.
- Refresh/retry/end-call controls appear only in the relevant state.
- Accessibility labels explain action intent.

Risks & mitigations:

- Risk: hiding an action users still need.
- Mitigation: map every existing action to either a tab, a tab-local button, or an overflow/menu before removal.

Effort: Medium.

## Phase 5 - Stabilize Tab State And Conversation Continuity

Goal: ensure switching between Assistant tabs does not lose the current chat, transcript, call state, or selected conversation unexpectedly.

Status: Complete. Chat and Chats are kept alive across tab switches, draft text survives tab changes, and selecting a conversation from Chats returns to Chat with the selected history loaded.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- Relevant widget/controller tests

Acceptance criteria:

- Current chat remains selected after visiting Memory, Goals, or Chats.
- Voice call state is preserved or intentionally ended with clear UI copy.
- Background app suspension during a voice call has a defined restore, reconnect, or end-call behavior.
- Returning from Chats resumes the selected conversation in Chat.
- Tests cover tab switch state preservation for Chat and Chats.

Risks & mitigations:

- Risk: stale providers keeping too much state alive.
- Mitigation: define which providers are app-scoped, tab-scoped, or disposable before editing.

Effort: Medium.

## Phase 6 - Unify Assistant Entry Points

Goal: make every way of entering Rex predictable: bottom nav, chat composer phone icon, voice tab, conversation resume, and Deep Think.

Status: Complete. `AssistantScreen` now owns the Assistant tab controller, defaults to Chat, conversation resume returns through the shell owner, and the Voice tab starts voice through the same `voiceCallProvider.startCall(conversationId: chat.conversationId)` rule used by the composer.

Files to modify / create:

- `apps/mobile/lib/features/shell/presentation/home_shell.dart`
- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`

Acceptance criteria:

- Bottom nav opens Assistant to the last meaningful Assistant tab or a defined default.
- Composer voice entry and Voice tab share the same voice-start rules.
- Conversation resume opens Chat with the correct conversation.
- Deep Think stays a chat/voice capability, not a separate nav destination.

Risks & mitigations:

- Risk: confusing users with remembered tab state.
- Mitigation: default to Chat unless there is an active voice call or explicit resume action.

Effort: Medium.

## Phase 7 - Create Assistant Navigation Component Tests

Goal: protect the shell from future regressions with focused tests around tab ordering, labels, selected state, and action visibility.

Status: Complete. Focused Assistant navigation tests now cover tab order, selected-index changes, Chats as a tab instead of a detached header action, and exclusion of unrelated global actions.

Files to modify / create:

- `apps/mobile/test/assistant_navigation_test.dart`
- `apps/mobile/test/app_routing_test.dart`
- Test fakes/helpers as needed

Acceptance criteria:

- Tests assert the five-tab nav order.
- Tests assert Chats is not rendered as a detached header action.
- Tests assert selected state changes when each tab is tapped.
- Tests assert no sign-out or unrelated global action appears inside Assistant nav.

Risks & mitigations:

- Risk: brittle widget tests based on text duplication.
- Mitigation: prefer semantic labels, keys, or stable widget ids where appropriate.

Effort: Small.

## Phase 8 - Polish Safe Areas And Responsive Spacing

Goal: make the Assistant shell robust across iPhone safe areas, keyboard states, dynamic island, and bottom navigation.

Status: Complete. Assistant shell spacing now adapts on compact widths, tab labels use a stable fitted tab item, and navigation tests cover iPhone SE, iPhone 13/14 class, and iPhone 16/Pro class viewport sizes.

Files to modify / create:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- Shared layout constants if already present
- Focused widget tests where practical

Acceptance criteria:

- Header, tab nav, content, composer, and bottom nav do not overlap.
- Keyboard does not hide the composer or active controls.
- Voice error/retry surface does not collide with composer.
- Manual phone check covers at least Chat, Voice, Goals, and Chats on iPhone SE, iPhone 13/14 class, and iPhone 16/Pro class safe areas.

Risks & mitigations:

- Risk: test environment cannot reproduce all iOS safe-area states.
- Mitigation: combine widget constraints with real-device manual checklist.

Effort: Medium.

## Phase 9 - Navigation Phase Release Gate

Goal: verify the Assistant shell is ready before moving to Memory and Goals polish.

Status: Complete for automated verification. `flutter analyze`, Assistant navigation tests, app routing tests, and whitespace checks pass. Real-device smoke coverage has been added to the device release checklist and remains the manual gate before treating the phone build as fully released.

Files to modify / create:

- `docs/clarity/rex_assistant_polish_plan/01_navigation_structure.md`
- `docs/clarity/device_release_checklist.md` if manual checks need updating

Acceptance criteria:

- `flutter analyze` passes.
- Assistant navigation tests pass.
- Relevant app routing tests pass.
- Manual phone smoke test confirms tab alignment, conversation entry, voice entry, keyboard behavior, and no detached Chats icon.
- Known follow-up items are moved to later plan files instead of left as vague TODOs.

Risks & mitigations:

- Risk: shipping visual cleanup without real-device confirmation.
- Mitigation: do not close Phase 9 until a phone run has been completed or explicitly deferred with reason.

Effort: Small.
