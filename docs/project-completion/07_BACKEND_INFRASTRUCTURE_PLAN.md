# Backend And Infrastructure Completion Plan

## Goal

Make the Rex API backend, Supabase schema, Plaid sync, voice infrastructure, and deployment setup reliable, understandable, and easy to operate.

## Current State

- FastAPI is the backend for Rex chat, voice, Plaid, memory, goals, and actions.
- Supabase is the database and auth provider.
- Plaid sync and token storage are backend-owned.
- Grok is used for Rex.
- Deepgram and Google TTS support voice.
- Supabase Edge Functions support CSV AI categorization and MFA email.
- Backend services folder is large and flat.

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

### 3. Rex Brain Production Guard

- Keep production on:
  - `ChatService`
  - `ChatTurnOrchestrator`
  - `SimpleRexBrain`
- Keep experimental Rex Brain routing disabled for MVP.
- Move experimental modules to a clearly marked package or archive if they continue to confuse production work.
- Keep one production brain for chat and voice.

### 4. Supabase Schema Hygiene

- Treat root `supabase/migrations` as canonical.
- Remove or clearly mark stale standalone schemas.
- Clean env/docs references to archived tables:
  - memory confirmations.
  - memory candidates.
  - old review tables.
- Confirm RLS policies protect all user-scoped data.

### 5. Plaid Infrastructure

- Confirm service role is used only where needed for backend-owned Plaid persistence.
- Verify webhook signature checking.
- Verify item disconnect and degraded status updates.
- Add operational logs that are useful but do not leak sensitive tokens.

### 6. Edge Functions

- Confirm canonical AI categorization path.
- Remove or document unused `call-openai`.
- Keep JWT verification enabled.
- Confirm Edge Function secrets are not duplicated into Flutter config.

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

### 8. Deployment Runbook

- Keep one canonical VPS restart command.
- Keep one canonical release build command for mobile.
- Document required env vars.
- Document smoke checks after deploy.

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

## Manual Ops Smoke

1. Restart backend.
2. Check `/ready`.
3. Send authenticated chat request.
4. Send streaming chat request.
5. Create Plaid link token in sandbox.
6. Run a voice turn if voice env is configured.
7. Confirm logs show useful non-sensitive diagnostics.
