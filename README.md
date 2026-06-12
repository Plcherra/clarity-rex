# Clarity

Clarity is the merged app for the Clarity financial dashboard and Rex AI assistant.

## Repository Layout

```text
apps/mobile        Flutter app, based on the original Clarity app
services/rex-api   FastAPI backend, based on the original Rex backend
supabase           Shared Supabase migrations and Edge Functions
docs               Project documentation and migration notes
scripts            Local development helper scripts
```

## Current Merge Status

Phase 1 of `MERGE_PLAN.md` is complete:

- Clarity Flutter app copied into `apps/mobile`.
- Clarity Supabase migrations and functions copied into root `supabase`.
- Rex FastAPI backend copied into `services/rex-api`.
- Rex backend tests copied into `services/rex-api/tests`.

Supabase data has intentionally been reset for a clean project start. Treat the migrations in this repository as the source of truth for rebuilding the database.

Phase 2 is complete:

- Added `supabase/migrations/000010_create_rex_assistant_tables.sql`.
- Added user-scoped Rex assistant tables.
- Added `user_id` to Rex conversations, messages, memory, entities, plans, commitments, and voice turns.
- Added same-user foreign keys where Rex records reference each other.
- Added RLS policies requiring `auth.uid() = user_id`.

Phase 3 is complete:

- Added Supabase access-token validation to the Rex FastAPI service.
- Secured assistant HTTP routes behind authenticated Supabase users when Supabase auth is configured.
- Added websocket token validation for `/voice/stream`.
- Rex memory service now receives the authenticated user id.
- Supabase REST calls use the user's access token with the anon key when available.
- Rex memory reads, updates, and deletes are scoped with `user_id`.
- Rex memory inserts attach `user_id`.

Phase 4 is complete:

- Protected memory write paths from client-supplied `user_id`, `id`, and timestamp fields.
- Preserved authenticated `user_id` ownership on every Supabase-backed insert.
- Confirmed memory reads, updates, deletes, retrieval, candidates, corrections, entities, rules, plans, commitments, accountability, and voice paths run through user-scoped persistence.
- Fixed structured memory archive operations to return updated records consistently.
- Added test coverage for untrusted `user_id` insert/update attempts.

Phase 5 is complete:

- Merged Rex Flutter chat, voice, memory, and accountability modules into `apps/mobile/lib/rex/`.
- Added shared Rex configuration under `apps/mobile/lib/core/rex/`.
- Added Riverpod to the Clarity Flutter app for the isolated Assistant feature.
- Added an Assistant tab to the Clarity shell.
- Updated Flutter dependencies for Rex chat, voice, generated models, HTTP, and audio support.
- Added mobile voice permissions and the Android foreground voice service bridge.

Phase 6 is complete:

- Added `RexAuthHeaders` to read the active Supabase session access token.
- Added `RexApiClient` to centralize Rex base URL handling, authenticated HTTP requests, JSON requests, multipart uploads, and websocket URLs.
- Updated Assistant chat, conversation, memory, accountability, cloud voice, and streaming voice clients to use authenticated Rex requests.
- Added websocket token passing through `access_token` for `/voice/stream`.
- Added focused Flutter tests for authenticated Rex HTTP and websocket URL behavior.

Phase 7 is complete:

- Added a native Clarity Assistant screen with Chat, Voice, Memory, and Goals sections.
- Replaced the bottom-nav Assistant destination's raw chat screen with the new Assistant section shell.
- Made Rex chat, voice, memory, and accountability pages embeddable inside the Assistant screen.
- Kept conversation history accessible from the Assistant app bar.
- Updated the chat empty state prompts for Clarity's financial assistant context.
- Added a widget test proving the Assistant tab exposes all four sections.

Phase 8 is complete:

- Added an Assistant financial context service that builds a unified Clarity financial context.
- Includes cash flow, monthly spend, income, available amount, budget totals, top categories, month-over-month category increases, accounts, categories, budgets, and transaction records.
- Includes transaction IDs, account names, category names, merchants, descriptions, dates, amounts, import metadata, and balances where available.
- Sends the full Clarity context with Rex chat, streaming chat, cloud voice turns, and streaming voice sessions.
- Added Rex backend support for `financial_context` in chat, voice turn, and voice stream flows.
- Added prompt rendering so Rex treats Clarity and Rex as one product and can reason over specific financial records.
- Added an `available_controls` manifest for transaction, account, category, and budget operations.
- Added authenticated `/clarity/actions` control execution for confirmed transaction, account, category, and budget mutations.
- Added the Assistant action loop: Rex can propose a hidden structured Clarity action, Flutter renders a confirmation card, confirmation calls `/clarity/actions`, and the UI only reports success after the backend returns an applied result.

## Next Phase

Phase 9 is testing and validation across real Supabase users, including user isolation, voice streaming, and memory persistence with financial context enabled.

## Deployment Preparation

Before touching the VPS, run:

```sh
./scripts/predeploy_check.sh
```

The deployment guide, systemd template, nginx template, and production env template are in:

```text
docs/deployment.md
deploy/templates/
```
