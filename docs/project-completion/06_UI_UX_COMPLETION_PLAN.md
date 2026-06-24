# UI And UX Completion Plan

## Goal

Make Clarity feel calm, complete, coherent, and trustworthy across light, dark, and system themes.

## Current State

- The app has a five-tab shell: Dashboard, Accounts, Budgets, Assistant, Profile.
- Assistant has four inner tabs: Chat, Knows, Goals, Chats.
- Shared theme tokens exist and were recently tuned.
- Some screens remain large and need splitting.
- Some visual states and empty/error flows need final polish.

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

### 2. Border And Surface Cleanup

- Remove decorative borders where shape, spacing, and fill already communicate grouping.
- Keep borders only for:
  - Focus states.
  - Destructive states.
  - Selected states where fill alone is not enough.
  - Accessibility/contrast needs.

### 3. Navigation Polish

- Verify all tabs preserve expected state.
- Verify back navigation on pushed screens.
- Ensure Assistant tab switching is intuitive.
- Confirm conversation selection moves back to Chat.
- Add or remove route entries for orphan screens.

### 4. Empty, Loading, Error, Degraded States

Every major screen needs:

- Loading state.
- Empty state.
- Error state.
- Retry path.
- Degraded backend/source messaging where relevant.

Priority screens:

- Dashboard empty.
- Accounts empty/degraded Plaid.
- Budgets empty.
- Chat backend unavailable.
- Knows no memory.
- Goals no goals.
- Voice unavailable.
- Profile usage unavailable.

### 5. Accessibility And Mobile Fit

- Confirm text sizes on small iPhone screens.
- Confirm touch targets are large enough.
- Confirm search fields and chips are readable in both themes.
- Confirm screen readers get useful labels on primary actions.
- Avoid clipped content behind the bottom navigation bar.

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

## Manual Smoke

1. Walk every bottom tab in light mode.
2. Walk every bottom tab in dark mode.
3. Switch to system mode.
4. Check every search field.
5. Check all chips and selected states.
6. Trigger empty states.
7. Trigger common errors with backend off.
8. Confirm Profile theme labels update correctly.
