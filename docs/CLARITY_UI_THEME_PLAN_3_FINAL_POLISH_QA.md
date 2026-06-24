# Clarity UI Theme Plan 3: Final Polish And QA

## Status

| Item | State |
|------|-------|
| Static splash (centered logo on `#050D1A`) | Done |
| Splash fallback chain | Done |
| Android native launch `#050D1A` | Done (prior) |
| iOS LaunchScreen `#050D1A` | Done (prior) |
| App icon from `clarity_app_icon.png` | Done |
| Hardcoded color audit | Done |
| Manual iPhone QA | Pending (Mac/Xcode) |

**Last updated:** 2026-06-24

## Splash And Brand Tracker

- [x] `ClaritySplashScreen` uses full-screen `#050D1A` + centered `splash_logo.png`
- [x] Logo sized at ~42% shortest side (148–220px clamp)
- [x] Minimum display ~600ms + 520ms fade when boot is ready
- [x] Fallback: `splash_logo.png` → `clarity_mark.png` → `ClarityDiamondLoader`
- [x] Splash remains visual-only (no routing changes)
- [x] Asset path: `apps/mobile/assets/brand/splash_logo.png`
- [x] `flutter_launcher_icons` run to refresh iOS/Android launcher assets
- [ ] Manual iPhone QA (signed out/in, onboarding, all tabs, Rex flows)

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
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
```

If full tests reveal unrelated failures, report them separately and keep UI fixes scoped.

## Completion Report

**Files changed:**

- `apps/mobile/lib/screens/splash/clarity_splash_screen.dart`
- `apps/mobile/pubspec.yaml` (flutter_launcher_icons config)

**Splash/runtime status:** centered transparent logo splash on `#050D1A`; routing unchanged.

**Manual QA:** pending on physical iPhone via Mac/Xcode.

**Verification:** run full `flutter test` after pull; confirm launcher icons after `dart run flutter_launcher_icons`.
