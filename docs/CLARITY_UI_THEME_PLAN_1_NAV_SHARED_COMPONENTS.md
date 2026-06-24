# Clarity UI Theme Plan 1: Quick Visual Fixes

## Status

| Item | State |
|------|-------|
| Move `Import CSV instead` to account action icon | Complete |
| Restyle `+ Add custom category` as quiet outline/ghost action | Complete |
| Audit obvious too-blue CTA buttons | Complete |
| Keep dashboard/accounts layout mostly unchanged | Complete |

**Last updated:** 2026-06-24  
**Source:** `cursor_chat_app_logo_and_splash_screen.json`

## Goal

Apply the small, high-impact frontend fixes requested in the chat without changing architecture, finance behavior, Plaid/Supabase behavior, routing, or the overall dashboard/accounts layout.

The dashboard and bank accounts layout were considered acceptable. This plan is only for the urgent visual cleanup items.

## Checklist

- [x] Move `Import CSV instead` away from large/prominent blue button treatment.
- [x] Add an import/upload icon action near existing delete/sync actions where account-level actions are shown.
- [x] Keep CSV import behavior, duplicate warnings, account selection, and transaction import semantics unchanged.
- [x] Restyle `+ Add custom category` as a modern minimal outline/ghost action.
- [x] Replace mismatched blue action styling with theme-consistent teal/dark variants.
- [x] Audit obvious too-blue CTAs introduced by the affected flows.
- [x] Keep dashboard/accounts layout mostly as-is.

## Target Areas

Likely files to inspect and update:

- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_shell.dart`
- `apps/mobile/lib/features/accounts/presentation/account_selection_screen.dart`
- `apps/mobile/lib/features/accounts/presentation/widgets/connect_bank_setup_card.dart`
- `apps/mobile/lib/features/accounts/presentation/widgets/plaid_account_header.dart`
- `apps/mobile/lib/features/accounts/presentation/account_detail_screen.dart`
- `apps/mobile/lib/features/transactions/presentation/upload_screen.dart`
- `apps/mobile/lib/features/budgets/presentation/category_management_sheet_sections.dart`

## Requested Changes

### Import CSV Instead

The current text-button treatment makes the fallback import action too visually prominent. Move it toward an icon action pattern:

- Account detail / account-level surfaces should expose CSV import as an icon action next to delete/sync/upload actions where that pattern already exists.
- Empty/setup surfaces may still mention CSV as a fallback, but should avoid a large bright CTA if it competes with primary bank connection.
- Keep labels available through tooltips, semantics, or supporting text where needed for accessibility.

### Add Custom Category

The current `+ Add custom category` button should feel quieter and more premium:

- Prefer an outlined/ghost action over a filled blue button.
- Use the centralized dark navy / teal theme.
- Keep it easy to find, but visually subordinate to the category list and save flows.

### Too-Blue CTA Audit

Review the affected flows for bright blue actions that do not match the current Clarity theme. Convert only obvious mismatches; do not redesign unrelated screens in this pass.

## Constraints

- Do not change account, transaction, budget, Plaid, Supabase, or CSV import logic.
- Do not change dashboard/accounts information architecture.
- Do not add new product flows.
- Do not change tab order or navigation.
- Keep financial UI changes under `apps/mobile/lib/features`.
- Keep colors centralized through theme tokens or existing shared components.

## Expected Visual Outcome

- Dashboard/accounts still feel familiar.
- CSV fallback is available but less visually loud.
- Category management action feels modern, minimal, and theme-aligned.
- Obvious mismatched blue buttons are reduced.

## Verification

Run from `apps/mobile`:

```bash
flutter analyze
flutter test test/app_routing_test.dart
```

Manual checks:

- Dashboard empty state.
- Account detail actions.
- Manual/CSV import fallback path.
- Connected-account CSV duplicate warning path.
- Budget category management sheet.

## Completion Report

Implemented:

- Moved per-account CSV import into the dashboard app-bar action cluster with an upload icon, tooltip, and busy state.
- Removed the prominent per-account body CTA for CSV import.
- Changed empty/setup CSV fallback and standalone upload-screen CSV action to quieter text/outline treatments.
- Restyled `+ Add custom category` as a compact outline/ghost action.

Verification:

- IDE lints reported no errors for edited files.
- `flutter analyze` and `flutter test test/app_routing_test.dart` could not be verified because the terminal runner did not return an exit status, including for a simple shell sanity command.
