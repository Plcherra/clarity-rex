# Backend And Infrastructure Completion Plan

## Goal

Make the Rex API backend, Supabase schema, Plaid sync, voice infrastructure, and deployment setup reliable, understandable, and easy to operate.

## Status

**MVP code/static complete.** Production startup validation, deploy runbook, schema/env cleanup, and guardrail tests are in place. Service subpackage moves and oversized module splits remain deferred.

## Current State

- FastAPI is the backend for Rex chat, voice, Plaid, memory, goals, and actions.
- Supabase is the database and auth provider.
- Plaid sync and token storage are backend-owned.
- Grok is used for Rex.
- Deepgram and Google TTS support voice.
- Supabase Edge Functions support CSV AI categorization and MFA email.
- Backend services folder is large and flat (splits deferred).

## Work Plan

### 1. Readiness And Configuration

- Confirm `/ready` reports:
  - Grok.
  - Supabase.
  - Rex Brain mode.
  - Plaid.
  - Deepgram.
  - Google TTS.
  - Timezone.
- Make production env defaults explicit.
- Fail loudly on missing required release config.
- Keep dev fallback auth disabled in production.
- Done (code):
  - `/ready` reports all listed checks (config-based, not live probes).
  - Production startup fails when required release config is missing or experimental Rex Brain routing is enabled.
  - Dev auth fallback returns 503 in production when Supabase is not configured.

### 2. Backend Service Organization

Move toward subpackages after behavior is stable:

- `services/brain`
- `services/recall`
- `services/memory`
- `services/voice`
- `services/plaid`
- `services/plans`
- `services/accountability`
- `services/usage`

Do this incrementally. Avoid large move-only commits mixed with behavior changes.

**Deferred** until post-MVP.

### 3. Rex Brain Production Guard

- Keep production on:
  - `ChatService`
  - `ChatTurnOrchestrator`
  - `SimpleRexBrain`
- Keep experimental Rex Brain routing disabled for MVP.
- Move experimental modules to a clearly marked package or archive if they continue to confuse production work.
- Keep one production brain for chat and voice.
- Done (code):
  - Production path wired and tested.
  - Experimental Rex Brain routing env flags and router removed from launch path.
  - Experimental module relocation deferred.

### 4. Supabase Schema Hygiene

- Treat root `supabase/migrations` as canonical.
- Remove or clearly mark stale standalone schemas.
- Clean env/docs references to archived tables:
  - memory confirmations.
  - memory candidates.
  - old review tables.
- Confirm RLS policies protect all user-scoped data.
- Done (code/docs):
  - `services/rex-api/supabase_schema.sql` marked stale.
  - `SUPABASE_MEMORY_CANDIDATES_TABLE` removed from env examples.
- Deferred:
  - Full RLS audit pass.

### 5. Plaid Infrastructure

- Confirm service role is used only where needed for backend-owned Plaid persistence.
- Verify webhook signature checking.
- Verify item disconnect and degraded status updates.
- Add operational logs that are useful but do not leak sensitive tokens.
- Done (existing):
  - Webhook verification, disconnect, degraded status, and tests already implemented.
  - Plaid env vars added to production env template and deploy runbook.

### 6. Edge Functions

- Confirm canonical AI categorization path.
- Remove or document unused `call-openai`.
- Keep JWT verification enabled.
- Confirm Edge Function secrets are not duplicated into Flutter config.
- Done (code/docs):
  - `categorize-transactions` is canonical.
  - `call-openai` marked deprecated in function source.
  - JWT verification enabled in `supabase/config.toml`.
- Deferred:
  - Remove legacy `call-openai` deployment and dead Flutter client method.

### 7. Oversized Backend Modules

Priority splits:

- `memory_correction_service.py`
- `chat_recall_search.py`
- `person_memory_materializer.py`
- `voice_stream_session.py`
- `memory_turn_direct_helpers.py`
- `chat_recall_excerpts.py`
- `entity_merge_service.py`
- `memory_discipline_service.py`
- `memory_reference_resolver.py`

Each split should preserve tests and public behavior.

**Deferred** until post-MVP.

### 8. Deployment Runbook

- Keep one canonical VPS restart command.
- Keep one canonical release build command for mobile.
- Document required env vars.
- Document smoke checks after deploy.
- Done:
  - `docs/BACKEND_DEPLOY_RUNBOOK.md`
  - `scripts/vps_restart_rex_api.sh`
  - README link updated.

## Acceptance Criteria

- `/ready` accurately reports production health.
- Production code path cannot accidentally use experimental Rex Brain routing.
- Supabase schema docs match migrations.
- Plaid, voice, and Rex env dependencies are clear.
- Backend services are split enough to debug safely.

## Suggested Tests

- Backend full test suite.
- Plaid route/sync/webhook tests.
- Supabase auth tests.
- Voice route/stream tests.
- Chat service and Rex Brain tests.
- Memory and recall tests.

## Verification Log

- `python -m pytest tests/test_production_config.py tests/test_supabase_auth.py tests/test_readiness.py tests/test_chat_service_rex_brain.py tests/test_plaid_webhook_verifier.py tests/test_plaid_sync_service.py -q`
  - 41 tests passed.

## Deferred

- Live dependency probes in `/ready` (Grok/Supabase ping).
- Experimental Rex Brain module relocation to subpackage.
- Oversized service file splits.
- Remove legacy `call-openai` Edge Function.
- Manual ops smoke on VPS (restart → `/ready` → chat → voice).

## Manual Ops Smoke

1. Restart backend.
2. Check `/ready`.
3. Send authenticated chat request.
4. Send streaming chat request.
5. Create Plaid link token in sandbox.
6. Run a voice turn if voice env is configured.
7. Confirm logs show useful non-sensitive diagnostics.
