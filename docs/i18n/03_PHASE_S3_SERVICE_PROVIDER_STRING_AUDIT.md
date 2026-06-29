# Phase S3 — Service & Provider String Injection Audit

## Goal

Ensure non-widget layers never hardcode English. Services and Riverpod providers receive `AppLocalizations` or localized callbacks from the composition root, keyed to the active full locale.

## Target End State

- All user-visible messages from services/controllers flow through l10n or injected formatters.
- [`app.dart`](../../apps/mobile/lib/app/app.dart) ProviderScope overrides wire locale-aware dependencies once.
- No `lookupAppLocalizations(const Locale('en'))` defaults without override.
- Pattern documented and applied consistently for future features.

## Current Gaps

- [`import_job_status_service.dart`](../../apps/mobile/lib/features/transactions/application/import_job_status_service.dart) — `_defaultIdleProgressMessage = 'Uploading transactions...'`
- [`chat_action_result_formatter.dart`](../../apps/mobile/lib/rex/chat/application/chat_action_result_formatter.dart) — default provider still pins English
- [`app.dart`](../../apps/mobile/lib/app/app.dart) — formatter override uses `languageCode` not full `Locale`
- Voice/chat controllers may surface hardcoded error strings
- [`ui_dependencies.dart`](../../apps/mobile/lib/app/ui_dependencies.dart) — `configureIdleProgressMessage` wired with English at call site

## Files to Modify

- [`apps/mobile/lib/app/app.dart`](../../apps/mobile/lib/app/app.dart) — central locale-aware provider overrides
- [`apps/mobile/lib/app/ui_dependencies.dart`](../../apps/mobile/lib/app/ui_dependencies.dart) — pass l10n-derived messages at bind time
- [`apps/mobile/lib/features/transactions/application/import_job_status_service.dart`](../../apps/mobile/lib/features/transactions/application/import_job_status_service.dart) — remove default English; require configured message or callback
- [`apps/mobile/lib/features/shell/presentation/import_job_progress_banner.dart`](../../apps/mobile/lib/features/shell/presentation/import_job_progress_banner.dart) — supply localized idle message
- [`apps/mobile/lib/rex/chat/application/chat_action_result_formatter.dart`](../../apps/mobile/lib/rex/chat/application/chat_action_result_formatter.dart) — remove hardcoded default; document override requirement
- [`apps/mobile/lib/rex/chat/application/chat_controller.dart`](../../apps/mobile/lib/rex/chat/application/chat_controller.dart) — inject error message resolver if needed
- [`apps/mobile/lib/rex/voice/application/voice_call_controller.dart`](../../apps/mobile/lib/rex/voice/application/voice_call_controller.dart) (+ related parts) — user-facing errors → ARB or callback
- [`apps/mobile/lib/features/categories/application/category_read_model.dart`](../../apps/mobile/lib/features/categories/application/category_read_model.dart) — use full locale tag from controller when resolving labels

## Files to Create

- [`apps/mobile/lib/core/l10n/app_localizations_lookup.dart`](../../apps/mobile/lib/core/l10n/app_localizations_lookup.dart) — `AppLocalizations forLocale(Locale locale)` helper using full tag
- [`apps/mobile/test/app_localizations_lookup_test.dart`](../../apps/mobile/test/app_localizations_lookup_test.dart)

## Step-by-Step Work Plan

### 1. Add lookup helper

- `lookupForLocale(Locale locale)` wraps `lookupAppLocalizations` with catalog fallback.
- Use in all provider overrides.

### 2. Audit and fix providers

- Grep: `lookupAppLocalizations`, `'Uploading`, `'Could not`, `'Done.`, hardcoded error strings in `lib/rex` and `lib/features`.
- Each hit: move string to ARB or accept `String Function()` / `AppLocalizations` at construction.

### 3. Wire composition root

- In `ClarityApp` overrides, watch `localeController` and rebuild formatters on locale change.
- `ImportJobProgressBanner` / `ui_dependencies` configure messages from active l10n.

### 4. Document pattern

- Add section to [`docs/i18n/ARB_CONVENTIONS.md`](ARB_CONVENTIONS.md):
  - Widgets → `context.l10n`
  - Services → injected l10n or callbacks
  - Providers → override in `app.dart`

## Acceptance Criteria

- [ ] No service emits hardcoded English user strings.
- [ ] All locale-sensitive providers derive from `localeController.locale` (full tag).
- [ ] Switching locale (when enabled in L1) updates service messages without restart.
- [ ] Default providers throw or use explicit English-only test fallback — not silent production English.

## Verification

- `flutter test test/app_localizations_lookup_test.dart`
- `flutter test test/chat_api_locale_test.dart`
- `flutter test test/locale_controller_test.dart`
- Manual: trigger import progress banner and chat action confirmation — strings come from ARB keys

## Deferred

- Backend confirmation string localization
- Rex deterministic action messages in non-English
