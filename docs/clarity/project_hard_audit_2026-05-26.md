# Project Hard Audit - 2026-05-26

This audit looks for what can still break Clarity Rex even though the main app is now mostly working. The codebase is in much better shape than the earlier transaction/category phase: automated checks are green, the iOS release build succeeds locally, and the core financial tests are meaningful. The remaining risk is concentrated in production configuration, startup behavior, voice lifecycle, schema drift, and oversized UI/controller files.

## Automated Check Results

- `flutter analyze`: passed.
- `flutter test`: passed, 92 tests.
- `python3 -m pytest` in `services/rex-api`: passed, 365 tests.
- `deno test --allow-env --allow-net supabase/functions/categorize-transactions/index_test.ts`: passed, 11 tests.
- `flutter build ios --release --no-codesign`: passed, built `Runner.app`.
- `supabase db lint --local`: failed because local schema contains `public.create_company_invite`, which calls `gen_random_bytes(integer)` but the function cannot resolve.
- `supabase db diff --local --schema public`: blocked because Supabase CLI requires Docker for the shadow database and Docker is not available.
- `flutter pub outdated`: direct dependency `record` is pinned at `6.2.1`; latest is `7.0.0`.
- Python test run warns that Python `3.9` is end-of-life and local SSL is LibreSSL.

## P0 - Correctness And Release Blockers

Status after P0 pass:
- P0.1 has a migration prepared in `000022_drop_stale_company_invite_function.sql`; it still needs `supabase db push` against the linked project.
- P0.2 is implemented: Supabase mobile config now supports `--dart-define` and `.env` is no longer a required release asset.
- P0.3 is implemented: the app mounts a boot screen first and startup errors are retryable in-app.
- P0.4 is implemented: Rex financial context now reports `data_status` and load errors instead of silently claiming empty data.
- P0.5 is implemented: the financial read model loads each source independently and carries diagnostics for degraded sources.

### P0.1 Supabase schema drift is present

Evidence:
- `supabase db lint --local` reports `public.create_company_invite` uses `gen_random_bytes(24)`, but `gen_random_bytes(integer)` cannot be found.
- `create_company_invite` is not present in the committed migrations.
- `supabase db diff --local` cannot run without Docker, so drift cannot currently be inspected locally.

Why this matters:
- The checked-in migrations do not fully describe the active database.
- Future migration pushes may pass while local/remote behavior diverges.
- If the function exists in production, invite/account flows may fail at runtime.

Required fix:
- Identify whether `public.create_company_invite` exists in remote production, local only, or old project state.
- Add a migration that either drops the stale function or recreates it with a correct dependency, likely `extensions.gen_random_bytes(24)` or a stable `search_path`.
- Add a no-Docker schema verification runbook if Docker will not be part of this project.

### P0.2 Mobile release configuration depends on an ignored `.env` asset

Evidence:
- [apps/mobile/pubspec.yaml](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/pubspec.yaml:78) declares `.env` as a Flutter asset.
- [apps/mobile/.gitignore](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/.gitignore:3) ignores `.env`.
- [apps/mobile/lib/core/supabase/supabase_service.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/core/supabase/supabase_service.dart:19) reads Supabase URL/key only from dotenv.

Why this matters:
- A clean clone may fail to build if `.env` is missing.
- A release build can silently depend on one developer machine's local file.
- It creates a risk of accidentally bundling secrets if someone puts server keys in mobile `.env`.

Required fix:
- Support `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`.
- Remove `.env` as a required bundled asset, or bundle only a committed non-secret defaults asset.
- Keep server-only secrets out of all mobile assets.

### P0.3 App can crash or white-screen before `runApp`

Evidence:
- [apps/mobile/lib/app/bootstrap.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/app/bootstrap.dart:10) loads dotenv.
- [apps/mobile/lib/app/bootstrap.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/app/bootstrap.dart:11) initializes Supabase and can throw if config is missing.
- [apps/mobile/lib/app/bootstrap.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/app/bootstrap.dart:14) fetches initial app data before `runApp`.

Why this matters:
- Missing config, slow network, Supabase downtime, or one table read failure can prevent the UI from mounting.
- The user sees a blank/crashed app rather than a recoverable screen.

Required fix:
- Call `runApp` first with an app boot state.
- Move Supabase initialization, startup hydration, and profile hydration behind a visible loading/error/retry screen.
- Keep auth/config errors recoverable inside the app.

### P0.4 Rex financial context silently collapses to empty data

Evidence:
- [apps/mobile/lib/rex/data/financial_context_service.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/data/financial_context_service.dart:194) catches all financial read-model errors.
- On any error, it returns `FinancialReadModel.empty()`.

Why this matters:
- A single Supabase table failure can make Rex say it has no financial data.
- The user cannot distinguish "no data exists" from "data failed to load."

Required fix:
- Do not convert all failures into empty finance.
- Return a context payload with `data_status`, `load_errors`, and whatever partial data is available.
- Surface an app-side warning when Rex context is degraded.

