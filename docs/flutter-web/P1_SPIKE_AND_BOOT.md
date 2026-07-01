# P1 — Spike, Platform Foundation, and Web Boot

**Previous:** none  
**Next:** [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md)

**Status:** ✅ Code complete — manual Chrome auth + VPS CORS deploy still required to fully sign off exit criteria.

## Objective

App loads in Chrome, authenticates, and reaches `HomeShell` without plugin crashes.

## Prerequisites

- `apps/mobile/.env` or dart-defines with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REX_BACKEND_URL`
- Flutter SDK with web enabled
- rex-api reachable (local or `https://api.goclarity.app`)

## Tasks

### 1. Chrome spike ✅

Run and log every boot/runtime failure:

```bash
cd apps/mobile
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REX_BACKEND_URL=https://api.goclarity.app
```

Or use the helper script (reads `apps/mobile/.env`):

```bash
./scripts/flutter_web_dev.sh
```

**Spike log (2026-06-30):**

| Finding | Severity | Mitigation |
|---------|----------|------------|
| `flutter build web` compiles successfully (~30s) | — | Baseline OK |
| Wasm dry-run warns `ua_client_hints` uses `dart:html` | Info | Use `--no-wasm-dry-run` or ignore until wasm target needed |
| Boot requires `SUPABASE_URL` + `SUPABASE_ANON_KEY` | Expected | Pass via `.env` or `--dart-define`; boot error screen if missing |
| Native MethodChannels (Plaid, voice background, iOS voice bridge, voice audio) | Fixed | `AppCapabilities` + no-op stubs; `UnsupportedPlaidLinkLauncher` on web |
| `dart:io` in CSV import, chat attachments, streaming voice WebSocket | Deferred | Compiles today; runtime failures if those paths invoked on web (P3/P4/P5) |
| Rex API calls from browser blocked without CORS | Blocker (ops) | Origins added to `.env.example`; **must update live VPS env + restart** |
| Supabase Auth redirect allow-list for web origin | Blocker (ops) | Add `https://app.goclarity.app` and `http://localhost:8080` in Supabase dashboard |

### 2. Add `AppCapabilities` ✅

New module: `apps/mobile/lib/core/platform/app_capabilities.dart`

Flags:

- `supportsNativePlaidLink`
- `supportsWebPlaidLink` (false until P4)
- `supportsStreamingVoice` (false on web until P5)
- `supportsBackgroundVoice`
- `supportsNativeVoiceBridge`
- `supportsCsvImport`

Based on `kIsWeb` + `defaultTargetPlatform`. Unit tests in `apps/mobile/test/app_capabilities_test.dart`.

### 3. Guard plugin entry points ✅

- `NativePlaidLinkLauncher` — not used on web; `UnsupportedPlaidLinkLauncher` returns exit
- Voice: no-op stubs in `web_voice_service_stubs.dart`; providers gated in `voice_call_controller_providers.dart`
- Native audio session MethodChannel skipped on web via `NoOpVoiceAudioSessionService`

### 4. Web dev/build script ✅

- `scripts/flutter_web_dev.sh` — Chrome dev with standard dart-defines (port 8080 default)
- `scripts/flutter_web_release_build.sh` — P6 stub

### 5. Supabase auth on web ⚠️ (code + ops)

- `AuthConfig` documents `https://app.goclarity.app` web origin
- Email links continue using `goclarity.app/auth/*` pages in `apps/web`
- **Manual:** add `https://app.goclarity.app` and `http://localhost:8080` to Supabase Auth redirect allow-list
- **Manual:** verify login, signup, MFA, password reset in Chrome with real credentials

### 6. Backend CORS ⚠️ (code + ops)

Added to rex-api `.env.example`:

- `https://app.goclarity.app`
- `http://localhost:8080` (Flutter web default dev port)

**Manual:** update live `CORS_ALLOWED_ORIGINS` on VPS and restart rex-api per `docs/BACKEND_DEPLOY_RUNBOOK.md`.

## Exit criteria

- [ ] Login → MFA (if enabled) → lands in `HomeShell` on Chrome *(needs manual test with Supabase credentials + redirect allow-list)*
- [x] No unhandled `MissingPluginException` on boot *(native plugin entry points guarded)*
- [ ] Dashboard or accounts tab loads Supabase data (read path) *(needs manual test after auth + CORS)*
- [x] `AppCapabilities` unit test passes
- [x] Changed files analyze clean; web build succeeds *(pre-existing analyze infos and unrelated test failures unchanged)*

## Files changed

- `apps/mobile/lib/core/platform/app_capabilities.dart` (new)
- `apps/mobile/lib/rex/voice/data/web_voice_service_stubs.dart` (new)
- `apps/mobile/lib/rex/voice/application/voice_call_controller_providers.dart`
- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart`
- `apps/mobile/lib/features/auth/application/auth_config.dart`
- `apps/mobile/test/app_capabilities_test.dart` (new)
- `scripts/flutter_web_dev.sh` (new)
- `scripts/flutter_web_release_build.sh` (new, P6 stub)
- `services/rex-api/.env.example`
- `services/rex-api/mobile.env.example`
- `services/rex-api/README.md`

## Out of scope (defer)

- Adaptive layout (P2)
- Plaid web Link (P4)
- Voice on web (P5)
- PWA manifest polish (P6)

## Known blockers before P2

1. **VPS CORS** — live rex-api must include `https://app.goclarity.app` and dev localhost origin.
2. **Supabase Auth** — dashboard must allow web app + localhost redirect origins.
3. **Manual Chrome sign-off** — login/MFA/HomeShell and dashboard read path not verified in this session (no credentials in repo).
