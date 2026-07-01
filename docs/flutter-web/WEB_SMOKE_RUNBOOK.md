# Clarity Web Smoke Runbook (P6)

Browser smoke pass for **`https://goclarity.app/app/`** before public launch.
Adapted from [`docs/CLARITY_BETA_SMOKE_RUNBOOK.md`](../CLARITY_BETA_SMOKE_RUNBOOK.md).

Automated tests (`flutter test`, `pytest`) are necessary but not sufficient.
This pass verifies trust-critical behavior that only shows up in a real browser:
auth redirects, Plaid OAuth return, streaming voice over WSS, PWA install, and
Rex truth boundaries.

## Gate rule (P0 — do not launch with any open)

- Rex claims a save, delete, or financial action succeeded when it did not.
- Rex guesses balances, transactions, merchants, budgets, or spending without reliable context.
- Voice reaches a dead-end with no recovery path.
- Delete confirmation succeeds in chat but the item remains in Knows active view.
- Recall labels chat history as saved memory.
- Sign-up confirmation email cannot be sent or confirmed.
- Landing **Sign in on web** does not reach a working login at `/app/`.

## Run metadata

| Field | Value |
|-------|-------|
| Tester | |
| Date/time | |
| Browser + version | Chrome / Edge recommended |
| OS | |
| URL | `https://goclarity.app/app/` |
| API base URL | `https://api.goclarity.app` |
| Test account | |
| Network | Wi-Fi / cellular |
| PWA installed? | yes / no |
| Notes | |

## Result legend

- `[ ] PASS`
- `[ ] FAIL`
- `[ ] BLOCKED`
- `[ ] NOT RUN`

For every fail or blocked item, record: scenario, steps, expected, actual, screenshot, severity (P0/P1/P2).

---

## P0: Landing → web app entry

- `[ ]` Open `https://goclarity.app/`
- `[ ]` Click **Sign in on web** → lands on `https://goclarity.app/app/` (login or app shell)
- `[ ]` Optional: `https://app.goclarity.app/` → 301 to `https://goclarity.app/app/`

## P0: Auth (Supabase)

Prerequisite: Supabase Site URL + redirect URLs include `https://goclarity.app` and `https://goclarity.app/app`.

- `[ ]` Sign in with email + password
- `[ ]` MFA flow (if enabled on account)
- `[ ]` Sign out and sign back in
- `[ ]` Password reset link opens `https://goclarity.app/auth/reset-password`
- `[ ]` New user sign-up → confirmation email → `https://goclarity.app/auth/confirmed` → sign in

## P0: Finance parity

- `[ ]` Dashboard loads balances and charts from same data as mobile
- `[ ]` Accounts list + account detail
- `[ ]` Budgets: view, create/edit (if applicable)
- `[ ]` Transactions: browse, search, filter by month
- `[ ]` Rex financial question uses real numbers (no invented balances)

## P0: Rex chat + Knows + goals

- `[ ]` Chat streams a reply
- `[ ]` Save a memory → appears in Knows → editable/deletable
- `[ ]` Recall question searches old chats; Rex labels chat history vs saved memory correctly
- `[ ]` Goals tab loads; Rex discusses goals without inventing progress

## P0: Plaid web (sandbox)

Prerequisite: `PLAID_WEB_REDIRECT_URI=https://goclarity.app/app/` on rex-api; redirect registered in Plaid dashboard.

- `[ ]` Connect bank from Accounts
- `[ ]` Plaid Link opens in browser; OAuth completes and returns to app
- `[ ]` Accounts sync; transactions appear on Dashboard

## P0: Streaming voice (HTTPS + WSS)

Prerequisite: mic permission on `goclarity.app`; WSS proxy on `api.goclarity.app/voice/stream`.

- `[ ]` Start voice from Rex chat — browser mic prompt
- `[ ]` Speak → transcript → Rex reply → audio plays
- `[ ]` Interrupt during Rex reply
- `[ ]` End session cleanly
- `[ ]` Profile → Voice usage updates after session (pull to refresh)
- `[ ]` Deny mic → clear error + Try again
- `[ ]` (Optional) Block WebSocket → REST `/voice/turn` fallback still works

Known limitation (not a bug): voice pauses when the tab is hidden; no background voice on web.

## P1: PWA install

- `[ ]` Chrome or Edge shows install affordance (or menu → Install Clarity)
- `[ ]` Installed app opens in standalone window at `/app/`
- `[ ]` Icons and theme color match dark Clarity branding (`#081827`)
- `[ ]` After deploy update: hard refresh or reinstall picks up new version (see cache notes below)

## P1: Adaptive shell (desktop width)

- `[ ]` Wide viewport: navigation rail visible
- `[ ]` Narrow viewport: bottom navigation
- `[ ]` Finance tabs readable at max content width

## Cache and service worker notes

Flutter web ships a service worker. During early rollout:

1. After deploy, open `/app/` and hard refresh once (`Ctrl+Shift+R` / `Cmd+Shift+R`).
2. If behavior looks stale, DevTools → Application → Service Workers → Unregister, then reload.
3. Installed PWA may need close + reopen or reinstall after major updates.

---

## Infrastructure checklist (ops — before smoke)

| Item | Verify |
|------|--------|
| Supabase Site URL | `https://goclarity.app` |
| Supabase redirect URLs | `https://goclarity.app/app/**`, `https://goclarity.app/auth/**` |
| rex-api CORS | `https://goclarity.app` in `CORS_ALLOWED_ORIGINS` |
| Plaid web redirect | `https://goclarity.app/app/` |
| Landing env | `PUBLIC_WEB_LOGIN_URL=https://goclarity.app/app` |
| WSS | `wss://api.goclarity.app/voice/stream` upgrades through proxy |
| Deploy | `./scripts/goclarity_web_deploy.sh` or nginx template in `deploy/templates/nginx-goclarity-web.conf` |

## Build commands (reference)

```bash
./scripts/flutter_web_release_build.sh
./scripts/web_release_build.sh
./scripts/flutter_web_stage_into_landing.sh
./scripts/goclarity_web_deploy.sh --skip-build   # after staging
```

Windows:

```powershell
.\scripts\flutter_web_release_build.ps1
.\scripts\flutter_web_stage_into_landing.ps1
```
