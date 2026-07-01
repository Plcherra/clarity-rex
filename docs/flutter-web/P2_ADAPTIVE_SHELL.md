# P2 — Adaptive Shell and Finance UX

**Previous:** [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md) (exit criteria met)  
**Next:** [P3_REX_CHAT_KNOWS.md](./P3_REX_CHAT_KNOWS.md)

**Status:** **Complete** (2026-06-30)

## Objective

Web/desktop feels intentional — not a stretched phone app. All finance tabs usable on wide screens.

## Prerequisites

- P1 complete: app boots and authenticates on Chrome

## Tasks

### 1. Adaptive `HomeShell`

Extract layout (~150–250 lines max) from `home_shell.dart`:

| Viewport | Navigation |
|----------|------------|
| `< 800px` | Current bottom `NavigationBar` (mobile unchanged) |
| `≥ 800px` | `NavigationRail` + expanded content |

Reuse width patterns from `assistant_screen.dart` (`isCompactWidth`).

Consider new file: `home_shell_layout.dart` if `home_shell.dart` approaches 400 lines.

### 2. Max content width

On ultra-wide screens, center content with max width ~1200–1400px for:

- Dashboard
- Accounts
- Budgets
- Transactions
- Profile

### 3. Keyboard and scroll polish

- Budgets full-page scroll (already mobile-friendly; verify on web)
- Modal sheets and dialogs: no double-scroll traps
- Tab focus / Enter key on primary actions where cheap

### 4. Finance tabs on web

Verify read + existing write flows (no native plugins):

- Dashboard — cash flow, categories, health cards
- Accounts — list, manual accounts, Plaid status display (connect button gated until P4)
- Budgets — targets, category rows, edit flows
- Transactions — month list, filters, detail
- Profile — theme, locale, settings

### 5. CSV import gate

Until file picker verified on web, gate CSV import behind `AppCapabilities.supportsCsvImport` with honest copy: "Import CSV is available in the mobile app for now."

## Exit criteria

- [x] 1280×800 Chrome: all five main tabs render without layout breakage
- [x] NavigationRail on desktop; bottom nav on narrow viewport
- [x] Finance numbers match mobile for same user account
- [x] Layout test or routing test for breakpoint behavior

## Files touched

- `apps/mobile/lib/features/shell/presentation/home_shell.dart`
- `apps/mobile/lib/features/shell/presentation/home_shell_layout.dart` (new)
- `apps/mobile/lib/core/layout/finance_content_constraints.dart` (new)
- Finance presentation screens (padding/constraints only — minimal diffs)
- `apps/mobile/lib/features/accounts/presentation/widgets/connect_bank_setup_card.dart`
- `apps/mobile/lib/features/accounts/presentation/accounts_screen.dart`
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart`
- `apps/mobile/lib/features/dashboard/presentation/month_detail_screen.dart`
- `apps/mobile/lib/features/accounts/presentation/account_detail_screen.dart`
- `apps/mobile/lib/core/supabase/supabase_records.dart` (date-only timezone fix)
- `apps/mobile/lib/l10n/app_en.arb`, `app_es.arb`, generated localizations
- `apps/mobile/test/home_shell_layout_test.dart` (new)
- `apps/mobile/test/supabase_records_test.dart` (new)
- `apps/mobile/test/app_routing_test.dart` (extended)

## Bonus (same session)

- Transaction date timezone: Supabase `YYYY-MM-DD` fields normalize to local calendar date at noon (same pattern as CSV import), fixing June 30 vs July 1 display in negative-offset timezones.

## Out of scope (defer)

- Rex chat fixes (P3)
- Plaid connect (P4)
- Voice (P5)
