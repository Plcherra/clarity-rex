# Cloudflare Pages deploy (goclarity.app)

Deploy the **combined** site: Astro landing at `/` + Flutter PWA at `/app/`.

## Quick commands

**Linux / VPS (Node 18):**

```bash
git pull
npx wrangler@3 login          # see auth section below
./scripts/goclarity_web_deploy.sh
```

**Windows:**

```powershell
npx wrangler@3 login
.\scripts\goclarity_web_deploy.ps1
```

Build only (no deploy):

```bash
./scripts/flutter_web_release_build.sh
./scripts/web_release_build.sh
./scripts/flutter_web_stage_into_landing.sh
./scripts/wrangler_pages_deploy.sh   # deploy dist only
```

---

## Wrangler auth (pick one)

### Option A — API token (recommended for VPS / CI)

Avoids browser OAuth and `localhost:8976` callback issues.

1. Cloudflare Dashboard → **My Profile** → **API Tokens** → **Create Token**
2. Use template **Edit Cloudflare Workers** (includes Pages deploy), or custom with:
   - Account → Cloudflare Pages → Edit
   - Account → Account Settings → Read
3. On the machine that deploys:

```bash
export CLOUDFLARE_API_TOKEN="your-token-here"
# optional if you have many accounts:
# export CLOUDFLARE_ACCOUNT_ID="your-account-id"

./scripts/goclarity_web_deploy.sh --skip-build   # or full build
```

Windows PowerShell:

```powershell
$env:CLOUDFLARE_API_TOKEN = "your-token-here"
.\scripts\goclarity_web_deploy.ps1 -SkipBuild
```

No `wrangler login` needed when the token is set.

### Option B — OAuth login (`wrangler login`)

**Must run on the same machine as the browser** that completes OAuth.

1. Open a **dedicated terminal** (not inside `flutter run`).
2. Run and **leave the terminal open** until you see “Successfully logged in”:

```bash
npx wrangler@3 login
```

3. Browser opens → authorize → redirect to `http://localhost:8976/oauth/callback`.

**If you see `ERR_CONNECTION_REFUSED` on localhost:8976:**

- The wrangler CLI is not listening (terminal closed, login cancelled, or wrong machine).
- You ran login on a **remote VPS** but the browser opened on your **PC** — use **Option A (API token)** on the VPS instead.
- Retry in a fresh terminal; disable VPN/firewall blocking localhost briefly.

**Node version:** Wrangler 4 needs Node 22+. This repo pins **`wrangler@3`** for Node 18 VPS (`scripts/wrangler_pages_deploy.sh`).

---

## VPS without Flutter

The rex-api VPS usually does **not** have Flutter. Build on Windows, copy `apps/web/dist`, deploy:

**Windows:**

```powershell
.\scripts\goclarity_web_deploy.ps1
# or build + rsync dist to VPS, then on VPS:
# ./scripts/goclarity_web_deploy.sh --skip-build
```

---

## Verify

- `https://goclarity.app/` — landing
- `https://goclarity.app/app/` — Flutter login / app (not landing HTML)
- Hard refresh after deploy: `Ctrl+Shift+R`
