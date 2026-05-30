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

Recommended production target for the public landing site:

- Project name: `clarity-landing` or `goclarity`
- Production branch: `main`
- Root directory: `apps/web`
- Framework preset: Astro
- Build command: `npm run build`
- Build output directory: `dist`
- Node version: `22`
- Environment variable: `PUBLIC_SITE_URL=https://goclarity.app`

Connect the custom domain `goclarity.app` in Cloudflare Pages after the preview build passes.

## Content

Shared public copy and route metadata live in `src/content/site.ts`.

Keep legal/policy copy readable and reviewable. Extract only repeated content into shared constants.
