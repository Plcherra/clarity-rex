# Deployment Domain Checklist

Status: File 10 Phase 4 domain and HTTPS check complete with a deployment blocker.

## Summary

The Clarity web app is correctly configured to build canonical URLs for `https://rexpilot.com`, but the public domain is not yet ready for live smoke testing.

Current result:

- Cloudflare nameservers are configured.
- `rexpilot.com` does not currently resolve to a public A/CNAME record from this environment.
- `www.rexpilot.com` does not currently resolve to a public A/CNAME record from this environment.
- HTTPS cannot be verified until DNS points to the deployed static site.

## Checks Run

DNS checks:

```bash
dig +short rexpilot.com NS
dig +short rexpilot.com A
dig +short www.rexpilot.com A
dig @1.1.1.1 +short rexpilot.com A
dig @1.1.1.1 +short www.rexpilot.com A
dig @8.8.8.8 +short rexpilot.com A
dig @8.8.8.8 +short www.rexpilot.com A
```

Result:

- Nameservers returned:
  - `merlin.ns.cloudflare.com.`
  - `nova.ns.cloudflare.com.`
- No public A records returned for apex or `www`.

HTTPS checks:

```bash
curl -I -L --max-time 15 https://rexpilot.com
curl -I -L --max-time 15 https://www.rexpilot.com
```

Result:

- Both failed from this environment because the hostnames do not resolve yet.

## App Configuration Check

Configured production URL:

- `apps/web/astro.config.mjs` uses `process.env.PUBLIC_SITE_URL ?? 'https://rexpilot.com'`.
- `apps/web/.env.example` uses `PUBLIC_SITE_URL=https://rexpilot.com`.
- `scripts/web_release_build.sh` builds with `PUBLIC_SITE_URL=https://rexpilot.com` by default.
- `apps/web/src/content/site.ts` uses `siteUrl: 'https://rexpilot.com'`.

Generated build output confirms:

- Canonical URLs use `https://rexpilot.com`.
- Open Graph URLs use `https://rexpilot.com`.
- `robots.txt` points to `https://rexpilot.com/sitemap.xml`.
- `sitemap.xml` lists the expected `https://rexpilot.com` public routes.
- Form success redirects point to `https://rexpilot.com/form-success`.

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
10. Set production environment variable `PUBLIC_SITE_URL=https://rexpilot.com`.
11. Deploy the production build.
12. Attach custom domain `rexpilot.com` through the Cloudflare Pages custom-domain flow.
13. Optionally attach `www.rexpilot.com` and redirect it to the apex domain, or leave it unused for v1.

Do not add Plaid, Supabase, Grok, Google, Deepgram, service-role, or backend secrets to Cloudflare Pages for this static landing launch.

## Pass Criteria For Phase 5/6

After deployment, these checks must pass:

```bash
curl -I -L https://rexpilot.com
curl -I -L https://rexpilot.com/privacy
curl -I -L https://rexpilot.com/terms
curl -I -L https://rexpilot.com/security
curl -I -L https://rexpilot.com/data-deletion
curl -I -L https://rexpilot.com/contact
curl -I -L https://rexpilot.com/sitemap.xml
curl -I -L https://rexpilot.com/robots.txt
```

Expected:

- HTTPS works.
- Routes return 200.
- Canonical domain is `https://rexpilot.com`.
- No unexpected redirect loop.
- FormSubmit redirects use `https://rexpilot.com/form-success`.

## Acceptance Decision

File 10 Phase 4 passes as a domain-readiness check, but the domain is not ready for Plaid review yet.

The next required action is File 10 Phase 5 production deploy through Cloudflare Pages, including custom domain attachment and live DNS verification.
