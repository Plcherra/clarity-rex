# Phase S2 — Complete English-only ARB Migration

## Goal

Move **all** user-facing mobile copy into [`app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb). English becomes the single source of truth. No translations yet — other ARB files stay stubs or mirror English until their language phase.

## Target End State

- Zero hardcoded user-facing strings in widgets, dialogs, snackbars, tooltips, and empty states under `lib/features/` and `lib/rex/`.
- Consistent ARB key naming: `featureScreen_element` (e.g. `accountsScreen_connectBank`).
- Pluralization and placeholders use ARB `@` metadata where needed.
- Widget tests use [`test/helpers/l10n_test_wrapper.dart`](../../apps/mobile/test/helpers/l10n_test_wrapper.dart) with `Locale('en')`.
- UI appearance unchanged — same dark, minimal layout; only string source changes.

## Current Gaps

- ~35 ARB keys vs ~40+ files still using inline `Text('...')`, `hintText`, `SnackBar`, dialog titles.
- Partial migration: auth, shell nav, profile appearance/language, import banner only.
- MFA, dashboard, accounts, budgets, Rex chat/voice/memory/goals still hardcoded.

## Files to Modify (by batch)

### Batch 1 — Dashboard & accounts (highest visibility)

- [`features/dashboard/presentation/`](../../apps/mobile/lib/features/dashboard/presentation/) — shell, cards, summary, transaction controls, month detail
- [`features/accounts/presentation/`](../../apps/mobile/lib/features/accounts/presentation/) — accounts screen, detail, selection, add dialog, CSV warning, headers, connect bank, plaid tile
- [`features/onboarding/presentation/onboarding_screen.dart`](../../apps/mobile/lib/features/onboarding/presentation/onboarding_screen.dart)

### Batch 2 — Budgets & transactions

- [`features/budgets/presentation/`](../../apps/mobile/lib/features/budgets/presentation/) — screen, header, category management sheet + widgets/dialogs/sections
- [`features/transactions/presentation/widgets/transaction_category_dropdown.dart`](../../apps/mobile/lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart)
- [`features/transactions/application/import_job_status_service.dart`](../../apps/mobile/lib/features/transactions/application/import_job_status_service.dart) — replace default English with ARB key at call site (full injection in S3)

### Batch 3 — Rex assistant UI

- [`rex/chat/presentation/`](../../apps/mobile/lib/rex/chat/presentation/) — chat page, conversation list, input bar, attachment sheet, message bubble
- [`rex/chat/presentation/widgets/inline_voice_call_panel.dart`](../../apps/mobile/lib/rex/chat/presentation/widgets/inline_voice_call_panel.dart)
- [`rex/voice/application/voice_transcript_buffer.dart`](../../apps/mobile/lib/rex/voice/application/voice_transcript_buffer.dart) — user-visible status strings only

### Batch 4 — Memory, Goals, Accountability

- [`rex/memory/presentation/`](../../apps/mobile/lib/rex/memory/presentation/) — memory page, edit/archive dialogs, headers, display helpers
- [`rex/accountability/presentation/`](../../apps/mobile/lib/rex/accountability/presentation/) — page, tiles, detail sheets, shared widgets

### Batch 5 — Auth MFA, profile remainder, admin

- [`features/auth/presentation/mfa_enrollment_screen.dart`](../../apps/mobile/lib/features/auth/presentation/mfa_enrollment_screen.dart)
- [`features/auth/presentation/mfa_verification_screen.dart`](../../apps/mobile/lib/features/auth/presentation/mfa_verification_screen.dart)
- [`features/profile/presentation/profile_screen.dart`](../../apps/mobile/lib/features/profile/presentation/profile_screen.dart) — remaining hardcoded strings
- [`features/profile/presentation/usage_summary_screen.dart`](../../apps/mobile/lib/features/profile/presentation/usage_summary_screen.dart)
- [`features/usage_admin/presentation/`](../../apps/mobile/lib/features/usage_admin/presentation/) — if user-facing in beta
- [`app/bootstrap.dart`](../../apps/mobile/lib/app/bootstrap.dart) — boot error copy

### Batch 6 — Shell & shared widgets

- [`features/shell/presentation/home_shell.dart`](../../apps/mobile/lib/features/shell/presentation/home_shell.dart) — remaining strings
- Any shared widgets under [`lib/widgets/`](../../apps/mobile/lib/widgets/) with user-facing copy

## Files to Create / Update

- Expand [`apps/mobile/lib/l10n/app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb) — all new keys
- Update [`apps/mobile/lib/l10n/app_es.arb`](../../apps/mobile/lib/l10n/app_es.arb) — **English placeholders only** (mirror `app_en` values) until L1
- Add ARB header comment in `app_en.arb` documenting key naming convention
- Optional: [`docs/i18n/ARB_CONVENTIONS.md`](ARB_CONVENTIONS.md) — key naming, plurals, service-layer rules

## Step-by-Step Work Plan

### 1. Inventory and key naming pass

- Grep `Text('`, `hintText:`, `SnackBar`, `AlertDialog`, `tooltip:` under `lib/features` and `lib/rex`.
- Assign stable keys before editing widgets.

### 2. Migrate batch by batch

- Replace inline strings with `context.l10n.key`.
- Use `@placeholder` for dynamic values (names, counts, dates formatted elsewhere).
- Run `flutter gen-l10n` after each batch.

### 3. Fix tests per batch

- Wrap affected widget tests with `wrapWithL10n`.
- Update `find.text(...)` only when necessary; prefer keys/semantics for new tests.

### 4. Final sweep

- Grep confirms no user-facing hardcoded strings remain in scope.
- `app_es.arb` contains every key from `app_en.arb` with English placeholder text.

## Acceptance Criteria

- [ ] Every user-facing string in `lib/features/` and `lib/rex/` comes from `app_en.arb`.
- [ ] `app_es.arb` has 100% key parity with `app_en.arb` (English placeholders).
- [ ] No visual/layout changes beyond text source.
- [ ] `flutter gen-l10n` succeeds; app builds.
- [ ] Existing widget tests pass with English locale wrapper.

## Verification

- `flutter gen-l10n`
- `flutter test` (mobile)
- Manual smoke: auth → dashboard → accounts → budgets → assistant → profile (all English, no missing-key crashes)
- Grep audit: no remaining `Text('` with literal English in migrated directories

## Deferred

- Spanish/Portuguese/French translations (L1+)
- Service-layer injection cleanup (S3)
- Backend locale registry (S4)
- Rex inline voice panel redesign
