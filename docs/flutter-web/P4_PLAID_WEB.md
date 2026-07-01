# P4 — Plaid Link on Web

**Previous:** [P1_SPIKE_AND_BOOT.md](./P1_SPIKE_AND_BOOT.md), [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md)  
**Next:** [P5_VOICE_WEB.md](./P5_VOICE_WEB.md) or [P6_PWA_DEPLOY.md](./P6_PWA_DEPLOY.md)

## Objective

Connect bank accounts from browser with the same backend truth as mobile.

**Production context:** Clarity already uses **production Plaid** on rex-api and bank connect works on iOS/Android. P4 adds the web Link launcher only — no new Plaid environment, no duplicate exchange/sync path, no sandbox-only flow.

## Prerequisites

- P1 complete (CORS, auth)
- P2 complete (accounts screen layout)
- Production Plaid credentials already on rex-api (`PLAID_ENVIRONMENT=production`)
- **`PLAID_WEB_REDIRECT_URI`** set to `https://goclarity.app/app/` and registered in Plaid Dashboard **production** (separate from native `PLAID_REDIRECT_URI` used by iOS OAuth)

## Tasks

### 1. Backend — link token for web

Use existing `POST /plaid/link-token` with `platform: "web"`.

Verify in `plaid_api_client.py`:

- `redirect_uri` for web prefers `PLAID_WEB_REDIRECT_URI`, then falls back to `PLAID_REDIRECT_URI`
- iOS keeps using existing `PLAID_REDIRECT_URI` (do not change production mobile config)
- Register `PLAID_WEB_REDIRECT_URI` in Plaid Dashboard production

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

- [ ] Production Plaid connect completes on Chrome desktop (same institutions as mobile)
- [ ] Connected accounts appear in Accounts tab
- [ ] Dashboard reflects synced transactions/balances
- [ ] Login-required state shows correct recovery message
- [ ] rex-api test for web link token passes

## Deploy checklist (production)

1. Add `https://goclarity.app/app/` to Plaid Dashboard → **Production** → Allowed redirect URIs.
2. Set on rex-api: `PLAID_WEB_REDIRECT_URI=https://goclarity.app/app/`
3. Leave existing `PLAID_REDIRECT_URI` unchanged (native iOS OAuth).
4. Redeploy rex-api, then verify web connect in Chrome against production Plaid.

## Files likely touched

- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
- `apps/mobile/lib/features/plaid/application/web_plaid_link_launcher_web.dart` (new)
- `apps/mobile/lib/features/plaid/application/web_plaid_link_launcher_stub.dart` (new)
- `apps/mobile/lib/features/plaid/application/plaid_link_js.dart` (new)
- `apps/mobile/lib/features/plaid/application/web_plaid_link_parsing.dart` (new)
- `apps/mobile/web/index.html` (Plaid Link script)
- `apps/mobile/lib/core/platform/app_capabilities.dart`
- `services/rex-api/app/services/plaid_api_client.py`
- `services/rex-api/app/config.py` (`PLAID_WEB_REDIRECT_URI`)
- `services/rex-api/tests/test_plaid_routes.py`

## Out of scope (defer)

- Voice (P5)
- Production deploy (P6) — but redirect URI must be HTTPS-ready
