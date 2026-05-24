# Clarity VPS Deployment Guide

This guide is for the new merged app deployment. The target VPS layout is:

```text
/opt/clarity/
  current/              # Git checkout of this repository
  shared/
    rex-api.env         # Backend secrets, not committed
    google-tts.json     # Optional Google service-account file, not committed
```

Do not delete `/opt/rex` until `/opt/clarity` is deployed, health checks pass, and the mobile app can talk to the new backend.

## Pre-Deploy Local Checklist

Run this from the repository root before touching the VPS:

```sh
./scripts/predeploy_check.sh
```

Expected checks:

- Flutter analyze passes.
- Flutter tests pass.
- Android debug APK builds.
- Rex backend tests pass.
- Python compile check passes.
- `.env` files stay untracked.

## Supabase

The Supabase project is the source of auth and all Clarity/Rex data. Because this project was reset clean, apply the root migrations before testing real users:

```sh
supabase link --project-ref <project-ref>
supabase db push
```

Do not run `supabase db lint` unless a local Supabase database is running; it attempts to connect to local Postgres.

Required public Flutter values:

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
REX_BACKEND_URL=https://<api-domain-or-ip>
```

Required Rex API values live only on the VPS:

```env
APP_ENVIRONMENT=production
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
GROK_API_KEY=<server-secret>
GROK_MODEL=grok-4.3
DEEPGRAM_API_KEY=<server-secret>
GOOGLE_TTS_PROJECT_ID=<project-id>
GOOGLE_APPLICATION_CREDENTIALS=/opt/clarity/secrets/service_account.json
# Or use GOOGLE_TTS_CREDENTIALS_JSON=<raw-json-string>
```

`SUPABASE_SERVICE_ROLE_KEY` is optional. Normal user-scoped requests use the user's Supabase JWT with the anon key so RLS remains active.

## VPS Bootstrap

Use these commands on the VPS when we are ready to start the new deployment:

```sh
sudo mkdir -p /opt/clarity/shared
sudo chown -R rex:rex /opt/clarity

cd /opt/clarity
git clone https://github.com/Plcherra/clarity-rex.git current
cd current/services/rex-api

python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Create `/opt/clarity/shared/rex-api.env` from:

```text
deploy/templates/rex-api.env.example
```

Then symlink it:

```sh
ln -sfn /opt/clarity/shared/rex-api.env /opt/clarity/current/services/rex-api/.env
```

## Systemd

Copy the template:

```sh
sudo cp /opt/clarity/current/deploy/templates/clarity-rex.service /etc/systemd/system/clarity-rex.service
sudo systemctl daemon-reload
sudo systemctl enable clarity-rex
sudo systemctl start clarity-rex
sudo systemctl status clarity-rex --no-pager
```

The service binds to `127.0.0.1:8011` so it can sit beside the legacy `/opt/rex` process during migration.

## Reverse Proxy

Use the nginx template as a starting point:

```text
deploy/templates/nginx-clarity-rex.conf
```

It proxies HTTP and websocket traffic to `127.0.0.1:8011`.

After editing the `server_name` and TLS paths:

```sh
sudo nginx -t
sudo systemctl reload nginx
```

## Health Checks

From the VPS:

```sh
curl -i http://127.0.0.1:8011/
curl -sS http://127.0.0.1:8011/ready | python3 -m json.tool
```

From your Mac, after nginx/domain is ready:

```sh
./scripts/vps_smoke_check.sh https://<api-domain-or-ip>
```

If nginx/domain is not ready yet, run the smoke check on the VPS with `http://127.0.0.1:8011`, or create an SSH tunnel from your Mac first.

Expected `/ready` status is `ready` once Grok, Supabase, Deepgram, Google TTS, and timezone config are set.

## Mobile Build Pointing At VPS

Either set `apps/mobile/.env`:

```env
REX_BACKEND_URL=https://<api-domain-or-ip>
```

or pass it at build/run time:

```sh
cd apps/mobile
flutter run --dart-define=REX_BACKEND_URL=https://<api-domain-or-ip>
```

The dart define wins over `.env` when both are present.

## Post-Deploy Validation

Use two separate Supabase users and verify:

- User A cannot see User B conversations, memory, goals, or transactions.
- Chat works with authenticated requests.
- Streaming chat works and does not expose hidden `clarity_action` JSON.
- Clarity action cards execute only after confirmation.
- Cloud voice turn works.
- Streaming voice works over websocket.
- Memory persists per user.
- Dashboard/transactions refresh after confirmed actions.

Only after these pass should `/opt/rex` be retired.
