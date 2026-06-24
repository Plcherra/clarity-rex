# Clarity UI Theme Plan 2: Assistant And Profile UI Refresh

## Status

| Area | State |
|------|-------|
| Assistant landing / tab shell | Complete |
| Assistant prompt chips / empty states | Complete |
| Conversation list cards | Complete |
| Profile hierarchy and action rows | Complete |
| Shared Assistant/Profile surface language | Complete |

**Last updated:** 2026-06-24  
**Source:** `cursor_chat_app_logo_and_splash_screen.json`

## Goal

Upgrade the Assistant and Profile screens that were called out as primitive, while keeping Rex Brain, memory, goals, voice, auth, and profile data behavior unchanged.

This is a visual and presentation refresh only.

## Checklist

- [x] Redesign the Assistant landing/tab shell so it feels intentional and premium.
- [x] Refresh prompt chips, tabs, chat list cards, and empty states.
- [x] Keep Assistant navigation and tab destinations unchanged.
- [x] Make Profile cards feel more premium with clearer hierarchy and spacing.
- [x] Improve Profile action rows so they feel less like default Material list tiles.
- [x] Unify Assistant/Profile surfaces with Clarity card language without making them visually heavy.
- [x] Tighten typography and reduce visual noise.

## Target Areas

Likely files to inspect and update:

- `apps/mobile/lib/rex/presentation/assistant_screen.dart`
- `apps/mobile/lib/rex/presentation/rex_surfaces.dart`
- `apps/mobile/lib/rex/presentation/rex_ui_tokens.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/conversation_list_page.dart`
- `apps/mobile/lib/rex/chat/presentation/pages/chat_page.dart`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_input_bar.dart`
- `apps/mobile/lib/rex/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/rex/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/features/profile/presentation/profile_screen.dart`
- `apps/mobile/lib/features/profile/presentation/usage_summary_screen.dart`

## Requested Changes

### Assistant

Refresh the Assistant area as a presentation surface:

- Improve the landing/shell layout, especially the first impression when opening the Assistant tab.
- Make tabs feel integrated with the current dark Clarity theme.
- Give prompt chips and empty states a more modern hierarchy.
- Improve conversation list cards and loading/empty states so they feel less generic.
- Preserve the current Assistant tab destinations: chat, memory, goals, and history.

### Profile

Profile should feel more premium without changing account behavior:

- Use softer surfaces and clearer grouping.
- Improve spacing and hierarchy in the profile header.
- Make action rows feel custom and calm rather than default list tiles.
- Keep MFA, voice usage, sign out, and profile-name flows unchanged.

### Shared Visual Direction

- Reuse existing Clarity/Rex tokens where they fit.
- Avoid heavy glassmorphism or excessive glow.
- Keep the screens dark, calm, precise, and readable.
- Use small, local widget extractions only when they reduce repetition.

## Constraints

- Do not change Rex Brain prompts, recall, memory, goals, or backend behavior.
- Do not change saved memory, chat history, accountability, or voice data contracts.
- Do not change profile persistence or auth behavior.
- Keep Rex UI changes under `apps/mobile/lib/rex`.
- Keep Profile UI changes under `apps/mobile/lib/features/profile`.
- Do not change navigation structure or tab order.
- Do not add new product flows.

## Expected Visual Outcome

- Assistant no longer feels like a primitive/default tab screen.
- Chat/history empty states and cards feel modern and aligned with Clarity.
- Profile feels more premium, calmer, and easier to scan.
- Typography and spacing feel intentional across both areas.

## Verification

Run from `apps/mobile`:

```bash
flutter analyze
flutter test test/assistant_navigation_test.dart
```

Manual checks:

- Open Assistant tab and switch between all Assistant sections.
- Open chat list with empty and populated states.
- Start a new chat and verify input bar behavior still works.
- Open Profile, edit profile name, open MFA, open voice usage, and sign out dialog.

## Completion Report

Implemented:

- Refreshed the Assistant top surface with a premium compact header and integrated tab bar while preserving tab order and destinations.
- Upgraded chat empty state, prompt chips, conversation history header, search/filters, empty states, and conversation cards.
- Softened Memory and Goals tab surfaces for consistency with Rex card language.
- Reworked Profile into clearer header, grouped custom action rows, and calmer voice usage cards.

Verification:

- `dart format` completed for edited Dart files.
- IDE lints reported no errors for edited files.
- `flutter analyze` passed from the IDE terminal before the final compact-layout fixes.
- `flutter test test/assistant_navigation_test.dart` passed from the IDE terminal after the compact-layout fixes.
