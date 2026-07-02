# Clarity Web

Public static-first landing site for Clarity's Plaid approval and trust surface.

This app is intentionally separate from:

- `apps/mobile`, which contains the Flutter mobile app.
- `services/rex-api`, which contains the Rex backend API.

## Scope

Build now:

- Landing page
- Privacy Policy
- Terms of Service
- Security and Data Handling
- Data Deletion
- Contact
- Waitlist/contact shell

Deferred:

- Authenticated web dashboard
- Plaid Link in browser
- Rex chat or voice in browser
- Billing or admin tools

## Local Development

```bash
cd apps/web
npm install
cp .env.example .env
npm run dev
```

## Environment

`PUBLIC_SITE_URL` controls canonical URLs and hosted-form redirect URLs.

Default launch value:

```bash
PUBLIC_SITE_URL=https://goclarity.app
```

This landing app does not need private secrets for the static launch. Do not place Plaid,
Supabase, Grok, Google, Deepgram, or service-role credentials in `apps/web/.env`.

## Build

```bash
cd apps/web
npm run build
npm run preview
```

## Release Build

```bash
cd apps/web
PUBLIC_SITE_URL=https://goclarity.app npm run build
```

Or from the repository root:

```bash
./scripts/web_release_build.sh
```

## Cloudflare Pages

**Do not use Git-connected `npm run build` as the production deploy for `goclarity.app`.**
That build is landing-only and removes `/app/` (Flutter login). A previous deploy also used
`/app/* → /app/index.html` rewrites that served marketing HTML in place of missing Flutter assets,
which left the boot screen stuck on "Loading Clarity…".

Production deploy (landing + Flutter PWA at `/app/`):

```powershell
# Windows (builds Flutter + Astro, stages, verifies, deploys)
.\scripts\goclarity_web_deploy.ps1
```

```bash
# Linux / VPS
./scripts/goclarity_web_deploy.sh
```

If the Cloudflare Pages project is connected to GitHub, either **disconnect automatic builds**
or set the production branch to none so only `wrangler pages deploy` publishes. Manual deploy
uses project `clarity-landing`, branch `main`, dist `apps/web/dist`.

Verify after deploy:

- `https://goclarity.app/app/` — Flutter boot → login (not marketing HTML)
- `https://goclarity.app/app/passkeys_bundle.js` — JavaScript, not HTML
- `https://goclarity.app/app/main.dart.js` — JavaScript (~5 MB)

**Cloudflare zone settings:** disable **Speed → Optimization → Auto Minify → JavaScript**
for `goclarity.app`. Minifying Flutter's already-minified `main.dart.js` can leave the boot
screen stuck on "Loading Clarity…". Script tags use `data-cfasync="false"` to opt out of
Rocket Loader; Auto Minify must be off in the dashboard.

See `docs/flutter-web/CLOUDFLARE_DEPLOY.md` for auth and VPS notes.

## Content

Shared public copy and route metadata live in `src/content/site.ts`.

Keep legal/policy copy readable and reviewable. Extract only repeated content into shared constants.
