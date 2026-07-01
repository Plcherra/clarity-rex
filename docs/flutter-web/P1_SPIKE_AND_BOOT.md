# P1 — Spike, Platform Foundation, and Web Boot

**Previous:** none  
**Next:** [P2_ADAPTIVE_SHELL.md](./P2_ADAPTIVE_SHELL.md)

## Objective

App loads in Chrome, authenticates, and reaches `HomeShell` without plugin crashes.

## Prerequisites

- `apps/mobile/.env` or dart-defines with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REX_BACKEND_URL`
- Flutter SDK with web enabled
- rex-api reachable (local or `https://api.goclarity.app`)

## Tasks

### 1. Chrome spike

Run and log every boot/runtime failure:

```bash
cd apps/mobile
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REX_BACKEND_URL=https://api.goclarity.app
```

Document: crash site, `MissingPluginException`, config errors, auth redirect issues.

### 2. Add `AppCapabilities`

New module (~80–120 lines): `apps/mobile/lib/core/platform/app_capabilities.dart`

Flags (minimum):

- `supportsNativePlaidLink`
- `supportsWebPlaidLink` (false until P4)
- `supportsStreamingVoice` (false until P5)
- `supportsBackgroundVoice`
- `supportsNativeVoiceBridge`
- `supportsCsvImport`

Based on `kIsWeb` + `defaultTargetPlatform`.

### 3. Guard plugin entry points

Prevent boot crashes from web-unsupported plugins:

- `NativePlaidLinkLauncher` — do not invoke on web
- Voice: `MethodChannelBackgroundVoiceService`, `MethodChannelNativeVoiceSessionService`, native audio session channels
- Stub or no-op providers in `voice_call_controller_providers.dart` when `kIsWeb`

### 4. Web dev/build script

Add `scripts/flutter_web_dev.sh` at repo root with standard dart-defines (mirror `scripts/mobile_release_run.sh` pattern).

Optional: `scripts/flutter_web_release_build.sh` stub for P6.

### 5. Supabase auth on web

- Verify login, signup, MFA, password reset in Chrome
- `AuthConfig` redirect URLs: ensure Supabase dashboard allows `https://app.goclarity.app` (and localhost for dev)
- Email links may continue using `goclarity.app/auth/*` pages in `apps/web`

### 6. Backend CORS

Add to rex-api `CORS_ALLOWED_ORIGINS`:

- `https://app.goclarity.app`
- `http://localhost:<flutter-web-port>` (dev)

Deploy/restart rex-api on VPS per `docs/BACKEND_DEPLOY_RUNBOOK.md`.

## Exit criteria

- [ ] Login → MFA (if enabled) → lands in `HomeShell` on Chrome
- [ ] No unhandled `MissingPluginException` on boot
- [ ] Dashboard or accounts tab loads Supabase data (read path)
- [ ] `AppCapabilities` unit test passes
- [ ] Existing `flutter test` / analyze still clean

## Files likely touched

- `apps/mobile/lib/core/platform/app_capabilities.dart` (new)
- `apps/mobile/lib/rex/voice/application/voice_call_controller_providers.dart`
- `apps/mobile/lib/features/plaid/application/plaid_link_service.dart` (guard only)
- `scripts/flutter_web_dev.sh` (new)
- `services/rex-api/.env.example` (document CORS origins)

## Out of scope (defer)

- Adaptive layout (P2)
- Plaid web Link (P4)
- Voice on web (P5)
- PWA manifest polish (P6)
