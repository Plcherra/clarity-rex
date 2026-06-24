# Clarity UI QA

## Automated Checks

Run from `apps/mobile`:

```bash
flutter analyze
flutter test test/assistant_navigation_test.dart
flutter test test/app_routing_test.dart
```

On Windows, Cursor agent shell commands may need to run outside the sandbox.

## Manual Screenshot QA

Check these in dark mode and light mode after the appearance toggle is enabled:

- Dashboard cash flow hero and transaction rows.
- Dashboard spending pressure and account health sections.
- Accounts list, sync controls, and connected account status.
- Budgets summary, category list, and Manage categories sheet.
- Assistant Chat empty state and active conversation.
- Assistant Knows, Goals, and Chats tabs.
- Chat input bar with and without active voice.
- Voice states: listening, thinking, speaking, muted, failure, ended.
- Profile header, account actions, Rex/voice actions, appearance action, sign
  out dialog.
- Voice usage screen.

## Acceptance Criteria

- No bright blue accent remains outside theme compatibility aliases.
- Primary accent is teal/cyan and used sparingly.
- Cards are flat or softly filled by default.
- Heavy borders and nested panels are removed where they do not carry
  information.
- All existing navigation and data flows still work.
- Text remains readable in both themes.
