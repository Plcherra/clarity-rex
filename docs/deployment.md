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

The Phase 9 Rex migration archives and drops the old pending-memory review
tables. Before pushing it to production, optionally inspect whether those legacy
tables still contain rows:

```sql
select count(*) from public.memory_candidates;
select count(*) from public.memory_confirmations;
select count(*) from public.memory_candidate_review_sessions;
```

After `supabase db push`, any remaining rows are copied into legacy archive
tables with owner-only RLS before the old runtime tables are removed.

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
GROK_FAST_MODEL=<optional-fast-model-or-empty>
GROK_STANDARD_MODEL=<optional-standard-model-or-empty>
GROK_REASONING_MODEL=<optional-reasoning-model-or-empty>
REX_BRAIN_ROUTING_ENABLED=false
REX_BRAIN_DEBUG_ENABLED=false
REX_BRAIN_FAST_FIRST_ENABLED=false
REX_BRAIN_ROLLOUT_STAGE=disabled
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

python3.12 -m venv .venv || python3.11 -m venv .venv
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

The canonical VPS service name is `clarity-rex.service`. Do not restart the
legacy `rex-backend.service` for this app unless you are intentionally checking
an old deployment.

Copy the template:

```sh
sudo cp /opt/clarity/current/deploy/templates/clarity-rex.service /etc/systemd/system/clarity-rex.service
sudo systemctl daemon-reload
sudo systemctl enable clarity-rex
sudo systemctl start clarity-rex
sudo systemctl status clarity-rex --no-pager
```

The service binds to `127.0.0.1:8011` so it can sit beside the legacy `/opt/rex` process during migration.

For normal deploy restarts, use the checked-in helper from `/opt/clarity/current`:

```sh
./scripts/vps_restart_rex_api.sh
```

It restarts `clarity-rex.service` and immediately checks `/ready`.

## Reverse Proxy

Use the nginx template as a starting point:

```text
deploy/templates/nginx-clarity-rex.conf
```

It proxies HTTP and websocket traffic to `127.0.0.1:8011`.

For the Clarity API domain migration, keep both hostnames during the transition:

```nginx
server_name api.goclarity.app api.rexpilot.com;
```

This allows current mobile builds that still know the old API hostname to keep working while new builds move to `https://api.goclarity.app`.

On the VPS, the active Nginx config is usually `/etc/nginx/sites-available/rex` with `/etc/nginx/sites-enabled/rex` symlinked to it. Update both HTTP and HTTPS server blocks if both exist:

```sh
sudo grep -R "server_name api.rexpilot.com" -n /etc/nginx/sites-enabled /etc/nginx/sites-available /etc/nginx/conf.d
sudo nano /etc/nginx/sites-available/rex
```

After editing the `server_name` values:

```sh
sudo nginx -t
sudo systemctl reload nginx
```

Then issue or expand the TLS certificate:

```sh
sudo certbot --nginx -d api.goclarity.app -d api.rexpilot.com
```

Keep `api.goclarity.app` DNS-only in Cloudflare until the certificate and `/ready` checks pass.

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

Expected `/ready` status is `ready` once Grok, Supabase, Deepgram, Google TTS, and timezone config are set. The `checks.rex_brain` section should also show the current routing/debug flags, rollout stage, and configured model names.

## Rex Brain Staged Rollout

Rex Brain ships disabled by default. Use these stages in production:

1. `disabled` - default; no routed prompt/model behavior.
2. `logging_only` - keep `REX_BRAIN_ROUTING_ENABLED=true` only if you want planning/log verification without changing model calls.
3. `fast_contextual` - allow only fast/contextual routed turns.
4. `analytical` - allow fast/contextual/coaching/analytical routes, but block strategic/reflective.
5. `strategic_reflective` - allow all backend routing layers.
6. `deep_think_ui` - full backend routing plus the mobile Deep Think UX.

Recommended first VPS enablement:

```env
REX_BRAIN_ROUTING_ENABLED=true
REX_BRAIN_ROLLOUT_STAGE=logging_only
REX_BRAIN_DEBUG_ENABLED=false
```

Rollback is intentionally simple:

```env
REX_BRAIN_ROUTING_ENABLED=false
REX_BRAIN_ROLLOUT_STAGE=disabled
```

Then restart only the canonical service:

```sh
cd /opt/clarity/current
./scripts/vps_restart_rex_api.sh
```

## Mobile Build Pointing At VPS

Either set `apps/mobile/.env`:

```env
REX_BACKEND_URL=https://<api-domain-or-ip>
```

or pass it at build/run time:

```sh
cd apps/mobile
flutter run -d <device-id> --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=REX_BACKEND_URL=https://<api-domain-or-ip> \
  --dart-define=REX_CLOUD_VOICE_ENABLED=true \
  --dart-define=REX_STREAMING_VOICE_ENABLED=true
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
