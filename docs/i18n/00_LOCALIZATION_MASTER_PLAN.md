# Clarity Localization Master Plan

## Goal

Build a clean, extensible localization system so English is the single source of truth and each new language is mostly translate + enable.

## Plan Files (execute in order)

1. [`01_PHASE_S1_LOCALE_CATALOG_AND_MATCHING.md`](01_PHASE_S1_LOCALE_CATALOG_AND_MATCHING.md) — locale catalog, full-locale tags, English-only enablement
2. [`02_PHASE_S2_ENGLISH_ARB_MIGRATION.md`](02_PHASE_S2_ENGLISH_ARB_MIGRATION.md) — move all user-facing copy into `app_en.arb`
3. [`03_PHASE_S3_SERVICE_PROVIDER_STRING_AUDIT.md`](03_PHASE_S3_SERVICE_PROVIDER_STRING_AUDIT.md) — services/providers receive l10n, not hardcoded English
4. [`04_PHASE_S4_BACKEND_LOCALE_REGISTRY.md`](04_PHASE_S4_BACKEND_LOCALE_REGISTRY.md) — Rex API locale registry + category N-language shape
5. [`05_PHASE_L1_SPANISH_IMPLEMENTATION.md`](05_PHASE_L1_SPANISH_IMPLEMENTATION.md) — first real language (Spanish)

Execute **one plan file at a time**, in order. Do not start L1 until S1–S4 acceptance criteria pass.

## Principles

- `app_en.arb` is the source of truth.
- Full locale tags from day one (`en`, `es`, `pt-BR`, `pt-PT`).
- No hardcoded user-facing `Text('...')` after S2.
- Profile picker shows only **enabled** languages.
- Rex conversational locale follows app locale; Rex deterministic actions stay English until a future phase.

## Current Baseline (already done)

- gen-l10n scaffold: [`apps/mobile/l10n.yaml`](../../apps/mobile/l10n.yaml), partial [`app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb)
- [`LocaleController`](../../apps/mobile/lib/features/profile/application/locale_controller.dart), [`AppLocale`](../../apps/mobile/lib/core/l10n/app_locale.dart)
- `profiles.preferred_locale` migration
- Locale-aware formatting, category label resolver (partial ES labels exist)
- Chat/voice `locale` API contract + [`locale_utils.py`](../../services/rex-api/app/services/locale_utils.py)
- Pilot ARB migration: auth, shell nav, profile, import banner

## Deferred (not in S1–L1)

- Portuguese, French, and other languages (same pattern as L1)
- Rex goal/memory/recall intent patterns in non-English
- Marketing site / email template localization
- Auto-detect spoken language in voice
