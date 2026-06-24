# Clarity UI Theme Plan 1: Navigation And Shared Components

## Goal

Make the shared app shell and reusable UI foundation match the Clarity dark navy blue-to-teal theme without redesigning the main screens yet.

## Scope

- Restyle `HomeShell` bottom navigation using centralized Clarity theme tokens.
- Tighten shared Material themes where needed:
  - `AppBarTheme`
  - `CardTheme`
  - `InputDecorationTheme`
  - `FilledButtonTheme`
  - `OutlinedButtonTheme`
  - `TextButtonTheme`
  - `DialogTheme`
  - `SnackBarTheme`
  - `BottomSheetTheme`
  - `ProgressIndicatorTheme`
- Add or refine shared components:
  - `ClarityCard`
  - `ClarityButton`
  - `ClarityDiamondLoader`
- Replace obvious warm/gold hardcoded styling with centralized Clarity blue-to-teal tokens.
- Keep all colors centralized in `apps/mobile/lib/theme/`.

## Constraints

- Do not redesign Dashboard, Accounts, Budgets, Assistant, Profile, Auth, or Onboarding in this pass.
- Do not change the bottom navigation structure or tab order.
- Do not change auth logic.
- Do not change Supabase initialization.
- Do not change Plaid, finance, or Rex backend behavior.
- Do not introduce random hardcoded colors in screens.

## Expected Visual Changes

- Bottom navigation should feel dark navy, softly separated, and premium.
- Active navigation state should use restrained blue-to-teal emphasis.
- Shared buttons, inputs, cards, dialogs, snackbars, bottom sheets, and loaders should feel aligned with the splash style.
- The app should move away from the previous warm black/gold look.

## Verification

Run from `apps/mobile`:

```bash
flutter analyze
flutter test test/app_routing_test.dart test/assistant_navigation_test.dart
```

## Completion Report

After implementation, report:

- Files changed.
- Exact visual areas changed.
- Whether `flutter analyze` passed.
- Whether targeted tests passed.
