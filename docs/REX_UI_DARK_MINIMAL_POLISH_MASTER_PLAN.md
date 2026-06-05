# Rex UI Dark Minimal Polish Master Plan

## Executive Summary

Rex should feel calm, modern, fast, and human. The current Assistant UI still feels too heavy and inconsistent: the chat bubbles are bulky, the composer looks crowded, the Deep Think button is obsolete, voice and chat do not feel like one product, and the light theme makes the assistant feel more like an admin panel than a natural conversational space.

This plan creates a focused path to redesign Rex around a minimal dark-first experience. It keeps the scope practical: remove obsolete controls first, define a small Rex-specific visual system, then polish Chat, Voice, What Rex Knows, Goals, and history so the whole Assistant surface feels premium and coherent.

## Product Direction

- Voice remains the primary Rex interface, but chat must feel equally premium.
- Dark mode is the default visual direction for Rex.
- The UI should use empty space, restrained contrast, quiet controls, and readable typography.
- Rex should not expose backend concepts, debug labels, routing modes, or legacy memory flows.
- Controls should be obvious but subtle.
- The Assistant area should feel like one continuous experience, not five unrelated tabs.

## Non-Negotiable Design Rules

- Remove the visible Deep Think button from chat and voice UI.
- Avoid heavy cards, thick borders, oversized icons, and loud status panels.
- Use short labels and natural copy.
- Prefer one primary action per surface.
- Keep all new UI files under 500 lines.
- Extract reusable widgets instead of growing `chat_page.dart` or `voice_chat_page.dart`.
- Test on iPhone-sized layouts before calling a phase done.

## Current Problem Areas

| Area | Current Issue | Primary Files |
| --- | --- | --- |
| Assistant shell | Tab navigation is large, light, and visually noisy | `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart`, `assistant_tab.dart` |
| Chat | Bubbles and composer feel primitive; obsolete Deep Think mode still visible | `chat_page.dart`, `chat_input_bar.dart`, `chat_message_bubble.dart` |
| Voice | Better than before, but still visually separate from chat | `voice_chat_page.dart`, `voice_call_controls.dart` |
| What Rex Knows | Cleaner than old Memory tab, but still information-dense and not dark-system aligned | `memory_page.dart`, `saved_memory_tiles.dart`, memory widgets |
| Goals | Still more dashboard-like than assistant-like | accountability presentation files |
| Design system | Rex lacks a dedicated visual token layer | new shared Rex UI files needed |

## Phase 1: Remove Obsolete Brain UI

### Goal

Remove the visible Deep Think mode from the Assistant UI and simplify the chat composer.

### Files To Change

- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/features/assistant/brain/rex_deep_think_state.dart`
- `apps/mobile/lib/features/assistant/chat/data/chat_api.dart`
- Relevant chat tests

### What Done Looks Like

- No visible `Deep Think` button in chat.
- No Deep Think control state passed through UI widgets.
- Backend may still support deep routing internally, but users do not see a manual mode toggle.
- Composer becomes smaller, calmer, and focused on message + voice.

### Acceptance Criteria

- `rg "Deep Think|DeepThink|deepThink" apps/mobile/lib/features/assistant` shows no active user-facing UI labels.
- Chat send still works.
- Voice launch from chat still works.
- Existing chat tests pass.

## Phase 2: Define Rex Dark UI Tokens

### Goal

Create a small Rex-specific dark visual language without rewriting the entire app theme.

### Files To Change

- Create `apps/mobile/lib/features/assistant/presentation/rex_ui_tokens.dart`
- Create `apps/mobile/lib/features/assistant/presentation/rex_surfaces.dart`
- Update assistant presentation imports as needed

### What Done Looks Like

- Rex has shared colors, spacing, radius, text styles, and subtle surface helpers.
- Dark surfaces are consistent across chat, voice, knows, goals, and chats.
- No one-off dark colors scattered across files.

### Acceptance Criteria

- Rex UI tokens are used by at least Chat, Voice, and What Rex Knows.
- No new oversized styling helper file.
- Light app screens outside Assistant are not accidentally changed.

## Phase 3: Modernize Assistant Shell

### Goal

Make the Assistant top-level screen feel like a premium dark workspace.

### Files To Change

- `apps/mobile/lib/features/assistant/presentation/assistant_screen.dart`
- `apps/mobile/lib/features/assistant/presentation/assistant_tab.dart`

### What Done Looks Like

- Dark background throughout Assistant.
- Header is smaller and cleaner.
- Tab navigation is compact and consistent.
- Selected tab state is subtle, not a giant pale circle.
- Labels remain: `Chat`, `Voice`, `Knows`, `Goals`, `Chats`.

### Acceptance Criteria

- No tab label wraps on iPhone width.
- Navigation does not dominate the screen.
- All tabs remain reachable.
- Screenshot review shows no heavy white blocks inside Assistant.

## Phase 4: Redesign Chat Layout

### Goal

Make regular Rex chat feel modern, minimal, and conversational.

### Files To Change

- `apps/mobile/lib/features/assistant/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_message_bubble.dart`
- Create focused widgets under `apps/mobile/lib/features/assistant/chat/presentation/widgets/`

### What Done Looks Like

- Chat background is dark.
- User and Rex messages use quiet contrast.
- Rex avatar is removed or made extremely subtle.
- Message text is easy to read.
- Long messages look intentional and do not feel cramped.
- Loading state is minimal.

### Acceptance Criteria

- `chat_page.dart` stays under 500 lines.
- Message bubbles do not overflow on iPhone width.
- Empty, loading, error, and normal message states are all styled.
- Chat still supports attachments and voice entry if currently supported.

## Phase 5: Redesign The Composer

### Goal

Make the input area feel like a modern assistant composer instead of a utility form.

### Files To Change

- `apps/mobile/lib/features/assistant/chat/presentation/widgets/chat_input_bar.dart`
- Any extracted composer widgets

### What Done Looks Like

- Composer is compact and dark.
- Voice button is clear but not oversized.
- Send button state is obvious.
- Attachment button is subtle.
- No obsolete mode buttons.
- Text input supports long messages comfortably.

### Acceptance Criteria

- Composer fits above bottom nav and keyboard.
- Text does not overlap buttons.
- Send disabled/enabled states are clear.
- Voice can be started from composer.

## Phase 6: Align Voice UI With Chat

### Goal

Make voice feel like the natural extension of chat, not a separate experimental screen.

### Files To Change

- `apps/mobile/lib/features/assistant/voice/presentation/pages/voice_chat_page.dart`
- `apps/mobile/lib/features/assistant/voice/presentation/widgets/voice_call_controls.dart`

### What Done Looks Like

- Voice uses the same dark background and typography as chat.
- Status is one simple line: `Listening`, `Thinking`, or `Speaking`.
- Controls are subtle and bottom-aligned.
- Error state is calm and useful, not a large red block unless truly needed.

### Acceptance Criteria

- Voice controls do not cover transcript content.
- Voice error state has one clear retry action.
- Status transitions feel quiet.
- Speaker/audio fixes from prior phases remain intact.

## Phase 7: Redesign What Rex Knows

### Goal

Make the Knows tab feel like a clean personal profile Rex can reference, not a backend database viewer.

### Files To Change

- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/saved_memory_tiles.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/saved_memory_group_list.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_page_header_widgets.dart`

### What Done Looks Like

- Dark, clean list of saved information.
- No pending/review language.
- Facts are grouped simply: `About me`, `People`, `Preferences`, `Plans`, `Recent`.
- Edit/archive actions are tucked into a quiet menu.
- Empty state explains naturally what Rex will know after conversations.

### Acceptance Criteria

- `rg "pending|review before saving|Save this only after approval" apps/mobile/lib/features/assistant/memory` returns no active UI copy.
- Knows tab remains editable.
- Search and filters still work.
- No memory tile feels like a compliance card.

## Phase 8: Polish Goals And Accountability

### Goal

Make Goals visually match Rex instead of feeling like a separate dashboard.

### Files To Change

- `apps/mobile/lib/features/assistant/accountability/presentation/pages/accountability_page.dart`
- `accountability_page_sections.dart`
- `accountability_page_tiles.dart`
- `accountability_page_shared.dart`

### What Done Looks Like

- Dark styling aligned with Chat and Knows.
- Goal cards are simpler and easier to scan.
- Empty and error states are designed.
- No raw backend labels leak into UI.

### Acceptance Criteria

- Goals tab has no visual mismatch with Chat.
- Large cards are reduced or simplified.
- Existing accountability tests pass.

## Phase 9: Polish Chat History

### Goal

Make the Chats tab feel like a modern conversation history.

### Files To Change

- `apps/mobile/lib/features/assistant/chat/presentation/pages/conversation_list_page.dart`
- Related conversation widgets if extracted

