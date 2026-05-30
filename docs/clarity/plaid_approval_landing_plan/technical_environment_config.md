# Clarity Landing Environment Configuration

Status: File 08 Phase 6 environment management approved for initial landing launch draft.

Purpose: define the safe environment configuration for the public Clarity landing site before deployment.

## Decision

Use `goclarity.app` as the launch domain unless a newer Clarity-specific domain is chosen before deployment.

Default site URL:

- `https://goclarity.app`

Environment example:

- `apps/web/.env.example`

## Public Environment Variables

Allowed public variable:

- `PUBLIC_SITE_URL`

Purpose:

- Sets Astro's `site` value.
- Controls canonical/static site URL generation.
- Controls hosted-form success redirect generation through `Astro.site`.

Launch value:

```bash
PUBLIC_SITE_URL=https://goclarity.app
```

Local default:

- If the variable is not set, the Astro config falls back to `https://goclarity.app`.

## Secret Environment Variables

No secret environment variables are required for the static landing launch.

Do not add these to `apps/web/.env`:

- Plaid client ID.
- Plaid secret.
- Supabase service-role key.
- Supabase database password.
- Grok API key.
- Google service account JSON.
- Deepgram API key.
- SMTP credentials.
- Private webhook secrets.

If a future serverless form endpoint needs a secret, it must be added during a separate reviewed phase and kept out of client-side bundles.

## Committed Files

Safe to commit:

- `apps/web/.env.example`
- Public placeholder values.
- Public support email.
- Public route/domain values.

Never commit:

- `apps/web/.env`
- `.env.production`
- `.env.local`
- Provider secrets.
- API keys.
- Webhook signing secrets.

The root `.gitignore` already excludes `.env` and `.env.*` while allowing `.env.example`.

## Local Setup

Recommended local setup:

```bash
cd apps/web
cp .env.example .env
npm install
npm run dev
```

The local `.env` file may keep the launch value or use another public preview URL.

## Deployment Setup

Deployment environment should set:

```bash
PUBLIC_SITE_URL=https://goclarity.app
```

If a preview deploy URL is used, the production deploy should still use the final public domain before Plaid review.

## Form Redirect Impact

The hosted-form-compatible implementation uses `Astro.site` for success redirects.

That means:

- `PUBLIC_SITE_URL=https://goclarity.app` redirects successful form submissions to `https://goclarity.app/form-success`.
- If the deployment provider uses preview URLs, test form redirects carefully before Plaid review.

## Acceptance Checklist

- `.env.example` exists for `apps/web`.
- Public and secret env values are clearly separated.
- No secrets are required or committed.
- `goclarity.app` replaces the old placeholder domain.
- README documents local setup and env usage.
- Deployment env value is documented.
