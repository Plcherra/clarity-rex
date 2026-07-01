# P6 — PWA Packaging, Deploy, and Production Hardening

**Previous:** P1–P5 exit criteria all met  
**Next:** [P7_NATIVE_DESKTOP.md](./P7_NATIVE_DESKTOP.md) (optional)

## Objective

Public launch at **`goclarity.app/app/`** as an installable PWA with full parity smoke pass.

## Prerequisites

- P1–P5 complete
- Domain `goclarity.app` DNS on Cloudflare (landing + `/app/` path for Flutter)
- Optional: `app.goclarity.app` → 301 redirect to `goclarity.app/app/`
- Cloudflare Pages or VPS nginx slot for Flutter web build

## Tasks

### 1. PWA assets

Update `apps/mobile/web/manifest.json`:

- `name` / `short_name`: Clarity
- `theme_color` / `background_color`: `#081827` (dark)
- Icons from `assets/brand/clarity_app_icon.png` (192, 512, maskable)
- `display`: standalone
- `start_url`: `/`
- Description matching product copy

Update `apps/mobile/web/index.html`:

- Meta theme-color, description, apple-touch-icon
- Title: Clarity

### 2. Release build script

`scripts/flutter_web_release_build.sh`:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REX_BACKEND_URL=https://api.goclarity.app \
  --dart-define=REX_CLOUD_VOICE_ENABLED=true \
  --dart-define=REX_STREAMING_VOICE_ENABLED=true
```

Document in `apps/mobile/README.md` (short section, not a new master doc).

### 3. Deploy

Target: **`goclarity.app/app/`** serving `apps/mobile/build/web/` (build with `--base-href=/app/`)

Options:

- Cloudflare Pages: Astro at site root, Flutter at `/app/` path (path rules or second project)
- VPS nginx: Astro static at `/`, Flutter static at `/app/`

Legacy redirect: `app.goclarity.app` → `https://goclarity.app/app/`

### 4. Infrastructure checklist

- [ ] Supabase: Site URL + redirect URLs include `https://goclarity.app` and `https://goclarity.app/app`
- [ ] rex-api: `CORS_ALLOWED_ORIGINS` includes `https://goclarity.app`
- [ ] Plaid: redirect URI registered for web OAuth
- [ ] Landing: `PUBLIC_WEB_LOGIN_URL=https://goclarity.app/app` in Cloudflare env for `apps/web`
- [ ] WSS: `api.goclarity.app` proxies WebSocket for voice

### 5. QA — web smoke runbook

Adapt `docs/CLARITY_BETA_SMOKE_RUNBOOK.md` for browser:

| Path | Verify |
|------|--------|
| Auth | Login, MFA, logout |
| Finance | Dashboard, accounts, budgets, transactions |
| Rex | Chat stream, Knows CRUD, goals |
| Plaid | Connect + sync (sandbox) |
| Voice | Full streaming session |
| PWA | Install prompt, standalone launch |

### 6. Cache and updates

- Verify service worker behavior after deploy
- Document hard-refresh / cache-bust if needed for users during early rollout

## Exit criteria

- [ ] Installable PWA on Chrome and Edge desktop
- [ ] Full parity smoke pass documented
- [ ] `goclarity.app` "Sign in on web" lands on working login
- [ ] App Store / Play Store CTAs unchanged; web path live

## Files likely touched

- `apps/mobile/web/manifest.json`
- `apps/mobile/web/index.html`
- `scripts/flutter_web_release_build.sh` (new)
- Deploy config (Cloudflare / nginx — outside repo or in `deploy/`)

## Out of scope (defer)

- Native macOS/Windows builds (P7)
- App Store web wrapper
