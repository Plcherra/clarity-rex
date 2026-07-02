# Cloudflare Pages deploy (goclarity.app)

Deploy the **combined** site: Astro landing at `/` + Flutter PWA at `/app/`.

**Important:** If the Pages project runs `npm run build` from Git on every push, it deploys
landing-only output and breaks `/app/` (marketing HTML or a stuck Flutter boot screen). Use
`goclarity_web_deploy` via Wrangler for production, or disable Git-connected builds on the
Pages project.

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
   - Account → Cloudflare Pages → **Edit**
   - Account → Account Settings → **Read**
   - User → User Details → **Read** (optional; fixes whoami email warning)

**Do not use** Access / Custom Pages permissions — that token will fail with `Authentication error [code: 10000]`.

After creating the token, verify:

```bash
export CLOUDFLARE_API_TOKEN="your-token"
npx wrangler@3 pages project list    # must succeed before deploy
```

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
- `https://goclarity.app/app/` — Flutter boot → login (not marketing HTML)
- `https://goclarity.app/app/passkeys_bundle.js` — `Content-Type: application/javascript` (not HTML)
- `https://goclarity.app/app/main.dart.js` — JavaScript (~5 MB)
- Hard refresh after deploy: `Ctrl+Shift+R`

Local dist check before deploy:

```bash
./scripts/verify_combined_web_dist.sh apps/web/dist
```

```powershell
.\scripts\verify_combined_web_dist.ps1 -DistDir apps\web\dist
```

---

## VPS: "Permission denied" (even with sudo)

**Do not use `sudo` for deploy.** Run as your normal user (`rex`):

```bash
whoami          # should be rex, not root
cd /opt/clarity/current
```

### A) Shell script not executable / `command not found`

Often Windows CRLF line endings on `.sh` files. Fix:

```bash
git pull
sed -i 's/\r$//' scripts/*.sh
chmod +x scripts/*.sh
bash scripts/goclarity_web_deploy.sh --skip-build
```

Always prefer `bash scripts/...` over `sudo ./scripts/...`.

### B) API token not visible to sudo

`sudo` drops environment variables. Either skip sudo, or pass the token explicitly:

```bash
export CLOUDFLARE_API_TOKEN="your-token"
./scripts/goclarity_web_deploy.sh --skip-build

# If you must use sudo (you usually shouldn't):
sudo -E env CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
  bash scripts/goclarity_web_deploy.sh --skip-build
```

### C) Cloudflare API "permission denied" (Wrangler auth)

This is **not** Linux sudo — your token lacks scope. Recreate using template **Edit Cloudflare Workers**, or add **Account → Cloudflare Pages → Edit**.

Test:

```bash
export CLOUDFLARE_API_TOKEN="your-token"
npx wrangler@3 whoami
npx wrangler@3 pages project list
```

### D) Files owned by root from past sudo runs

```bash
sudo chown -R rex:rex /opt/clarity/current
```

### E) VPS has no Flutter — build on Windows first

On Windows: `.\scripts\goclarity_web_deploy.ps1` (builds + deploys).

Or copy only `apps/web/dist` to the VPS, then:

```bash
ls apps/web/dist/app/index.html   # must exist
./scripts/goclarity_web_deploy.sh --skip-build
```

Paste the **exact error line** if none of the above match.

