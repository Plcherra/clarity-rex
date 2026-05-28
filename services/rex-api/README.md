# Rex API

Rex API is the FastAPI assistant backend inside the merged Clarity app.

Current stack:

- Backend: FastAPI
- AI: Grok API through the backend only
- Database: Supabase for conversations, messages, memory, goals, rules, plans, commitments, and voice turns
- Memory: short-term transcript memory plus long-term facts, preferences, and events
- Production voice target: Deepgram speech-to-text and Google Text-to-Speech through the backend

Rex API no longer uses Ollama, local models, or SQLite.

## Architecture

```text
Clarity Flutter app
  -> Rex FastAPI backend with Supabase access token
    -> Supabase Auth validates the user token
    -> Supabase REST API stores user-scoped assistant data
    -> Grok API generates chat responses and memory extraction
    -> Deepgram handles cloud speech-to-text
    -> Google Text-to-Speech generates spoken responses
```

The Flutter app never stores Grok, Supabase service-role, Deepgram, or Google credentials. It authenticates with Clarity/Supabase and sends the current Supabase access token to this API.

All assistant records must belong to a Supabase `auth.users.id` through `user_id`.

## Environment

Backend settings are read from `.env` by `app/config.py`.

Create a backend environment file:

```sh
cp .env.example .env
```

Required backend values:

```env
APP_ENVIRONMENT=development
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
GROK_API_KEY=
GROK_MODEL=
GROK_FAST_MODEL=
GROK_STANDARD_MODEL=
GROK_REASONING_MODEL=
REX_BRAIN_ROUTING_ENABLED=false
REX_BRAIN_DEBUG_ENABLED=false
REX_BRAIN_FAST_FIRST_ENABLED=false
REX_BRAIN_ROLLOUT_STAGE=disabled
GROK_BASE_URL=https://api.x.ai/v1
GROK_TIMEOUT_SECONDS=120

SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_CONVERSATIONS_TABLE=conversations
SUPABASE_MESSAGES_TABLE=messages
SUPABASE_LONG_TERM_MEMORY_TABLE=long_term_memory
SUPABASE_MEMORY_CORRECTIONS_TABLE=memory_corrections
SUPABASE_MEMORY_CANDIDATES_TABLE=memory_candidates
SUPABASE_VOICE_TURNS_TABLE=voice_turns

DEEPGRAM_API_KEY=
DEEPGRAM_MODEL=nova-3
DEEPGRAM_LANGUAGE=en-US
DEEPGRAM_BASE_URL=https://api.deepgram.com/v1
DEEPGRAM_TIMEOUT_SECONDS=60
DEEPGRAM_ENDPOINTING_MS=900
DEEPGRAM_LIVE_TRANSCRIPT_IDLE_MS=1100

GOOGLE_TTS_PROJECT_ID=
GOOGLE_APPLICATION_CREDENTIALS=/opt/clarity/secrets/service_account.json
# Or set GOOGLE_TTS_CREDENTIALS_JSON to the raw service-account JSON.
GOOGLE_TTS_CREDENTIALS_JSON=
GOOGLE_TTS_VOICE_NAME=en-US-Neural2-J
GOOGLE_TTS_LANGUAGE_CODE=en-US
GOOGLE_TTS_AUDIO_ENCODING=MP3
GOOGLE_TTS_SPEAKING_RATE=1.14
GOOGLE_TTS_PITCH=0.0
```

`SUPABASE_SERVICE_ROLE_KEY` is optional. Normal app traffic should use the user's Supabase access token plus `SUPABASE_ANON_KEY` so RLS remains active.

## Supabase Setup

Use the root repository Supabase migrations, not the old standalone schema file.

The current Rex assistant schema lives at:

```text
../../supabase/migrations/000010_create_rex_assistant_tables.sql
```

## Backend

Install dependencies:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Run the backend:

```sh
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check:

```sh
curl http://localhost:8000/
```

Authenticated request example:

```sh
curl http://localhost:8000/conversations \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN"
```

Readiness check:

```sh
curl http://localhost:8000/ready
```

## Rex Brain Rollout

Rex Brain is disabled by default. `GROK_MODEL` remains the fallback model, so existing deployments keep working. Enable gradually with:

```env
REX_BRAIN_ROUTING_ENABLED=true
REX_BRAIN_ROLLOUT_STAGE=logging_only
```

Available rollout stages are `disabled`, `logging_only`, `fast_contextual`, `analytical`, `strategic_reflective`, and `deep_think_ui`. Roll back by setting `REX_BRAIN_ROUTING_ENABLED=false` and restarting `clarity-rex.service` through `./scripts/vps_restart_rex_api.sh`.

Production VPS restarts should use the canonical systemd unit:

```sh
sudo systemctl restart clarity-rex
curl -fsS http://127.0.0.1:8011/ready | python3 -m json.tool
```

From `/opt/clarity/current`, the helper wraps those steps:

```sh
./scripts/vps_restart_rex_api.sh
```

Chat request:

```sh
curl -X POST http://localhost:8000/chat \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello Rex"}'
```

Streaming chat request:

```sh
curl -N -X POST http://localhost:8000/chat \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello Rex","stream":true}'
```

## Flutter

Install packages:

```sh
flutter pub get
```

Run the app:

```sh
flutter run --dart-define=REX_BACKEND_URL=http://localhost:8000
```

Main screens currently implemented:

- Chat screen with streaming responses
- Conversation list and switching
- Long-term memory list/edit/deactivate screen
- File upload flow for `.txt`, `.md`, and `.csv`

Current local voice support exists as a development fallback. The production voice plan is documented in [docs/action_plans/voice_pipeline_checklist.md](docs/action_plans/voice_pipeline_checklist.md), with the initial audio contract in [docs/cloud_voice_contract.md](docs/cloud_voice_contract.md) and Google TTS setup in [docs/google_tts_setup.md](docs/google_tts_setup.md).

## Tests

Backend:

```sh
python -m pytest
```

Flutter:

```sh
flutter analyze
flutter test
```

Current expected status after Phase 8 plus pre-deploy cleanup:

- Backend tests: 363 passing
- Flutter tests: 41 passing

## Notes

- Do not commit real `.env` files or secrets.
- Use `services/rex-api/.env.example` as the source for backend environment variable names.
- Use `apps/mobile/.env` or `--dart-define=REX_BACKEND_URL=...` to point Flutter at the correct backend. The dart define wins if both are set.
- Supabase SQL must be applied before real chat memory can work.
- Deepgram and Google TTS credentials stay backend-side only.
- Deployment notes are in [../../docs/deployment.md](../../docs/deployment.md).
