# Clarity + Rex Merge Plan

## Project Goal

Merge Rex, the AI voice assistant with memory, into Clarity, the financial dashboard, as the main intelligent assistant feature.

The final product should be a single app called **Clarity** where users can manage their finances and interact with Rex as a personalized assistant for financial insight, planning, memory, goals, and voice-based conversations.

## Architecture Decision

Clarity is the main app and owner of authentication, user profiles, financial data, dashboard workflows, accounts, transactions, budgets, categories, and Supabase integration.

Rex becomes the AI service inside Clarity:

- FastAPI backend for AI orchestration, memory, chat, goals, accountability, voice transcription, and text-to-speech.
- Flutter feature module inside the Clarity app for assistant UI, chat, voice, memory review, and goals.

This keeps the existing Clarity backend and data model intact while embedding Rex as a first-class intelligent assistant feature.

## Current Projects

- Clarity: `/Users/pedromartins/Documents/clarity`
- Rex: `/Users/pedromartins/Documents/rex`
- New merged repository: `https://github.com/Plcherra/clarity-rex`

## Recommended Final Structure

```text
clarity-rex/
  apps/
    mobile/                  # Flutter app (from Clarity)
      lib/
        app/
        core/
        features/
          auth/
          onboarding/
          shell/
          dashboard/
          accounts/
          transactions/
          budgets/
          categories/
          assistant/          # Rex Flutter feature lives here
            chat/
            voice/
            memory/
            goals/
            accountability/
      ios/
      android/
      pubspec.yaml

  services/
    rex-api/                 # FastAPI backend (from Rex)
      app/
        main.py
        config.py
        dependencies.py
        auth/
        routes/
        services/
        models/
      scripts/
      tests/
      requirements.txt
      .env.example

  supabase/
    migrations/
    functions/

  docs/
    architecture.md

  scripts/
    dev_mobile.sh
    dev_rex_api.sh

  MERGE_PLAN.md
  README.md
```

---

## Guiding Principles

1. **Clarity remains the source of truth for auth and financial data.**
2. **Rex must be fully user-scoped before production use.**
3. **No Rex memory table should contain global, shared, or anonymous memory.**
4. **The Flutter app should feel like one product, not two apps stitched together.**
5. **Rex should operate as part of Clarity, with user-scoped access to Clarity financial data and confirmed controls.**
6. **The merge should happen in phases with tests after each risky boundary.**

---

## 10-Phase Merge Plan

### Phase 1: Project Setup & Monorepo Structure

- Create the proper folder structure.
- Copy Clarity as the base app because it already owns auth, dashboard, Supabase, transactions, budgets, accounts, and categories.
- Move the Clarity Flutter app into `apps/mobile`.
- Preserve Clarity's existing `supabase/migrations` and `supabase/functions`.
- Move Rex backend into `services/rex-api`.
- Keep Rex backend as a FastAPI service instead of converting it to Supabase Edge Functions, because Rex needs streaming, long-running AI orchestration, Deepgram, TTS, and memory workflows.
- Add root-level documentation and scripts.

Expected result:

```text
apps/mobile        # working Clarity Flutter app
services/rex-api   # working Rex FastAPI backend
supabase           # unified database migrations and edge functions
```

### Phase 2: Database & User Isolation (Critical)

- Add `user_id` to all Rex tables.
- Add proper RLS policies.
- Update all memory-related tables, including:
  - `conversations`
  - `messages`
  - `long_term_memory`
  - `memory_corrections`
  - `memory_candidates`
  - `entities`
  - `entity_events`
  - `personal_rules`
  - `plans`
  - `plan_milestones`
  - `commitments`
  - `voice_turns`
- Ensure every Rex table references `auth.users(id)` with `on delete cascade`.
- Update indexes so uniqueness is scoped by `user_id`.
- Add RLS policies using `auth.uid() = user_id`.

Example policy pattern:

