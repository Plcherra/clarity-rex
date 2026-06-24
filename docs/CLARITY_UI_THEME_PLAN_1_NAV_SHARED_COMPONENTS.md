# Clarity UI Theme Plan 1: Navigation And Shared Components

## Status

| Item | State |
|------|-------|
| Foundation theme tokens | Done |
| Material component themes | Done |
| `ClarityCard` / `ClarityButton` / `ClarityDiamondLoader` | Done |
| `HomeShell` bottom navigation cleanup | Done |
| Warm/gold cleanup in shared layer | Done |

**Last updated:** 2026-06-24  
**Completed:** 2026-06-24

## Checklist

- [x] Central theme files under `apps/mobile/lib/theme/`
- [x] `ClarityTheme.dark()` AppBar, Card, Input, Button, Dialog, SnackBar, BottomSheet, ProgressIndicator themes
- [x] `navigationBarTheme` in `clarity_theme.dart`
- [x] Remove redundant `HomeShell` nav wrapper styling
- [x] Polish `ClarityCard` edge treatment
- [x] Confirm `ClarityButton` primary gradient styling
- [x] Align `ClarityDiamondLoader` glow with splash diamond
- [x] Grep shared layer for stray hardcoded colors

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

**Files changed:**

- `apps/mobile/lib/features/shell/presentation/home_shell.dart`
- `apps/mobile/lib/widgets/clarity_card.dart`
- `apps/mobile/lib/widgets/clarity_button.dart`
- `apps/mobile/lib/theme/clarity_shadows.dart`

**Visual areas changed:**

- Bottom navigation uses theme `NavigationBarTheme` with a single divider separator.
- Cards use a subtle blue-to-teal gradient edge when `highlighted` is true (default).
- Primary buttons use the blue-to-teal gradient fill.
- Shared shadow tokens use navy-tinted shadows instead of raw black.

**Verification:** run `flutter analyze` and targeted routing tests after pull.
