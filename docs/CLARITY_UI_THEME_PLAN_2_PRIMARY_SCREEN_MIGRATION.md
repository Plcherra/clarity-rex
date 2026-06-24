# Clarity UI Theme Plan 2: Primary Screen Migration

## Goal

Migrate the main app screens to the Clarity dark AI/finance aesthetic using the shared theme and components from Plan 1.

## Scope

- Migrate primary screens in this order:
  1. Auth and Onboarding.
  2. Dashboard and Accounts.
  3. Budgets and Profile.
  4. Assistant/Rex.
  5. Shared loading, empty, setup, and error states in those flows.
- Update loading states, empty states, setup states, and error states where they appear in the main flows.
- Replace generic Material-looking screen-level styling with shared Clarity components and centralized theme tokens.
- Use `ClarityCard`, `ClarityButton`, `ClarityDiamondLoader`, and theme constants where they reduce duplication and improve consistency. Do not wrap every widget just to use the new components.
- Review finance positive/negative colors as a visual-only pass so they remain readable and serious without feeling bright green/mint or playful.

## Constraints

- Do not rework business logic.
- Do not change auth/session/onboarding routing decisions.
- Do not change tab order or navigation structure.
- Do not change Plaid, Supabase, finance data, or Rex backend behavior.
- Do not change transaction/account/budget semantics while reviewing finance colors.
- Keep financial UI changes under `apps/mobile/lib/features`.
- Keep Rex UI changes under `apps/mobile/lib/rex`.
- Do not add new product flows.
- Do not overuse blur, glow, or glassmorphism.
- Keep performance production-ready.
- Keep all colors centralized.

## Execution Notes

- Treat Plan 1 shared components as primitives, not as a mandate to replace every existing domain widget.
- Preserve existing controllers, view models, repositories, callbacks, and user-scoped data behavior.
- Prefer small file-by-file migrations that keep each screen reviewable.
- Add focused widget tests only when a migrated screen changes layout contracts, navigation contracts, or key empty/error state behavior.

## Expected Visual Changes

- Auth and onboarding should feel like the same premium system as the splash.
- Dashboard, Accounts, Budgets, Assistant, and Profile should share consistent cards, borders, spacing, inputs, buttons, and loading states.
- Main screens should stay calm, dark, precise, and high-end.
- Screen-level old warm/gold or generic Material styling should be removed.

## Verification

Run from `apps/mobile`:

```bash
flutter analyze
flutter test test/app_routing_test.dart test/assistant_navigation_test.dart
```

Add focused widget tests only if a screen migration changes layout assumptions or existing test contracts.

## Completion Report

After implementation, report:

- Files changed.
- Screens migrated.
- Any visual areas intentionally left for Plan 3.
- Whether `flutter analyze` passed.
- Whether targeted tests passed.
