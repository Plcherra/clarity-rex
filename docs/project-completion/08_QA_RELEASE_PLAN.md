# QA And Release Completion Plan

## Goal

Define the final verification path that proves Clarity is ready for beta or production release.

## Status

**In progress.** Plan 8 §1 static checks and §5 targeted regressions **passed** on
2026-06-25. Manual device smoke (§3), deployment `/ready` (§2), and final signoff
checklist items remain open.

Results log: `docs/CLARITY_BETA_SMOKE_RESULTS_2026_06_25.md`

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

**Done (2026-06-25):** analyze clean, 234 Flutter tests, 1016 backend tests,
`git diff --check` clean. Deno 2.8.3 installed; all three Edge Functions
type-check clean; 11/11 `categorize-transactions` Deno tests passed
(`deno test --allow-env --allow-net`).

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

**Done (automated proxy):** route/readiness tests pass. **Pending:** live VPS curl
smoke per `docs/BACKEND_DEPLOY_RUNBOOK.md`.

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
- Create/complete goal records (edit deferred in MVP).
- Confirm Rex and Goals show same records.

Themes:

- Light mode.
- Dark mode.
- System mode.
- Small screen layout.

**Pending:** manual pass using `docs/CLARITY_BETA_SMOKE_RUNBOOK.md`.

### 4. Data Truth Checks

- Dashboard totals match transaction records.
- Budgets use the same categories as transactions.
- Rex finance answers use visible app data.
- Rex does not invent balances or transactions.
- Chat history is not labeled as saved memory.
- Backend-confirmed actions show success; failed actions show failure.

**Pending:** manual/device verification.

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

**Done (2026-06-25):** 134 backend + 88 Flutter critical-path tests passed.

## Launch Blockers

Do not release if:

- Rex claims a save/action succeeded without backend confirmation.
- Rex guesses finance data.
- Plaid secrets or service-role keys are exposed to mobile.
- Auth/RLS scoping allows cross-user data access.
- Main navigation has unreachable or broken surfaces.
- Voice gets stuck in a loop or cannot recover from failure.
- Light/dark themes have unreadable text or controls.
- Supabase Auth cannot send sign-up confirmation email (`verify_supabase_auth_email.sh` fails).

Static review (2026-06-25): no mobile secret exposure; voice loop cap and memory
tests green. Manual blocker checks still required on device.

Auth email (2026-06-26): REX project auth logs show Gmail SMTP `BadCredentials`.
Permanent fix runbook: `docs/SUPABASE_AUTH_EMAIL_SETUP.md` (switch Auth SMTP to Resend).

## Release Artifacts

Before release, update:

- `docs/PROJECT_MAP.md`
- `docs/CLARITY_BETA_SMOKE_RUNBOOK.md`
- `docs/CLARITY_BETA_SMOKE_RESULTS_YYYY_MM_DD.md`
- `docs/ui/CLARITY_UI_QA.md`
- Backend env example if env vars changed.
- Mobile README if run commands changed.

**Done:** `docs/CLARITY_BETA_SMOKE_RESULTS_2026_06_25.md`, `docs/ui/CLARITY_UI_QA.md`
automated section updated.

## Verification Log

- `flutter analyze` — no issues.
- `flutter test` — 234 passed.
- `python -m pytest` — 1016 passed.
- Targeted regression backend — 134 passed.
- Targeted regression Flutter — 88 passed.
- `git diff --check` — clean.
- Deno 2.8.3: `deno check` on call-openai, categorize-transactions,
  send-mfa-security-email — pass.
- `deno test --allow-env --allow-net supabase/functions/categorize-transactions/index_test.ts`
  — 11 passed.

## Final Signoff Checklist

- [x] Full backend tests pass.
- [x] Full Flutter tests pass.
- [x] Working tree clean (static pass date).
- [ ] Manual smoke completed on target device.
- [ ] `./scripts/verify_supabase_auth_email.sh` passes.
- [ ] Sign-up confirmation email verified on a real inbox.
- [ ] `/ready` checked in deployment environment.
- [ ] Supabase migrations applied.
- [ ] Edge Functions deployed.
- [ ] Plaid sandbox flow verified.
- [ ] Rex chat and voice verified on device.
- [ ] Known release limitations documented.

## Manual Smoke

Follow `docs/CLARITY_BETA_SMOKE_RUNBOOK.md`. Record outcomes in
`docs/CLARITY_BETA_SMOKE_RESULTS_2026_06_25.md`.