```sql
alter table public.conversations enable row level security;

create policy "Users can manage their own conversations"
on public.conversations
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

This phase is mandatory before Rex can safely operate inside Clarity.

### Phase 3: Backend Authentication

- Add Supabase JWT validation to Rex FastAPI.
- Secure all routes with the user's token.
- Extract the authenticated `user_id` from the Supabase JWT.
- Do not accept `user_id` from request bodies.
- Remove service role key dependency where possible.
- Keep the service role key only for tightly controlled admin scripts or server-only maintenance jobs.
- Require authentication for:
  - chat routes
  - conversation routes
  - memory routes
  - memory candidate routes
  - goals/plans routes
  - accountability routes
  - voice routes
  - voice streaming websocket routes

Target request flow:

```text
Clarity Flutter app
  -> gets Supabase session access token
  -> sends Authorization: Bearer <token> to Rex API
  -> Rex validates token
  -> Rex derives user_id
  -> Rex queries and writes only that user's records
```

### Phase 4: Memory Service Updates

- Update all memory queries to filter by `user_id`.
- Implement user-scoped memory extraction, correction, and retrieval.
- Update conversation creation so every conversation belongs to the current user.
- Update message creation so messages inherit the conversation's user boundary.
- Update relevant memory search so it only searches the current user's memory.
- Update structured memory services for:
  - entities
  - entity events
  - personal rules
  - plans
  - milestones
  - commitments
  - corrections
  - candidates
- Add tests proving that User A cannot read, update, retrieve, or influence User B's memory.

The Rex backend should treat `user_id` as a required service argument for every persistence operation.

### Phase 5: Flutter Integration

- Merge Rex Flutter code into `apps/mobile/lib/rex/`.
- Update imports from `package:rex/...` to `package:clarity/...`.
- Merge Rex dependencies into Clarity's `pubspec.yaml`.
- Add Riverpod setup if needed.
- Preserve Clarity's existing app composition and auth flow.
- Keep Rex UI modular and contained under the assistant feature.

Suggested mapping:

```text
rex/lib/features/chat              -> apps/mobile/lib/rex/chat
rex/lib/features/voice             -> apps/mobile/lib/rex/voice
rex/lib/features/memory            -> apps/mobile/lib/rex/memory
rex/lib/features/accountability    -> apps/mobile/lib/rex/accountability
rex/lib/core/config                -> apps/mobile/lib/core/rex
```

### Phase 6: Rex API Client in Clarity

- Create an authenticated Rex API client.
- Handle Supabase token passing.
- Attach the current Supabase access token to every Rex HTTP request.
- Attach the token to websocket connection setup for voice streaming.
- Centralize Rex API configuration under `lib/core/rex/`.

Recommended files:

```text
apps/mobile/lib/core/rex/rex_config.dart
apps/mobile/lib/core/rex/rex_api_client.dart
apps/mobile/lib/core/rex/rex_auth_headers.dart
```

The client should fail clearly if there is no active Supabase session.

### Phase 7: UI Integration

- Add a "Rex" or "Assistant" tab in the main Clarity shell.
- Create sub-sections:
  - Chat
  - Voice
  - Memory
  - Goals
- Keep the Assistant UI visually consistent with Clarity's Material theme.
- Do not ship the old Rex app shell as a separate app inside Clarity.
- The assistant should feel native to the financial dashboard.

Recommended navigation:

```text
Dashboard | Accounts | Budgets | Assistant
```

Inside Assistant:

```text
Chat | Voice | Memory | Goals
```

### Phase 8: Financial Context Integration

- Create a service to send unified Clarity financial context to Rex.
- Include high-signal summaries such as:
  - monthly income
  - monthly spending
  - budget status
  - top spending categories
  - account balance summaries
  - recurring spending patterns
  - unusual spending alerts
- Include detailed user-scoped Clarity records when Rex is being used as the in-app assistant:
  - accounts
  - categories
  - budgets
  - transaction rows
  - account names
  - merchant names
  - descriptions
  - transaction IDs and import metadata
- Expose an explicit controls manifest for actions Rex can initiate through Clarity, including transaction, account, category, and budget operations.
- Destructive or money-moving changes must require explicit confirmation and an execution result before Rex claims that data changed.

Recommended backend approach:

```text
Rex API receives authenticated request
  -> validates user token
  -> receives or reads user-scoped Clarity financial context
  -> injects bounded context into assistant prompt
  -> returns hidden structured action proposals when a Clarity mutation is needed
  -> Flutter renders confirmation cards inside the existing chat thread
  -> routes confirmed mutations through /clarity/actions command handlers
