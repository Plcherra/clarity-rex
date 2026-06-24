# Archived UI Plan: Phase 1 Finance Quick Fixes

Superseded by `docs/ui/CLARITY_UI_VISION.md`,
`docs/ui/CLARITY_UI_TOKENS.md`, and `docs/ui/CLARITY_UI_PHASES.md`.

## Original Status

Completed on 2026-06-24.

## Original Goal

Apply small, high-impact frontend fixes without changing architecture, finance
behavior, Plaid/Supabase behavior, routing, or the overall dashboard/accounts
layout.

## Completed Scope

- Moved `Import CSV instead` away from prominent blue button treatment.
- Added an import/upload icon action near existing account-level actions.
- Kept CSV import behavior, duplicate warnings, account selection, and
  transaction import semantics unchanged.
- Restyled `+ Add custom category` as a modern minimal outline/ghost action.
- Replaced obvious mismatched blue action styling with theme-consistent
  teal/dark variants.
- Kept dashboard/accounts layout mostly unchanged.

## Historical Verification

- IDE lints reported no errors for edited files.
- `dart analyze` reported no issues after dependency upgrade.
- `flutter test test/app_routing_test.dart test/assistant_navigation_test.dart`
  passed from `apps/mobile` with 16 passing tests.
