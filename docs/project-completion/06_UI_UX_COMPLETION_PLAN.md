# UI And UX Completion Plan

## Goal

Make Clarity feel calm, complete, coherent, and trustworthy across light, dark, and system themes.

## Status

**MVP code/static complete.** Rex assistant surfaces now read active Clarity theme tokens instead of hard-coded dark-only Rex color constants. Dedicated manual light/dark/system QA is deferred until the project-wide test pass.

## Current State

- The app has a five-tab shell: Dashboard, Accounts, Budgets, Assistant, Profile.
- Assistant has four inner tabs: Chat, Knows, Goals, Chats.
- Shared theme tokens exist and were recently tuned.
- Rex assistant UI (Chat, Knows, Goals, Chats, voice panel) uses `context.clarityColors` for user-facing colors.
- Some financial feature screens remain large and need splitting (deferred).
- Full-app manual theme QA deferred per current testing plan.

## Work Plan

### 1. Visual System Final Pass

- Confirm light theme:
  - Strong enough green/red semantic colors.
  - Clean grey surfaces.
  - No brown/dirty tones in search boxes or cards.
- Confirm dark theme:
  - Absolute black background.
  - Neutral grey surfaces.
  - No brown tones.
  - Strong enough accent and danger colors.
- Confirm system theme:
  - Follows OS mode.
  - Label makes sense to users.
- Done (code):
  - Chat bubbles, attachment sheet, input bar hint, transcript error banner, voice muted chip, Knows group headers, and Goals tiles/error/empty states follow light/dark theme tokens.

### 2. Border And Surface Cleanup

- Remove decorative borders where shape, spacing, and fill already communicate grouping.
- Keep borders only for:
  - Focus states.
  - Destructive states.
  - Selected states where fill alone is not enough.
  - Accessibility/contrast needs.
- Done (code):
  - Chat message bubbles use fill and shape without ordinary decorative borders.

### 3. Navigation Polish

- Verify all tabs preserve expected state.
- Verify back navigation on pushed screens.
- Ensure Assistant tab switching is intuitive.
- Confirm conversation selection moves back to Chat.
- Add or remove route entries for orphan screens.
- Done (static):
  - Widget tests cover assistant tab order, tab switching, Chats search, draft preservation, and conversation return flow.

### 4. Empty, Loading, Error, Degraded States

Every major screen needs:

- Loading state.
- Empty state.
- Error state.
- Retry path.
- Degraded backend/source messaging where relevant.

Priority screens:

| Screen | Status (code) |
|--------|---------------|
| Dashboard empty | Existing (not re-audited this pass) |
| Accounts empty/degraded Plaid | Existing (not re-audited this pass) |
| Budgets empty | Existing basic message |
| Chat backend unavailable | Error banner in transcript |
| Knows no memory | Empty + filtered empty + error banner |
| Goals no goals | Empty + section empties + error banner + loading |
| Voice unavailable | Failed panel with Try again + Settings |
| Profile usage unavailable | Error + Retry on usage screen |

### 5. Accessibility And Mobile Fit

- Confirm text sizes on small iPhone screens.
- Confirm touch targets are large enough.
- Confirm search fields and chips are readable in both themes.
- Confirm screen readers get useful labels on primary actions.
- Avoid clipped content behind the bottom navigation bar.
- Done (static):
  - Assistant navigation tests cover 320/390/430 widths and semantic tab labels.

### 6. File Splits

Split large presentation files after product wiring stabilizes:

- `transaction_category_dropdown.dart`
- `conversation_list_page.dart`
- `transaction_review_screen.dart`
- `account_selection_screen.dart`
- `month_detail_screen.dart`
- `profile_screen.dart`
- `mfa_enrollment_screen.dart`

Use one screen file plus focused widget files. Avoid creating vague `utils` files.

**Deferred** until post-MVP polish.

## Acceptance Criteria

- Every visible screen looks consistent in light and dark.
- No user-facing screen has unreadable faded colors.
- Main flows work on small mobile screens.
- No major feature appears unfinished unless intentionally labeled.
- No hidden/unreachable UI remains.

## Suggested Tests

- Flutter analyze.
- Widget tests for main tabs.
- Golden/screenshot checks if available later.
- Manual light/dark/system theme QA.

## Verification Log

- `flutter analyze` on Rex UI files touched this pass — no issues found.
- `flutter test test/chat_message_bubble_test.dart test/attachment_source_sheet_test.dart test/chat_input_bar_test.dart test/assistant_navigation_test.dart test/app_routing_test.dart test/memory_page_test.dart test/inline_voice_call_panel_test.dart`
  - 30 tests passed.

## Deferred

- Manual light/dark/system walkthrough of every bottom tab.
- Golden/screenshot theme regression suite.
- Financial feature screen file splits.
- Full Dashboard/Accounts/Budgets empty-degraded re-audit.
- Sync `docs/ui/CLARITY_UI_TOKENS.md` with current `clarity_colors.dart` palette values.

## Manual Smoke

1. Walk every bottom tab in light mode.
2. Walk every bottom tab in dark mode.
3. Switch to system mode.
4. Check every search field.
5. Check all chips and selected states.
6. Trigger empty states.
7. Trigger common errors with backend off.
8. Confirm Profile theme labels update correctly.