```

This makes Rex and Clarity feel like one product while preserving user isolation and preventing unconfirmed writes.

### Phase 9: Testing & Validation

- Test user isolation.
- Test voice streaming.
- Test memory persistence per user.
- Test Clarity auth still works after wrapping with Riverpod.
- Test dashboard, accounts, budgets, transactions, CSV import, and Supabase functions.
- Test Rex chat with authenticated requests.
- Test Rex memory extraction and retrieval for multiple users.
- Test invalid, expired, or missing Supabase tokens.
- Test that financial context only contains the current user's summarized data.

Recommended validation commands:

```bash
cd apps/mobile
flutter analyze
flutter test

cd ../../services/rex-api
pytest
```

### Phase 10: Cleanup & Documentation

- Final cleanup.
- Update `README.md`.
- Create `docs/architecture.md`.
- Document local development setup.
- Document required environment variables.
- Document Supabase migration order.
- Document how Clarity talks to Rex.
- Document deployment strategy for:
  - Flutter app
  - Supabase migrations/functions
  - Rex FastAPI backend
- Remove obsolete Rex standalone app files once the integrated Assistant feature is stable.

---

## Environment Variables

### Mobile App

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=
REX_BACKEND_URL=
REX_CLOUD_VOICE_ENABLED=
REX_STREAMING_VOICE_ENABLED=
```

### Rex API

```text
APP_ENVIRONMENT=
APP_TIMEZONE=
CORS_ALLOWED_ORIGINS=

SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_JWT_SECRET=
SUPABASE_SERVICE_ROLE_KEY=

GROK_API_KEY=
GROK_BASE_URL=
GROK_MODEL=

DEEPGRAM_API_KEY=

GOOGLE_TTS_PROJECT_ID=
GOOGLE_TTS_CREDENTIALS_JSON=
GOOGLE_APPLICATION_CREDENTIALS=
```

Note: `SUPABASE_SERVICE_ROLE_KEY` should not be used for normal user-scoped requests unless there is a specific server-side reason and the code still enforces the authenticated user's boundary.

---

## Main Security Requirements

- Every Rex request must be authenticated.
- Every Rex database row must belong to a `user_id`.
- Every Rex query must filter by the authenticated `user_id`.
- RLS must be enabled on all Rex tables.
- Financial context must be user-scoped.
- Detailed transaction data may be sent to Rex only inside authenticated Clarity assistant flows.
- Rex must not execute destructive or money-moving changes without explicit confirmation and a successful command result.
- Service role access must never create cross-user memory leakage.

---

## Definition of Done

The merge is complete when:

- Clarity runs as the single main Flutter app.
- Rex appears as the Assistant feature inside Clarity.
- Users authenticate through Clarity/Supabase.
- Rex chat works for authenticated Clarity users.
- Rex voice works for authenticated Clarity users.
- Rex memory, goals, plans, commitments, and conversations are fully separated per user.
- Rex can use detailed user-scoped financial context from Clarity.
- Rex can initiate confirmed Clarity controls for transactions, accounts, categories, and budgets.
- Existing Clarity features continue to work.
- Tests confirm user isolation and core app behavior.
- The repository has updated setup and architecture documentation.
