# Clarity Landing Deployment Pipeline

Status: File 08 Phase 7 deployment pipeline approved for initial landing launch draft.

Purpose: define the repeatable deployment path for the public Clarity landing site on `rexpilot.com`.

## Decision

Use Cloudflare Pages as the primary deployment target for the static Astro landing site.

Why:

- `rexpilot.com` is already managed in Cloudflare.
- The site is static-first and does not need a long-running server.
- Cloudflare Pages supports GitHub-connected preview/production deploys.
- Rollback is available through prior Pages deployments.
- Domain/DNS setup stays close to the existing Cloudflare domain.

Fallback:

- Static VPS/Nginx deployment from `apps/web/dist` is acceptable only if Cloudflare Pages is blocked.

## Production Domain

Primary domain:

- `https://rexpilot.com`

Required environment:

```bash
PUBLIC_SITE_URL=https://rexpilot.com
```

## Cloudflare Pages Settings

Recommended project settings:

- Project name: `clarity-landing` or `rexpilot`
- Source: GitHub repository `Plcherra/clarity-rex`
- Production branch: `main`
- Root directory: `apps/web`
- Framework preset: Astro
- Build command: `npm run build`
- Build output directory: `dist`
- Node version: `22`
- Production environment variable: `PUBLIC_SITE_URL=https://rexpilot.com`

Do not add Plaid, Supabase, Grok, Google, Deepgram, or service-role secrets to the Cloudflare Pages project for this static launch.

## Local Release Build

Run from the repository root:

```bash
./scripts/web_release_build.sh
```

The script:

- Installs dependencies with `npm ci` when `package-lock.json` exists.
- Builds with `PUBLIC_SITE_URL=https://rexpilot.com` by default.
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
7. Set `PUBLIC_SITE_URL=https://rexpilot.com`.
8. Deploy a preview.
9. Verify preview routes and forms.
10. Attach custom domain `rexpilot.com`.
11. Run live smoke checks from File 10 before submitting to Plaid.

## DNS Requirements

In Cloudflare:

- `rexpilot.com` should point to the Cloudflare Pages project through the Pages custom domain flow.
- Do not manually create conflicting A/CNAME records if Pages creates the required records.
- Keep HTTPS enabled.
- Keep redirects simple until final SEO review.

If using `www.rexpilot.com`, choose one canonical domain in File 09/10 and redirect the other.

## Rollback

Preferred rollback:

1. Open Cloudflare Pages deployments.
2. Select the last known good deployment.
3. Use Cloudflare's rollback/redeploy action.
4. Smoke test `https://rexpilot.com`.

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
PUBLIC_SITE_URL=https://rexpilot.com npm --prefix apps/web run build
```

Serve `apps/web/dist` through Nginx as a static root for `rexpilot.com`.

Do not mix the landing site static root with the Rex API reverse proxy. The API should remain on `api.rexpilot.com` or another explicit API hostname.

## Pre-Deploy Checklist

- `./scripts/web_release_build.sh` passes.
- `apps/web/dist` contains all public routes.
- `PUBLIC_SITE_URL` is `https://rexpilot.com`.
- Form `_next` redirects point to `https://rexpilot.com/form-success`.
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
