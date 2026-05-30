# Production Deployment Notes

Status: File 10 Phase 5 pre-deployment package complete; production deployment is blocked until the latest changes are pushed and Cloudflare Pages is connected or Wrangler is authenticated.

## Current Deployment State

Production deployment has not been completed from this environment.

Reasons:

- The landing page changes are currently uncommitted locally.
- Cloudflare Pages Git deployments require the latest changes to be committed and pushed to `main`.
- No Cloudflare API token or Wrangler authenticated session is available in this shell.
- `goclarity.app` currently resolves to GoDaddy parking, not to a public Pages deployment.

## Build Status

Local production build passed with:

```bash
./scripts/web_release_build.sh
```

Build output:

- `apps/web/dist`

NPM audit result:

- `0 vulnerabilities`

## Recommended Production Deployment Path

Use Cloudflare Pages connected to GitHub.

Cloudflare Pages settings:

- Project name: `clarity-landing` or `goclarity`
- Repository: `Plcherra/clarity-rex`
- Production branch: `main`
- Root directory: `apps/web`
- Framework preset: Astro
- Build command: `npm run build`
- Build output directory: `dist`
- Node version: `22`
- Production environment variable: `PUBLIC_SITE_URL=https://goclarity.app`

Required Git steps before Cloudflare Pages can deploy the current work:

```bash
git add apps/web docs/clarity/plaid_approval_landing_plan scripts/web_cloudflare_pages_deploy.sh
git commit -m "Prepare Clarity landing site for production deploy"
git push
```

Then use Cloudflare Pages to deploy from `main` and attach the custom domain `goclarity.app`.

## Direct Wrangler Deployment Option

If you prefer direct upload instead of Git-connected Pages, authenticate Wrangler first:

```bash
npx wrangler login
```

Then run:

```bash
CLOUDFLARE_PAGES_PROJECT=clarity-landing ./scripts/web_cloudflare_pages_deploy.sh
```

If the Cloudflare Pages project has a different name, replace `clarity-landing` with the real project name.

## Domain Requirement

After the Cloudflare Pages deploy succeeds:

1. Add or delegate `goclarity.app` to Cloudflare, or configure the current DNS provider with the records Cloudflare Pages requires.
2. Attach custom domain `goclarity.app`.
3. Let Cloudflare create the required DNS records through the Pages custom-domain flow when the domain is managed there.
4. Keep HTTPS enabled.
5. Decide whether `www.goclarity.app` should redirect to `goclarity.app` or remain unused for v1.

The backend API is separate from the landing site:

1. Create `api.goclarity.app` in DNS, pointing to the Clarity VPS.
2. Configure Nginx on the VPS with `server_name api.goclarity.app`.
3. Issue TLS for `api.goclarity.app`.
4. Smoke test `https://api.goclarity.app/ready`.
5. Build the mobile release with `REX_BACKEND_URL=https://api.goclarity.app`.

## Verification Commands After Deploy

Run these after Cloudflare Pages reports the custom domain is active:

```bash
curl -I -L https://goclarity.app
curl -I -L https://goclarity.app/privacy
curl -I -L https://goclarity.app/terms
curl -I -L https://goclarity.app/security
curl -I -L https://goclarity.app/data-deletion
curl -I -L https://goclarity.app/contact
curl -I -L https://goclarity.app/sitemap.xml
curl -I -L https://goclarity.app/robots.txt
```

Expected:

- HTTPS works.
- All public routes return 200.
- No redirect loop.
- Canonical URLs use `https://goclarity.app`.

## FormSubmit Production Requirement

FormSubmit cannot be fully verified until the live site is deployed.

After deployment:

- Submit one safe waitlist test.
- Submit one safe contact test.
- Check `clarity.rex@gmail.com` inbox and spam.
- Confirm any FormSubmit activation email if prompted.
- Submit again after activation if needed.
- Confirm redirect to `https://goclarity.app/form-success`.

## Acceptance Decision

File 10 Phase 5 cannot be marked as fully deployed yet because production DNS/Cloudflare Pages is not live.

The pre-deployment package is ready. The next action is to commit/push these changes and complete the Cloudflare Pages deployment in the Cloudflare dashboard or through authenticated Wrangler.
