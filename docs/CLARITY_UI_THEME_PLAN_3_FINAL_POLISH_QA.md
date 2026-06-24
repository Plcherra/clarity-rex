# Clarity UI Theme Plan 3: Final Polish And QA

## Status

| Item | State |
|------|-------|
| Static splash (`clarity_splash_screen.png` full-screen) | Done |
| Splash fallback chain | Done |
| Android native launch `#050D1A` | Done (prior) |
| iOS LaunchScreen `#050D1A` | Done (prior) |
| App icon from `clarity_app_icon.png` on white background | Done |
| Hardcoded color audit | Done |
| Manual iPhone QA | Pending (Mac/Xcode) |

**Last updated:** 2026-06-24

## Splash And Brand Tracker

- [x] `ClaritySplashScreen` uses full-screen `clarity_splash_screen.png`
- [x] Splash image upscaled to a higher-resolution 9:16 asset for cleaner rendering
- [x] Minimum display ~600ms + 520ms fade when boot is ready
- [x] Fallback: `clarity_splash_screen.png` → `clarity_mark.png` → `ClarityDiamondLoader`
- [x] Splash remains visual-only (no routing changes)
- [x] Asset path: `apps/mobile/assets/brand/clarity_splash_screen.png`
- [x] `clarity_app_icon.png` enlarged slightly and generated into iOS/Android launcher assets
- [x] Launcher icon background is opaque white for Apple compatibility
- [ ] Manual iPhone QA (signed out/in, onboarding, all tabs, Rex flows)

## Goal

Finish the Clarity visual system after the main migration by tuning consistency, responsiveness, splash behavior, and test coverage.

## Scope

- Tune responsive spacing for common iPhone and Android widths.
- Tune glow intensity, borders, shadows, card contrast, and text hierarchy.
- Review all hardcoded colors across `apps/mobile/lib`.
- Confirm the static splash behavior:
  - Full-screen branded splash image.
  - Not stretched or distorted.
  - Fades smoothly into the app after startup is ready.
  - Falls back to `clarity_mark.png`, then `ClarityDiamondLoader`, if the splash asset is missing.
- Confirm the splash image asset exists at:
  - `apps/mobile/assets/brand/clarity_splash_screen.png`
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
flutter analyze
flutter test
```

Regenerate launcher icons after source icon changes with the configured
`flutter_launcher_icons` workflow, then confirm the generated iOS/Android assets.

If full tests reveal unrelated failures, report them separately and keep UI fixes scoped.

## Completion Report

**Files changed:**

- `apps/mobile/lib/screens/splash/clarity_splash_screen.dart`
- `apps/mobile/pubspec.yaml` (flutter_launcher_icons config)
- `apps/mobile/assets/brand/clarity_splash_screen.png`
- `apps/mobile/assets/brand/clarity_app_icon.png`
- iOS and Android generated launcher icon assets
- `apps/mobile/android/app/src/main/res/values/colors.xml`

**Splash/runtime status:** full-screen `clarity_splash_screen.png` splash; routing unchanged.

**Launcher icon status:** enlarged white-background `clarity_app_icon.png`; generated iOS/Android launcher assets refreshed.

**Manual QA:** pending on physical iPhone via Mac/Xcode.

**Verification:** `dart analyze lib/screens/splash/clarity_splash_screen.dart` passed locally. Run full `flutter analyze` and `flutter test` before release/manual signoff.
