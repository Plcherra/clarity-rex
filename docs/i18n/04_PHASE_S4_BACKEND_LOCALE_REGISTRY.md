# Phase S4 — Backend Locale Registry & Category Structure

## Goal

Make Rex API locale handling data-driven and extensible. Prepare category labels for N languages with English-only content until each language phase.

## Target End State

- [`locale_utils.py`](../../services/rex-api/app/services/locale_utils.py) uses a registry (`LocaleSpec`) instead of scattered dicts.
- Adding a language = one registry row + tests (no scattered if/else).
- Region-aware STT/TTS codes supported (`pt-BR` vs `pt-PT`).
- Mobile category map has N-language shape; **only `en` populated** (remove or ignore pre-filled `es` until L1).
- Chat/voice prompt rule uses registry label.

## Current Gaps

- Hardcoded `_LOCALE_LANGUAGE_LABELS`, `_STT_CODES`, `_TTS_CODES` for en/es only.
- `normalize_locale()` strips region — loses pt-BR vs pt-PT distinction for voice.
- [`category_display_labels.dart`](../../apps/mobile/lib/features/categories/domain/category_display_labels.dart) already has `es` entries — should be en-only until L1.

## Files to Create

- [`services/rex-api/app/services/locale_registry.py`](../../services/rex-api/app/services/locale_registry.py)
  - `LocaleSpec(language, regions, prompt_label, stt_code, tts_code, enabled)`
  - `resolve_locale_tag(tag) -> LocaleSpec` with fallback chain
- [`services/rex-api/tests/test_locale_registry.py`](../../services/rex-api/tests/test_locale_registry.py)

## Files to Modify

- [`services/rex-api/app/services/locale_utils.py`](../../services/rex-api/app/services/locale_utils.py) — delegate to registry; preserve public function signatures
- [`services/rex-api/app/services/prompt_service.py`](../../services/rex-api/app/services/prompt_service.py) — no change beyond locale_utils
- [`services/rex-api/app/services/voice_stream_config.py`](../../services/rex-api/app/services/voice_stream_config.py) — use registry for instructions
- [`services/rex-api/app/routes/voice.py`](../../services/rex-api/app/routes/voice.py) — STT/TTS from resolved spec
- [`services/rex-api/app/services/deepgram_service.py`](../../services/rex-api/app/services/deepgram_service.py) — accept resolved language code
- [`apps/mobile/lib/features/categories/domain/category_display_labels.dart`](../../apps/mobile/lib/features/categories/domain/category_display_labels.dart)
  - Keep `{ en, es?, pt?, ... }` shape per category
  - Strip `es` values (or comment as L1 TODO); en-only content for now
  - Add `resolveLabel(normalizedName, localeTag)` with fallback: tag → language → en → DB name
- [`apps/mobile/lib/features/categories/application/category_read_model.dart`](../../apps/mobile/lib/features/categories/application/category_read_model.dart) — pass full locale tag

## Step-by-Step Work Plan

### 1. Backend registry

- Define specs for `en`, `es`, `pt-BR`, `pt-PT`, `fr` (only `en` enabled for production defaults).
- `locale_to_stt_code('pt-BR')` → `pt-BR`; `locale_to_stt_code('pt-PT')` → `pt-PT`.
- Unknown locale → `en-US` safe fallback.

### 2. Refactor locale_utils

- Thin wrapper over registry; keep existing tests passing, extend with region cases.

### 3. Mobile category structure

- En-only labels in map.
- Resolver uses `localeTag` from S1 catalog.

### 4. Align mobile ↔ backend tags

- Confirm `AppLocale.rexLocaleTag()` matches registry parsing (`en`, `es`, `pt-BR`, etc.).

## Acceptance Criteria

- [ ] Registry is the single backend source for prompt labels and STT/TTS codes.
- [ ] Region tags resolve correctly in tests (`pt-BR`, `pt-PT`, `es-MX` → appropriate codes).
- [ ] Category UI shows English labels regardless of device locale (until L1).
- [ ] Existing locale tests pass; new registry tests added.

## Verification

- `python -m pytest services/rex-api/tests/test_locale_utils.py services/rex-api/tests/test_locale_registry.py -q`
- `flutter test test/formatting_test.dart`
- Manual: Rex chat with `locale: en` in API — behavior unchanged

## Deferred

- Populating ES/PT/FR category translations (L1+)
- Rex goal/memory intent localization
- Spanish TTS voice tuning
