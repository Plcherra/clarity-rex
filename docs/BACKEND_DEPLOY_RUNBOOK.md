# Backend Deploy Runbook

Canonical operations guide for the Rex API (`services/rex-api`) on the VPS.

## Canonical Commands

Restart backend and wait for readiness:

```sh
./scripts/vps_restart_rex_api.sh
```

Manual equivalent:

```sh
sudo systemctl restart clarity-rex
curl -fsS http://127.0.0.1:8011/ready | python3 -m json.tool
```

Health only (no dependency checks):

```sh
curl -fsS http://127.0.0.1:8011/
```

## Required Production Env

Copy `deploy/templates/rex-api.env.example` to the VPS env file (for example `/opt/clarity/shared/rex-api.env`).

Required for production startup (`APP_ENVIRONMENT=production`):

| Variable | Purpose |
|----------|---------|
| `GROK_API_KEY` | Rex chat/voice reasoning |
| `GROK_MODEL` | Primary Grok model |
| `SUPABASE_URL` | Database and auth |
| `SUPABASE_ANON_KEY` | User-scoped REST + auth validation |
| `DEEPGRAM_API_KEY` | Cloud speech-to-text |
| `GOOGLE_TTS_PROJECT_ID` | Cloud text-to-speech |
| `GOOGLE_TTS_CREDENTIALS_JSON` or `GOOGLE_APPLICATION_CREDENTIALS` | Google TTS auth |

The API refuses to start in production when required vars are missing.

## Plaid (when finance sync is enabled)

Plaid is optional for `/ready`, but required for bank connections:

| Variable | Purpose |
|----------|---------|
| `PLAID_CLIENT_ID` | Plaid app id |
| `PLAID_SECRET` | Plaid secret |
| `PLAID_ENVIRONMENT` | `sandbox`, `development`, or `production` |
| `PLAID_PRODUCTS` | Usually `transactions` |
| `PLAID_COUNTRY_CODES` | Usually `US` |
| `PLAID_WEBHOOK_URL` | Webhook endpoint for sync updates |
| `PLAID_TOKEN_ENCRYPTION_SECRET` | Encrypt stored access tokens |
| `SUPABASE_SERVICE_ROLE_KEY` | Backend-owned Plaid persistence |

## Post-Deploy Smoke

1. Restart with `./scripts/vps_restart_rex_api.sh`.
2. Confirm `/ready` returns `"status": "ready"` or review `"degraded"` checks.
3. Send an authenticated chat request:

```sh
curl -X POST http://127.0.0.1:8011/chat \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello Rex"}'
```

4. Optional: streaming chat, Plaid link token, voice turn when those env groups are configured.
5. Check logs for useful diagnostics without token leakage:

```sh
sudo journalctl -u clarity-rex -n 80 --no-pager
```

## Rex Brain Production Path

MVP uses one brain only:

```text
Chat/Voice routes -> ChatService -> ChatTurnOrchestrator -> SimpleRexBrain
```

Experimental layered routing modules remain in the tree for later work but are not on the production path.

## Supabase Schema

Apply migrations from `supabase/migrations/`. Do not apply `services/rex-api/supabase_schema.sql` (stale reference file).

## Edge Functions

CSV AI categorization uses `supabase/functions/categorize-transactions` with JWT verification enabled. The legacy `call-openai` function is deprecated.

## Auth email (launch blocker)

Supabase Auth must send sign-up confirmation mail through working SMTP.
See `docs/SUPABASE_AUTH_EMAIL_SETUP.md` and run `./scripts/verify_supabase_auth_email.sh`
before beta sign-off.

## Mobile Release Build

From `apps/mobile`:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=REX_BACKEND_URL=https://your-api-host
```

Use the production Rex API URL in `REX_BACKEND_URL`.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Service exits immediately on restart | Missing production env; check `journalctl -u clarity-rex` |
| `/ready` is `degraded` | Voice or Grok env missing; check `checks` object |
| Auth returns 503 in production | Supabase URL/anon key missing |
| Plaid routes fail | Plaid env or service role key missing |
| Dev user id in logs on VPS | `APP_ENVIRONMENT` not set to `production` |
| Sign-up shows email send error | Broken Supabase Auth SMTP; see `docs/SUPABASE_AUTH_EMAIL_SETUP.md` |
| No confirmation email received | Fix Resend SMTP, verify domain, check spam |
