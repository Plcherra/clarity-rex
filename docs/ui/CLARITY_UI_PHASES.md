# Clarity UI Phases

## Active Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Theme foundation: semantic dark/light tokens | In progress |
| 2 | Shared components: cards, buttons, loaders, Rex surfaces | In progress |
| 3 | Assistant/Rex simplification | In progress |
| 4 | Finance, budgets, accounts, profile polish | In progress |
| 5 | Appearance toggle and light theme enablement | In progress |
| 6 | Automated and manual QA | In progress |

## Archived Tactical Plans

The earlier June 24 tactical plans are historical execution records. They are
superseded by the current vision and token system:

- `docs/ui/archive/2026-06-24_phase-1-finance-quick-fixes.md`
- `docs/ui/archive/2026-06-24_phase-2-assistant-profile.md`
- `docs/ui/archive/2026-06-24_phase-3-voice-theme-lightening.md`

## Constraints For Every Phase

- Presentation-only unless a phase explicitly says otherwise.
- Do not change Plaid, Supabase, Rex Brain, voice backend, auth, or data flows.
- Keep financial UI under `apps/mobile/lib/features`.
- Keep Rex UI under `apps/mobile/lib/rex`.
- Prefer central tokens and shared components over one-off screen styling.
- Do not add new cards, borders, descriptions, or text unless needed for
  accessibility or an existing product action.