### What Done Looks Like

- Dark list view.
- Clear recent conversation titles.
- Timestamps and previews are subtle.
- Empty state is clean.

### Acceptance Criteria

- Conversations remain selectable.
- Delete/archive behavior, if present, still works.
- No layout overflow on small screens.

## Phase 10: Visual QA And Release Readiness

### Goal

Verify the redesigned Rex UI on device before release.

### Files To Change

- Tests only if issues are found
- Update this plan with final status

### What Done Looks Like

- Chat, Voice, Knows, Goals, and Chats all share the same dark visual system.
- No Deep Think UI remains.
- No pending memory UI remains.
- The Assistant area feels modern, minimal, and consistent.

### Acceptance Criteria

- Run:
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `./scripts/mobile_release_run.sh`
- Manual device checks:
  - Open Assistant tabs.
  - Send short and long chat messages.
  - Start voice from Voice tab.
  - Start voice from Chat composer.
  - View and edit What Rex Knows.
  - Open Goals and Chats.
  - Confirm dark UI has no unreadable text or awkward white panels.

## Execution Order

1. Phase 1: Remove Obsolete Brain UI
2. Phase 2: Define Rex Dark UI Tokens
3. Phase 3: Modernize Assistant Shell
4. Phase 4: Redesign Chat Layout
5. Phase 5: Redesign The Composer
6. Phase 6: Align Voice UI With Chat
7. Phase 7: Redesign What Rex Knows
8. Phase 8: Polish Goals And Accountability
9. Phase 9: Polish Chat History
10. Phase 10: Visual QA And Release Readiness

## Current Cursor

Status: Phase 10 automated QA complete. Manual device validation and release run pending.

## Phase Ledger

- Phase 1 complete on 2026-06-04. Removed the visible Deep Think UI, deleted the mobile Deep Think state provider, stopped sending `deep_think` from mobile chat requests, and updated focused chat/API tests.
- Phase 2 complete on 2026-06-04. Added Rex dark UI tokens and reusable surfaces, then applied the Rex theme wrapper to Assistant, Chat, Voice, and What Rex Knows roots without changing app-wide theme behavior.
- Phase 3 complete on 2026-06-04. Modernized the Assistant shell with a compact dark header, quieter tab rail, smaller icons and labels, and a subtle selected state while preserving the `Chat`, `Voice`, `Knows`, `Goals`, `Chats` tab contract.
- Phase 4 complete on 2026-06-04. Extracted the chat transcript and inline voice strip from `chat_page.dart`, reduced the chat page from 624 to 297 lines, and redesigned message bubbles around the Rex dark token system with quieter surfaces, no heavy avatar/tail, and better long-message width.
- Phase 5 complete on 2026-06-04. Restyled the composer as a compact Rex dark surface, made attachment and voice controls subtle, clarified send/loading states, expanded draft capacity to seven lines, and added focused coverage to keep obsolete mode controls out.
- Phase 6 complete on 2026-06-04. Aligned Voice with the Rex dark UI system, simplified status copy to `Listening`, `Thinking`, and `Speaking`, removed duplicate failed-state actions from the main voice body, restyled bottom controls, and eliminated the Flutter Swift Package Manager warnings by removing unused `flutter_tts`, replacing `permission_handler` with `record` plus the existing native channel, and cleaning generated iOS SPM project references.
- Phase 7 complete on 2026-06-05. Redesigned What Rex Knows around the Rex dark surfaces, removed the remaining pending/review vocabulary from the memory UI, simplified saved-memory chips and group labels, fixed compact empty states, and updated focused memory tests for the new clean editable-list model.
- Phase 8 complete on 2026-06-05. Restyled Goals and accountability around the Rex dark scaffold, replaced divider-heavy Material list rows with compact Rex surfaces, softened section labels and empty/error states, and kept all accountability presentation files under 500 lines.
- Phase 9 complete on 2026-06-05. Restyled Chats as a dark Rex conversation history, extracted the conversation row/date helpers from the page, removed default Material list rows and floating action button treatment, updated stale navigation assertions, and kept the new files under 500 lines.
- Phase 10 automated QA complete on 2026-06-05. Ran analyzer, focused Assistant tests, the full mobile test suite, and stale UI terminology scans; replaced the last generic Assistant surface-token usages, softened inline voice failure copy to `Voice paused`, and left manual device checks plus `./scripts/mobile_release_run.sh` for the final release pass.