### P0.5 Financial read model is all-or-nothing

Evidence:
- [apps/mobile/lib/features/finance/application/financial_read_model_service.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/features/finance/application/financial_read_model_service.dart:44) loads accounts, transactions, budgets, categories, merchant rules, and statement imports with one `Future.wait`.

Why this matters:
- Dashboard, budgets, account pages, and Rex share this read model.
- One optional table failure can break every financial surface.

Required fix:
- Split required data from optional/enrichment data.
- Treat accounts, transactions, and categories as hard requirements.
- Treat budgets, statement imports, merchant rules, and audit enrichments as partial/degraded inputs with diagnostics.

## P1 - Product Logic And UX Risks

Status after P1 pass:
- P1.1 is implemented: the supported voice UX is now the inline chat voice call. Legacy `VoiceController`, `VoiceRecorderSheet`, and standalone `VoiceCallPage` were removed from the app code path.
- P1.2 is implemented for the backend timing contract: live transcript idle timing is explicit via `DEEPGRAM_LIVE_TRANSCRIPT_IDLE_MS` instead of a hidden hard-coded `3.4s` floor.
- P1.3 remains intentionally unchanged: barge-in stays disabled until echo-safe device tests exist.
- P1.4 is implemented: account display now has an explicit display model separating statement balance, monthly income, monthly spending, available-this-month, and net cash flow.
- P1.5 is implemented as a first split: the dashboard transaction explorer and dashboard cards were split out of `financial_dashboard_view.dart`, reducing the main file from roughly 2,430 lines to under 1,000.
- P1.6 is implemented as a first app-data boundary: `FinancialReadModelService` now owns an in-flight load boundary so simultaneous dashboard/account/budget/Rex requests share one read-model load instead of duplicating reads.

### P1.1 Voice has too many active/legacy paths

Original evidence:
- Inline voice call used `VoiceCallController`.
- Legacy `VoiceController`, `VoiceRecorderSheet`, and `VoiceCallPage` also existed.
- [apps/mobile/lib/rex/presentation/assistant_screen.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/rex/presentation/assistant_screen.dart:71) mapped the Voice tab to `ChatPage`, while `VoiceCallPage` was separate and unused in the primary tab flow.

Why this matters:
- Bugs can be fixed in one voice path while another dead/legacy path remains broken.
- Release commands and user testing become confusing.

Required fix:
- Pick one voice UX: inline voice inside chat.
- Delete or fully quarantine legacy `VoiceController`, `VoiceRecorderSheet`, and standalone `VoiceCallPage`.
- Add widget tests for starting/stopping voice from the Chat and Voice tabs.

### P1.2 Voice endpointing and latency are split across client and server

Evidence:
- Client endpoint timeouts live in `VoiceCallController`.
- Server live endpointing has a hard lower bound in `VoiceStreamSession` with `max(3.4, endpointing_seconds + 0.5)`.
- Deepgram endpointing is also configured by `DEEPGRAM_ENDPOINTING_MS`.

Why this matters:
- Small timing changes can cause "stuck listening," delayed replies, or premature endpointing.
- There is no single voice timing contract.

Required fix:
- Define one timing contract for listening-ready, speech-start, silence-end, STT final, first token, first audio, playback done.
- Log these timings in both app and backend.
- Make endpointing values env/config driven and covered by tests.

### P1.3 Barge-in is disabled because echo cancellation is not solved

Evidence:
- `voiceCallBargeInEnabledProvider` currently defaults to `false`.

Why this matters:
- This is correct for current stability, but it means "interrupt Rex by talking over him" is not available.
- If re-enabled without echo cancellation, Rex can hear his own TTS and cut himself off.

Required fix:
- Keep disabled until the audio session and recording path can prove echo-safe behavior on device.
- Re-enable only behind a real feature flag plus device tests.

### P1.4 Account balance vs cash flow is still conceptually fragile

Evidence:
- `dashboardBalanceForAccount` uses latest statement import balance or raw account balance.
- The accounts list was recently adjusted to show monthly cash flow because raw balance was `$0`.

Why this matters:
- Users can confuse statement balance, current account balance, monthly income/spend, and monthly net.
- Future UI changes can reintroduce `$0` account displays.

Required fix:
- Add a formal financial display contract:
  - `statementBalance`
  - `availableThisMonth`
  - `incomeThisMonth`
  - `spentThisMonth`
  - `netCashFlow`
- Use explicit labels everywhere.
- Add tests for account list display rows, not only read-model math.

### P1.5 Dashboard UI/controller file is too large

Evidence:
- `financial_dashboard_view.dart` is roughly 2,430 lines.

Why this matters:
- Filters, cards, import status, rows, categories, months, account-scope behavior, and budget navigation all live in one file.
- Small UI changes have large regression risk.

Required fix:
- Split into dashboard cards, transaction explorer, filter bar, empty/loading states, import actions, and scoped account actions.
- Add widget tests around the transaction explorer filters.

