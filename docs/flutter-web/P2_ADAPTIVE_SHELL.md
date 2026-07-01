# P2 — Adaptive Shell and Finance UX

**Previous:** [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md) (exit criteria met)  
**Next:** [P3_REX_CHAT_KNOWS.md](./P3_REX_CHAT_KNOWS.md)

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

- [ ] 1280×800 Chrome: all five main tabs render without layout breakage
- [ ] NavigationRail on desktop; bottom nav on narrow viewport
- [ ] Finance numbers match mobile for same user account
- [ ] Layout test or routing test for breakpoint behavior

## Files likely touched

- `apps/mobile/lib/features/shell/presentation/home_shell.dart`
- `apps/mobile/lib/features/shell/presentation/home_shell_layout.dart` (new, if split)
- Finance presentation screens (padding/constraints only — minimal diffs)
- `apps/mobile/test/app_routing_test.dart` (extend)

## Out of scope (defer)

- Rex chat fixes (P3)
- Plaid connect (P4)
- Voice (P5)
