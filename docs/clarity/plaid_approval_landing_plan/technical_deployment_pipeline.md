# Clarity Landing Deployment Pipeline

Status: File 08 Phase 7 deployment pipeline approved for initial landing launch draft.

Purpose: define the repeatable deployment path for the public Clarity landing site on `goclarity.app`.

## Decision

Use Cloudflare Pages as the primary deployment target for the static Astro landing site.

Why:

- `goclarity.app` is the new Clarity-first public domain and should be attached to Cloudflare Pages before Plaid review.
- The site is static-first and does not need a long-running server.
- Cloudflare Pages supports GitHub-connected preview/production deploys.
- Rollback is available through prior Pages deployments.
- Domain/DNS setup should be kept in Cloudflare once the new domain is added or delegated there.

Fallback:

- Static VPS/Nginx deployment from `apps/web/dist` is acceptable only if Cloudflare Pages is blocked.

## Production Domain

Primary domain:

- `https://goclarity.app`

Required environment:

```bash
PUBLIC_SITE_URL=https://goclarity.app
```

## Cloudflare Pages Settings

Recommended project settings:

- Project name: `clarity-landing` or `goclarity`
- Source: GitHub repository `Plcherra/clarity-rex`
- Production branch: `main`
- Root directory: `apps/web`
- Framework preset: Astro
- Build command: `npm run build`
- Build output directory: `dist`
- Node version: `22`
- Production environment variable: `PUBLIC_SITE_URL=https://goclarity.app`

Do not add Plaid, Supabase, Grok, Google, Deepgram, or service-role secrets to the Cloudflare Pages project for this static launch.

## Local Release Build

Run from the repository root:

```bash
./scripts/web_release_build.sh
```

The script:

- Installs dependencies with `npm ci` when `package-lock.json` exists.
- Builds with `PUBLIC_SITE_URL=https://goclarity.app` by default.
- Runs `npm audit`.
- Leaves output in `apps/web/dist`.

Override domain for previews:

```bash
PUBLIC_SITE_URL=https://preview.example.com ./scripts/web_release_build.sh
```

## Manual Cloudflare Deployment Flow

1. Push the branch to GitHub.
2. Create or open the Cloudflare Pages project.
3. Connect the GitHub repo.
4. Set root directory to `apps/web`.
5. Set build command to `npm run build`.
6. Set output directory to `dist`.
7. Set `PUBLIC_SITE_URL=https://goclarity.app`.
8. Deploy a preview.
9. Verify preview routes and forms.
10. Attach custom domain `goclarity.app`.
11. Run live smoke checks from File 10 before submitting to Plaid.

## DNS Requirements

In Cloudflare:

- `goclarity.app` should point to the Cloudflare Pages project through the Pages custom domain flow.
- Do not manually create conflicting A/CNAME records if Pages creates the required records.
- Keep HTTPS enabled.
- Keep redirects simple until final SEO review.

If using `www.goclarity.app`, choose one canonical domain in File 09/10 and redirect the other.

## Rollback

Preferred rollback:

1. Open Cloudflare Pages deployments.
2. Select the last known good deployment.
3. Use Cloudflare's rollback/redeploy action.
4. Smoke test `https://goclarity.app`.

Git rollback option:

```bash
git revert <bad_commit_sha>
git push
```

Then wait for Cloudflare Pages to deploy the revert.

## Static VPS/Nginx Fallback

Only use this if Cloudflare Pages is blocked.

Build locally or on the VPS:

```bash
PUBLIC_SITE_URL=https://goclarity.app npm --prefix apps/web run build
```

Serve `apps/web/dist` through Nginx as a static root for `goclarity.app`.

Do not mix the landing site static root with the Rex API reverse proxy. The public landing site should live at `goclarity.app`; the Rex API should live on the separate hostname `api.goclarity.app`.

For the API hostname:

- Create DNS record `api.goclarity.app` pointing to the VPS that runs `clarity-rex.service`.
- Configure the VPS reverse proxy with `server_name api.goclarity.app`.
- Issue/refresh TLS for `api.goclarity.app`.
- Verify `/ready` before shipping a mobile build that points to the new API hostname.

## Pre-Deploy Checklist

- `./scripts/web_release_build.sh` passes.
- `apps/web/dist` contains all public routes.
- `PUBLIC_SITE_URL` is `https://goclarity.app`.
- Form `_next` redirects point to `https://goclarity.app/form-success`.
- `clarity.rex@gmail.com` has verified the hosted form destination if needed.
- Privacy, Terms, Security, Data Deletion, and Contact links are present.
- No `.env` files are tracked.

## Acceptance Checklist

- Deployment target is Cloudflare Pages.
- Build command is documented.
- Env vars are documented.
- Domain setup is documented.
- Rollback path is documented.
- Local release-build script exists.
