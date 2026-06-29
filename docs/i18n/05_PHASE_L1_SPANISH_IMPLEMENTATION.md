# Phase L1 — Spanish Language Implementation

## Goal

Ship **Spanish** as the first real localized language. After S1–S4, this phase is mostly: translate `app_es.arb`, enable `es` in the catalog, add backend/category Spanish rows, verify end-to-end.

## Prerequisites

- S1: catalog + full locale matching complete
- S2: 100% English ARB migration complete
- S3: service/provider injection complete
- S4: backend registry + category structure complete

## Target End State

- User can select **Español** in Profile → Language.
- All migrated UI strings display in Spanish.
- Money/dates format with Spanish locale rules.
- Built-in category labels show Spanish.
- Rex chat and voice receive `locale: es` and respond in Spanish conversationally.
- English remains available; switching is instant and persisted.

## Files to Modify

- [`apps/mobile/lib/l10n/app_es.arb`](../../apps/mobile/lib/l10n/app_es.arb) — professional Spanish translations for all keys
- [`apps/mobile/lib/core/l10n/clarity_locale_catalog.dart`](../../apps/mobile/lib/core/l10n/clarity_locale_catalog.dart) — set `es` spec `enabled: true`
- [`apps/mobile/lib/features/categories/domain/category_display_labels.dart`](../../apps/mobile/lib/features/categories/domain/category_display_labels.dart) — populate `es` for all built-in categories
- [`services/rex-api/app/services/locale_registry.py`](../../services/rex-api/app/services/locale_registry.py) — enable `es` spec; confirm `stt_code`/`tts_code` (e.g. `es-US` or `es-MX` — pick one product default)
- [`apps/mobile/test/helpers/l10n_test_wrapper.dart`](../../apps/mobile/test/helpers/l10n_test_wrapper.dart) — add optional ES smoke helper

## Files to Create

- [`apps/mobile/test/l10n_spanish_smoke_test.dart`](../../apps/mobile/test/l10n_spanish_smoke_test.dart) — pilot screens render Spanish without crashes
- [`docs/i18n/L1_SPANISH_VERIFICATION.md`](L1_SPANISH_VERIFICATION.md) — manual QA checklist (optional, short)

## Step-by-Step Work Plan

### 1. Translate ARB

- Translate every key in `app_en.arb` to natural Spanish (neutral/LATAM-friendly unless product chooses Spain Spanish).
- Handle plurals and `{placeholder}` strings correctly.
- Run `flutter gen-l10n`; fix any missing-key errors.

### 2. Enable Spanish

- Catalog: `es` enabled in picker.
- Verify device-locale `es` resolves to Spanish without manual selection.

### 3. Category + backend

- Add `es` labels to category map.
- Enable `es` in backend registry; verify prompt rule and voice STT/TTS.

### 4. QA pass

- Screen-by-screen Spanish review: auth, dashboard, accounts, budgets, assistant, profile.
- Rex chat: ask a finance question — response in Spanish.
- Rex voice: short Spanish utterance — STT/TTS in Spanish.
- Confirm deterministic actions (goals/memory) still work in English commands; document limitation if Spanish commands fail.

## Acceptance Criteria

- [ ] Profile picker shows English and Español.
- [ ] All ARB-covered UI displays Spanish when selected.
- [ ] No missing localization keys at runtime.
- [ ] `preferred_locale` persists as `es`.
- [ ] Rex API receives `locale: es` on chat and voice.
- [ ] Category labels and date/money formatting respect Spanish locale.
- [ ] App aesthetic unchanged — dark, minimal, professional.

## Verification

- `flutter gen-l10n`
- `flutter test test/l10n_spanish_smoke_test.dart`
- `flutter test test/locale_controller_test.dart test/formatting_test.dart`
- `python -m pytest services/rex-api/tests/test_locale_registry.py -q`
- Manual smoke checklist:
  - Switch to Español → nav labels Spanish
  - Dashboard amounts/dates formatted for Spanish locale
  - Rex chat reply in Spanish
  - Voice session accepts Spanish speech
  - Switch back to English cleanly

## Deferred

- `es-MX` vs `es-ES` as separate picker entries (future regional phase)
- Portuguese and French (repeat L-pattern: L2, L3…)
- Rex goal/memory/recall commands in Spanish
- Spanish email templates and marketing site
