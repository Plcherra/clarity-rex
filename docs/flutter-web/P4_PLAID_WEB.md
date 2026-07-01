# P4 — Plaid Link on Web

**Previous:** [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md), [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md)  
**Next:** [P5_VOICE_WEB.md](./P5_VOICE_WEB.md) or [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md)

## Objective

Connect bank accounts from browser with the same backend truth as mobile.

## Prerequisites

- P1 complete (CORS, auth)
- P2 complete (accounts screen layout)
- Plaid sandbox/prod credentials on rex-api
- `PLAID_REDIRECT_URI` planned for `https://app.goclarity.app/...`

## Tasks

### 1. Backend — link token for web

Use existing `POST /plaid/link-token` with `platform: "web"`.

Verify in `plaid_api_client.py`:

- `redirect_uri` included when platform is not `android`
- Register redirect URI in Plaid Dashboard

Add/update test in `services/rex-api/tests/test_plaid_routes.py` for `platform=web`.

### 2. `WebPlaidLinkLauncher`

New implementation (sibling file if `plaid_link_service.dart` > 400 lines):

- Load Plaid Link JavaScript (official web integration)
- Open Link with token from rex-api
- Handle success / exit / error callbacks
- OAuth redirect return handling on web route

### 3. Platform router

In `PlaidLinkService`:

- Mobile: `NativePlaidLinkLauncher` (existing MethodChannel)
- Web: `WebPlaidLinkLauncher`
- Select via `AppCapabilities`

Update `_plaidLinkPlatform()` to return `web` on `kIsWeb`.

### 4. Token exchange and sync

Reuse existing post-Link flows:

- Public token exchange
- Account sync
- Dashboard refresh

### 5. Error and recovery UX

Preserve status messaging in:

- `plaid_account_header.dart`
- `plaid_account_status_pill.dart`
- Login-required / reconnect flows

Enable "Connect bank" on web when P4 ships (`AppCapabilities.supportsWebPlaidLink = true`).

## Exit criteria

- [ ] Plaid sandbox connect completes on Chrome desktop
- [ ] Connected accounts appear in Accounts tab
- [ ] Dashboard reflects synced transactions/balances
- [ ] Login-required state shows correct recovery message
- [ ] rex-api test for web link token passes

## Files likely touched

- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
- `apps/mobile/lib/features/plaid/application/web_plaid_link_launcher.dart` (new)
- `apps/mobile/lib/core/platform/app_capabilities.dart`
- `services/rex-api/app/services/plaid_api_client.py` (verify only)
- `services/rex-api/tests/test_plaid_routes.py`

## Out of scope (defer)

- Voice (P5)
- Production deploy (P6) — but redirect URI must be HTTPS-ready
