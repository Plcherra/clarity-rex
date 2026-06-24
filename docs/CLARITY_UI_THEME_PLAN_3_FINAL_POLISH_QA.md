# Clarity UI Theme Plan 3: Final Polish And QA

## Goal

Finish the Clarity visual system after the main migration by tuning consistency, responsiveness, splash behavior, and test coverage.

## Scope

- Tune responsive spacing for common iPhone and Android widths.
- Tune glow intensity, borders, shadows, card contrast, and text hierarchy.
- Review all hardcoded colors across `apps/mobile/lib`.
- Confirm the static splash behavior:
  - Full-screen `#050D1A` background.
  - Centered logo image at the preferred size.
  - Not stretched or distorted.
  - Fades smoothly into the app after startup is ready.
  - Falls back to `clarity_mark.png`, then `ClarityDiamondLoader`, if the splash logo asset is missing.
- Confirm the splash logo asset exists at:
  - `apps/mobile/assets/brand/splash_logo.png`
- Run a visual sweep of all main flows.
- Run broader Flutter tests.

## Manual QA Flows

- Signed out startup.
- Signed in startup.
- Onboarding path.
- Dashboard empty state.
- Dashboard populated state.
- Accounts and Plaid entry points.
- Budgets.
- Assistant chat.
- Assistant memory/Knows.
- Assistant goals.
- Assistant chats/history.
- Profile.
- Security/MFA screens.
- Voice usage screens.

## Constraints

- Do not introduce new architecture.
- Do not change business logic unless a UI bug requires a minimal fix.
- Do not add topic-specific Rex behavior.
- Do not change Plaid, Supabase, finance data, or Rex backend behavior.
- Keep all final color decisions centralized in the theme layer.

## Verification

Run from `apps/mobile`:

```bash
flutter analyze
flutter test
```

If full tests reveal unrelated failures, report them separately and keep UI fixes scoped.

## Completion Report

After implementation, report:

- Files changed.
- Final polish areas completed.
- Splash asset/runtime status.
- Manual QA coverage completed.
- Whether `flutter analyze` passed.
- Whether full `flutter test` passed.
