# Clarity

Flutter personal finance app with Supabase Auth, Supabase-backed profile and
financial tables, CSV import, dashboard/budget views, and AI categorization
through a Supabase Edge Function.

Feature contract: [`docs/csv_import_ai_categorization.md`](docs/csv_import_ai_categorization.md)
is the source of truth for CSV import, automatic AI categorization, category
creation, Budget page category visibility, and merchant learning.

## Current Architecture

- App startup: `lib/main.dart` -> `lib/app/bootstrap.dart`
- Composition root: `lib/app/app_composition.dart`
- Routing shell: `lib/app/app.dart`
- UI controller wiring: `lib/app/ui_dependencies.dart`
- Supabase boundary: `lib/core/supabase/`
- Feature-first UI and workflows: `lib/features/`

`AppState` has been removed. Auth/profile routing is owned by
`AuthController` and `ProfileController`. App data services use Supabase table
services through `SupabaseRepository`.

## Local Setup

Install dependencies:

```sh
flutter pub get
```

For local development, either pass public config with `--dart-define`:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=REX_BACKEND_URL=https://your-rex-api.example.com \
  --dart-define=REX_CLOUD_VOICE_ENABLED=true \
  --dart-define=REX_STREAMING_VOICE_ENABLED=true
```

or create a local `.env` file:

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-public-anon-key
REX_BACKEND_URL=https://your-rex-api.example.com
REX_CLOUD_VOICE_ENABLED=true
REX_STREAMING_VOICE_ENABLED=true
```

Only public Supabase config belongs in Flutter `.env`. Do not put
`OPENAI_API_KEY` or other server secrets in Flutter config.

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `REX_BACKEND_URL` may be passed with
`--dart-define`; dart-define values win over `.env` when both are present. The
`.env` file is ignored and is not bundled as a required release asset.

Recommended iPhone release command:

```sh
flutter run -d 00008150-000C03C83A2B401C --release \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=REX_BACKEND_URL=https://api.rexpilot.com \
  --dart-define=REX_CLOUD_VOICE_ENABLED=true \
  --dart-define=REX_STREAMING_VOICE_ENABLED=true
```

Do not pass `REX_NATIVE_IOS_VOICE_ENABLED` for normal testing. That legacy flag
is intentionally reported in startup logs but is not the supported voice path.

## Supabase

Apply database migrations:

```sh
supabase db push
```

Deploy the OpenAI Edge Functions:

```sh
supabase functions deploy call-openai
supabase functions deploy categorize-transactions
supabase secrets set OPENAI_API_KEY=your-real-openai-key
```

Keep JWT verification enabled for Edge Functions. Do not deploy these functions
with `--no-verify-jwt`.

## Verification

Run:

```sh
flutter analyze
flutter test
git diff --check
```

Optional Edge Function type check, after installing Deno:

```sh
deno check supabase/functions/call-openai/index.ts
deno check supabase/functions/categorize-transactions/index.ts
```

## Product Direction

- CSV import is intended to be near-zero effort: select a file, save
  transactions, categorize everything with AI, apply categories, then refresh
  dashboard and budgets.
- Budget categories should be driven by categories that actually have
  transactions, not an empty static list.
- Manual category corrections should become Supabase-backed merchant learning
  and apply to matching past and future transactions.
