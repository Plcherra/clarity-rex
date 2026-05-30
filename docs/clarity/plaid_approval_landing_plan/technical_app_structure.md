# Clarity Landing App Structure

Status: File 08 Phase 2 app folder structure approved for initial landing launch draft.

Purpose: define the isolated web app folder and routing structure for the public Clarity landing site.

## Decision

The landing site lives in:

- `apps/web`

This folder is separate from:

- `apps/mobile`
- `services/rex-api`
- `supabase`

## Folder Contract

Initial structure:

- `apps/web/package.json`
- `apps/web/astro.config.mjs`
- `apps/web/tsconfig.json`
- `apps/web/README.md`
- `apps/web/src/content/site.ts`
- `apps/web/src/layouts/BaseLayout.astro`
- `apps/web/src/pages/index.astro`
- `apps/web/src/pages/privacy.astro`
- `apps/web/src/pages/terms.astro`
- `apps/web/src/pages/security.astro`
- `apps/web/src/pages/data-deletion.astro`
- `apps/web/src/pages/contact.astro`

## Route Contract

Routes match `landing_site_route_map.md`:

- `/`
- `/privacy`
- `/terms`
- `/security`
- `/data-deletion`
- `/contact`

No authenticated routes exist in the landing app.

## Script Contract

Local commands:

- `npm run dev`
- `npm run build`
- `npm run preview`
- `npm run check`

The landing app should be run from `apps/web` until a root workspace is intentionally added.

## Isolation Rules

- Do not import Flutter/mobile code into `apps/web`.
- Do not import backend application code into `apps/web`.
- Do not store secrets in client-side source files.
- Do not place web output in `apps/mobile/web`.
- Do not add Plaid Link to the public web app in v1.

## Acceptance Checklist

- Web folder is isolated from mobile and backend modules.
- Route files exist for all required public pages.
- README explains local dev and build commands.
- Scripts are clear and local to `apps/web`.
- The structure supports a static-first launch.
