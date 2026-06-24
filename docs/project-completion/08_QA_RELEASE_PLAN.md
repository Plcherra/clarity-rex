# QA And Release Completion Plan

## Goal

Define the final verification path that proves Clarity is ready for beta or production release.

## Release Definition

Clarity is release-ready when:

- Auth, onboarding, profile, MFA, and sign out work.
- Dashboard, Accounts, Budgets, Transactions, Plaid, and CSV flows work.
- Rex chat and voice use real backend paths.
- Memory and old chat recall are honest and reliable.
- Goals and accountability are either complete or intentionally scoped.
- Light, dark, and system themes are polished.
- Tests and smoke checks pass.

## Test Plan

### 1. Static Checks

- `flutter analyze`
- `flutter test`
- backend `python -m pytest`
- Edge Function type checks where Deno is available:
  - `call-openai`
  - `categorize-transactions`
  - `send-mfa-security-email`
- `git diff --check`

### 2. Backend Smoke

- `/` returns ok.
- `/ready` returns ready or expected degraded status with clear details.
- Authenticated `/chat` works.
- Streaming `/chat` works.
- `/conversations` list/search/messages work.
- `/memory` list/update/archive works.
- `/accountability/overview` works.
- `/voice/turn` or `/voice/stream` works when configured.
- Plaid link token creation works in sandbox.

### 3. Mobile Smoke

Auth:

- Sign up.
- Sign in.
- MFA enrollment.
- MFA verification.
- Sign out.

Finance:

- Create manual account.
- Import CSV.
- Connect Plaid sandbox account.
- Sync Plaid transactions.
- View Dashboard.
- View account detail.
- Correct category.
- Create/update budget.

Rex:

- Send chat.
- Stream chat.
- Ask finance question.
- Save memory.
- Recall saved memory.
- Recall old chat history.
- Edit/archive Knows item.
- Use conversation history.

Voice:

- Start voice session.
- Complete voice turn.
- Interrupt voice.
- Ask memory save by voice.
- Ask finance question by voice.
- Confirm usage updates.

Goals:

- View Goals overview.
- Create/edit/complete goal records if UI is implemented.
- Confirm Rex and Goals show same records.

Themes:

- Light mode.
- Dark mode.
- System mode.
- Small screen layout.

### 4. Data Truth Checks

- Dashboard totals match transaction records.
- Budgets use the same categories as transactions.
- Rex finance answers use visible app data.
- Rex does not invent balances or transactions.
- Chat history is not labeled as saved memory.
- Backend-confirmed actions show success; failed actions show failure.

### 5. Regression Areas

Run targeted regressions after touching:

- Recall/search.
- Memory save/update/delete.
- Financial context.
- Plaid sync.
- CSV import.
- Voice.
- Theme tokens.
- Navigation.

## Launch Blockers

Do not release if:

- Rex claims a save/action succeeded without backend confirmation.
- Rex guesses finance data.
- Plaid secrets or service-role keys are exposed to mobile.
- Auth/RLS scoping allows cross-user data access.
- Main navigation has unreachable or broken surfaces.
- Voice gets stuck in a loop or cannot recover from failure.
- Light/dark themes have unreadable text or controls.

## Release Artifacts

Before release, update:

- `docs/PROJECT_MAP.md`
- `docs/CLARITY_BETA_SMOKE_RUNBOOK.md`
- `docs/CLARITY_BETA_SMOKE_RESULTS_YYYY_MM_DD.md`
- `docs/ui/CLARITY_UI_QA.md`
- Backend env example if env vars changed.
- Mobile README if run commands changed.

## Final Signoff Checklist

- [ ] Working tree clean.
- [ ] Full backend tests pass.
- [ ] Full Flutter tests pass.
- [ ] Manual smoke completed on target device.
- [ ] `/ready` checked in deployment environment.
- [ ] Supabase migrations applied.
- [ ] Edge Functions deployed.
- [ ] Plaid sandbox flow verified.
- [ ] Rex chat and voice verified.
- [ ] Known release limitations documented.
