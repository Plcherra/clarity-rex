# Deployment Domain Checklist

Status: File 10 Phase 4 domain and HTTPS check complete with a deployment blocker.

## Summary

The Clarity web app is correctly configured to build canonical URLs for `https://goclarity.app`, but the public domain is not yet ready for live smoke testing.

Current result for `goclarity.app`:

- GoDaddy nameservers are currently configured.
- `goclarity.app` resolves to GoDaddy parking A records from this environment.
- `www.goclarity.app` resolves through the apex domain and also reaches GoDaddy parking.
- HTTPS for the Clarity landing site cannot be verified until DNS points to the deployed static site.

## Checks Run

DNS checks:

```bash
dig +short goclarity.app NS
dig +short goclarity.app A
dig +short www.goclarity.app A
dig @1.1.1.1 +short goclarity.app A
dig @1.1.1.1 +short www.goclarity.app A
dig @8.8.8.8 +short goclarity.app A
dig @8.8.8.8 +short www.goclarity.app A
```

Result:

- Nameservers returned:
  - `ns59.domaincontrol.com.`
  - `ns60.domaincontrol.com.`
- A records returned:
  - `76.223.105.230`
  - `13.248.243.5`
- `www` currently resolves through `goclarity.app`.

HTTPS checks:

```bash
curl -I -L --max-time 15 https://goclarity.app
curl -I -L --max-time 15 https://www.goclarity.app
```

Result:

- The domain is resolvable, but it is not yet attached to the Clarity Cloudflare Pages deployment.

## App Configuration Check

Configured production URL:

- `apps/web/astro.config.mjs` uses `process.env.PUBLIC_SITE_URL ?? 'https://goclarity.app'`.
- `apps/web/.env.example` uses `PUBLIC_SITE_URL=https://goclarity.app`.
- `scripts/web_release_build.sh` builds with `PUBLIC_SITE_URL=https://goclarity.app` by default.
- `apps/web/src/content/site.ts` uses `siteUrl: 'https://goclarity.app'`.

Generated build output confirms:

- Canonical URLs use `https://goclarity.app`.
- Open Graph URLs use `https://goclarity.app`.
- `robots.txt` points to `https://goclarity.app/sitemap.xml`.
- `sitemap.xml` lists the expected `https://goclarity.app` public routes.
- Form success redirects point to `https://goclarity.app/form-success`.

## Required Cloudflare Pages Action

Before File 10 Phase 5 can pass, configure the production deployment:

1. Push the latest branch to GitHub.
2. In Cloudflare Pages, create/open the Clarity landing project.
3. Connect repository `Plcherra/clarity-rex`.
4. Set production branch to `main`.
5. Set root directory to `apps/web`.
6. Set framework preset to Astro.
7. Set build command to `npm run build`.
8. Set output directory to `dist`.
9. Set Node version to `22`.
10. Set production environment variable `PUBLIC_SITE_URL=https://goclarity.app`.
11. Deploy the production build.
12. Move DNS management to Cloudflare or create the Cloudflare Pages-required records in the current DNS provider.
13. Attach custom domain `goclarity.app` through the Cloudflare Pages custom-domain flow.
14. Optionally attach `www.goclarity.app` and redirect it to the apex domain, or leave it unused for v1.

If Cloudflare imported the GoDaddy parking records, remove the two apex `A` records that point to `13.248.243.5` and `76.223.105.230` before connecting the Pages custom domain. Those records serve GoDaddy parking, not Clarity.

For the backend API, create a separate DNS record:

- Type: `A`
- Name: `api`
- Content: Clarity VPS public IPv4 address
- Proxy: optional, but keep websocket support in mind for voice streaming

Then configure Nginx/TLS on the VPS for `api.goclarity.app`.

Do not add Plaid, Supabase, Grok, Google, Deepgram, service-role, or backend secrets to Cloudflare Pages for this static landing launch.

## Pass Criteria For Phase 5/6

After deployment, these checks must pass:

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
- Routes return 200.
- Canonical domain is `https://goclarity.app`.
- No unexpected redirect loop.
- FormSubmit redirects use `https://goclarity.app/form-success`.

## Acceptance Decision

File 10 Phase 4 passes as a domain-readiness check, but the domain is not ready for Plaid review yet.

The next required action is File 10 Phase 5 production deploy through Cloudflare Pages, including custom domain attachment and live DNS verification.