### P1.6 App state mixes ChangeNotifier, Riverpod, and direct service calls

Evidence:
- `AppUiDependencies` and `AppUiControllerBindings` bridge many services manually.
- Screens use `ListenableBuilder`.
- Assistant/voice uses Riverpod providers.

Why this matters:
- Refresh order and ownership are hard to reason about.
- Cold-start and post-import refresh bugs are likely to return.

Required fix:
- Keep the current service graph for now, but create one app data state boundary:
  - boot/config state
  - auth/profile state
  - financial read model state
  - assistant/voice state
- Avoid screens triggering independent duplicate loads when a shared read model already exists.

## P2 - Deploy, Maintenance, And Ship-Readiness

Status after P2 pass:
- P2.1 is implemented: `clarity-rex.service` is the canonical systemd unit in docs, `/ready`, and `scripts/vps_restart_rex_api.sh`.
- P2.2 is implemented: mobile examples match the production streaming-voice default, the recommended release command is explicit, and startup logs print active backend/voice config without secrets.
- P2.3 is documented: deployment bootstrap now prefers Python 3.12/3.11 for new VPS virtualenvs.
- P2.4 is implemented as a no-Docker workflow document with remote SQL drift checks.
- P2.5 is implemented as a manual device release checklist covering cold start, dashboard reload, account values, CSV import, filters, Rex chat, and 5-turn voice calls.

### P2.1 Deployment service naming is inconsistent

Evidence:
- Template service is `clarity-rex.service`.
- In manual VPS work, `rex-backend` has also been used.

Why this matters:
- Restarting the wrong service leaves production stale.
- Debugging becomes slower under pressure.

Required fix:
- Standardize on one systemd unit name.
- Update docs and commands to match the real VPS.
- Add `/ready` checks after every restart.

### P2.2 Voice/mobile env examples conflict

Original evidence:
- [apps/mobile/.env.example](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/.env.example:5) previously said `REX_STREAMING_VOICE_ENABLED=false`.
- [apps/mobile/lib/core/rex/rex_config.dart](/Users/pedromartins/Desktop/clarity-rex/apps/mobile/lib/core/rex/rex_config.dart:38) defaults streaming voice to `true`.

Why this matters:
- Testing with no `.env`, local `.env`, and `--dart-define` can produce different voice behavior.
- This already caused confusion with release commands.

Required fix:
- Make examples match production defaults.
- Keep one recommended release command.
- Add a startup debug line or settings readout for active voice mode.

### P2.3 Python runtime is aging

Evidence:
- Backend tests pass, but pytest warns Python 3.9 is end-of-life.

Why this matters:
- Google auth and other dependencies may stop supporting local/prod runtime combinations cleanly.

Required fix:
- Move backend local and VPS runtime to Python 3.11 or 3.12.
- Rebuild the VPS virtualenv from `requirements.txt`.

### P2.4 No-Docker Supabase workflow is undefined

Evidence:
- `supabase db diff --local` requires Docker and failed.
- Project direction is to avoid Docker.

Why this matters:
- Schema drift is already visible.
- Without Docker, the project needs a different repeatable migration verification path.

Required fix:
- Use remote SQL lint/audit queries and `supabase db push` as the primary workflow.
- Add a schema-drift checklist that does not require Docker.
- Keep migration SQL idempotent and manually auditable.

### P2.5 Device-level regression coverage is manual only

Evidence:
- Unit tests are strong, but there is no automated device test for:
  - app reinstall/cold start with production config
  - dashboard reload after app close
  - real microphone permission flow
  - real iOS audio session behavior
  - voice call through 5+ turns

Why this matters:
- The bugs we found recently were mostly device/state bugs, not pure unit-test bugs.

Required fix:
- Add a short manual release checklist for every device build.
- Add integration tests where practical.
- Log active backend URL, voice mode, and financial-read status in a developer-only diagnostics screen.

## Recommended Fix Sequence

1. Fix mobile release configuration: add dart-define Supabase config support and remove required ignored `.env` asset.
2. Make app boot recoverable: move startup hydration behind mounted UI with retry.
3. Fix Supabase schema drift: resolve `create_company_invite` and document the no-Docker schema workflow.
4. Make Rex financial context degraded-aware instead of silently empty.
5. Make `FinancialReadModelService` partial-load with diagnostics.
6. Consolidate voice to one supported path and delete/quarantine legacy voice surfaces.
7. Normalize voice timing config and logging.
8. Split `financial_dashboard_view.dart` into focused widgets/controllers.
9. Standardize deployment service naming and production restart checklist.
10. Add a device release checklist and diagnostics surface.

## Current Ship Readiness

The project is test-green and can build for iOS release locally. It is suitable for focused device testing, but I would not call it production-clean until the P0 items above are fixed. The top two practical risks are the ignored `.env` release dependency and silent financial-context fallback. Those are exactly the kinds of issues that make the app look correct in normal tests but confusing on a real phone after reinstall, logout, network trouble, or backend/schema drift.
