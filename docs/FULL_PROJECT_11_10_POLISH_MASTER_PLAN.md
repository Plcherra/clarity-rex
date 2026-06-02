# Master Plan: Full Project 11/10 Polish

Status: Draft

Last updated: June 2, 2026

## Purpose

Bring the Clarity + Rex codebase from test-green and functional to launch-clean, maintainable, and trustworthy under the Universal Code Architecture Standards. The goal is not cosmetic polish. The goal is to eliminate the highest-risk failure modes before Plaid integration and broader user testing: missing security policies, silent or fake action claims, oversized god-files, voice fragility, memory/review confusion, and unclear module contracts.

## Core Outcome

By the end of this plan:

- All user-scoped Supabase tables have explicit RLS and policy coverage.
- Rex never claims a durable action, reminder, memory, goal, or financial change happened unless backend execution confirms it.
- Voice, memory, accountability, and financial context are split into smaller modules with clear ownership.
- Plaid integration has a documented module boundary before code is added.
- Release checks cover backend, mobile, web, schema, and real-device smoke tests.

## Non-Goals

- This plan does not implement Plaid Link or transaction sync.
- This plan does not redesign the full app UI.
- This plan does not add a real reminder/calendar system; it prevents false claims and prepares a contract if reminders are added later.
- This plan does not refactor generated files such as `.freezed.dart`.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Automated tests | Backend, mobile, Flutter analyze, and web build pass | Strong baseline, but tests do not cover every production schema/security state |
| Supabase schema | `memory_confirmations` exists with FKs and indexes | P0: no RLS enable/policy found for this new user-scoped table |
| Voice auth/logging | WebSocket accepts Supabase access tokens in `access_token` query params | P0: reverse proxy/app logs can expose bearer tokens |
| Rex memory | Explicit confirmation records exist and recent contextual birthday flow is tested | Pending candidates remain noisy and can confuse the user |
| Rex voice | Functional but controller is 1,791 lines with streaming, lifecycle, native fallback, capture, playback, and state in one file | High regression risk and hard to debug device-only bugs |
| Rex brain/accountability | Powerful but oversized deterministic routing and accountability services | Hard to tune, hard to reason about launch behavior |
| Mobile finance/import | Strong tests, but several UI/data files exceed hard size limits | Maintainability risk before Plaid |
| Plaid | Legal/public docs exist; implementation boundary is not yet coded | Risk of placing Plaid sync into existing god-files |
| Docs/contracts | Universal standards and Rex architecture doc exist | Missing root `docs/CODEX_SYSTEM_INSTRUCTIONS.md`; root `docs/REX_SERVICES_ARCHITECTURE.md` path differs from requested location |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Security/schema | Every user table has RLS, policies, and schema tests/checklists | Prevents privacy/data isolation mistakes |
| Voice | One supported release path, split controller, explicit lifecycle state machine | Fewer crashes and easier device debugging |
| Memory | Natural confirmation, durable save, clean pending review, dedupe by topic | Rex feels reliable and human |
| Accountability/goals | Focused route/service modules and clearer context contract | Goals become useful without bloating chat |
| Plaid | Dedicated Plaid module contract and service skeleton | Avoids polluting chat/memory/finance god-files |
| Release | Single repeatable release checklist with rollback | Safer VPS and phone testing |

## Phase 1 - Fix Security And Schema Gaps

Goal: Make all user-scoped Rex tables secure by default and stop leaking voice access tokens through logged URLs.

Files to change:

- `supabase/migrations/000025_enable_memory_confirmations_rls.sql`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/app/auth/supabase_auth.py`
- `apps/mobile/lib/core/rex/rex_api_client.dart`
- `apps/mobile/lib/core/rex/rex_auth_headers.dart`
- `apps/mobile/lib/features/assistant/voice/data/streaming_voice_api.dart`
- `apps/mobile/test/rex_api_client_test.dart`
- `apps/mobile/test/streaming_voice_api_test.dart`
- `services/rex-api/tests/test_supabase_auth.py`
- `services/rex-api/tests/test_user_scoped_memory_service.py`
- `services/rex-api/tests/test_voice_stream_routes.py`
- `docs/clarity/rex_assistant_polish_plan/MEMORY_CONFIRMATION_CONTRACT.md`

Steps:

1. Add `alter table public.memory_confirmations enable row level security`.
2. Add a user-owned management policy matching the rest of Rex memory tables.
3. Move voice WebSocket auth away from query-param bearer tokens where feasible, or add a short-lived exchange token.
4. Redact access tokens from any remaining logs and update tests.
5. Add a migration/schema verification test or documented SQL check.
6. Confirm the VPS Supabase project has the migration applied.

Done looks like:

- `memory_confirmations` has RLS and user-scoped policies.
- Voice logs no longer expose Supabase JWTs.
- Existing confirmation flow still saves and confirms memory.

Manual test steps:

1. On phone, tell Rex: `My mom's birthday is June 18`.
2. Confirm with `yes`.
3. Check Memory saved view and Supabase row ownership.

Acceptance criteria:

- [x] RLS is enabled for `memory_confirmations`
- [x] Policy restricts access to `auth.uid() = user_id`
- [x] Voice WebSocket client no longer sends bearer tokens in URLs
- [x] Backend memory/auth/voice tests pass
- [x] Mobile auth/WebSocket tests pass
- [ ] Manual memory save test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `apps/mobile/lib/core/rex/rex_api_client.dart` | 92 | 88 | removed query-token WebSocket helper dependency |
| `apps/mobile/lib/core/rex/rex_auth_headers.dart` | 54 | 42 | removed URL-token WebSocket helper |
| `apps/mobile/lib/features/assistant/voice/data/streaming_voice_api.dart` | 197 | 205 | header-aware WebSocket connector added in place |
| `apps/mobile/test/rex_api_client_test.dart` | 127 | 134 | WebSocket token assertion changed to no-query-token |
| `apps/mobile/test/streaming_voice_api_test.dart` | 0 | 64 | new focused WebSocket header-auth test |
| `services/rex-api/app/auth/supabase_auth.py` | 136 | 134 | removed WebSocket query-token fallback |
| `services/rex-api/tests/test_supabase_auth.py` | 85 | 141 | added WebSocket header/query auth tests |
| `services/rex-api/tests/test_user_scoped_memory_service.py` | 159 | 178 | added migration/RLS verification |
| `supabase/migrations/000025_enable_memory_confirmations_rls.sql` | 0 | 12 | new migration |
| `docs/clarity/rex_assistant_polish_plan/MEMORY_CONFIRMATION_CONTRACT.md` | 225 | 235 | added RLS policy contract SQL |

## Phase 2 - Add Action Truth Contract

Goal: Make false action claims impossible across chat and voice unless execution metadata confirms success.

Files to change:

- `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/app/services/rex_brain_prompts.py`
- `services/rex-api/app/services/rex_brain_chat_service.py`
- `services/rex-api/app/services/clarity_action_parser.py`
- `services/rex-api/tests/test_chat_service.py`
- `services/rex-api/tests/test_rex_brain_prompts.py`

Steps:

1. Centralize action-truth rules into one focused policy/prompt contract.
2. Cover memory, goals, financial changes, reminders, notifications, and calendar events.
3. Add tests for forbidden claims without execution result.
4. Add response metadata when an action is proposed vs completed.

Done looks like:

- Rex can propose actions but cannot claim completion without a backend result.

Manual test steps:

1. Ask Rex to set a reminder.
2. Confirm Rex does not say it was set unless a real backend action exists.

Acceptance criteria:

- [ ] Text chat action-claim tests pass
- [ ] Voice action-claim tests pass
- [ ] No prompt duplicates drift from the shared contract

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/prompt_service.py` | 864 | target < 700 | `action_truth_policy.py` |

## Phase 3 - Split Mobile Voice Controller

Goal: Reduce `voice_call_controller.dart` from 1,791 lines into focused controller, streaming, lifecycle, playback, and fallback modules.

Files to change:

- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_lifecycle_coordinator.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_streaming_turn_runner.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_playback_coordinator.dart`
- `apps/mobile/test/voice_call_controller_test.dart`

Steps:

1. Extract provider wiring and dependencies into a small module.
2. Extract lifecycle/resume/background behavior.
3. Extract streaming WebSocket turn runner.
4. Extract playback and barge-in coordination.
5. Keep `voiceCallProvider` stable.

Done looks like:

- `voice_call_controller.dart` is below 500 lines.
- Streaming voice tests still pass.

Manual test steps:

1. Start voice mode on iPhone.
2. Speak, receive response, screenshot/minimize/resume.
3. Confirm no stuck `turn_in_progress` loop.

Acceptance criteria:

- [ ] `voice_call_controller.dart` < 500 lines
- [ ] `flutter analyze` passes
- [ ] `flutter test test/voice_call_controller_test.dart` passes
- [ ] Device voice smoke test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `voice_call_controller.dart` | 1791 | target 350-500 | lifecycle/streaming/playback modules |

## Phase 4 - Harden Voice Backend Session

Goal: Make voice streaming resilient to planning failures, duplicate turn starts, TTS failures, and network interruptions.

Files to change:

- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/tests/test_voice_stream_routes.py`
- `services/rex-api/tests/test_rex_brain_voice_integration.py`

Steps:

1. Split `voice_stream_session.py` into event loop, turn coordinator, and audio response writer.
2. Add typed error events for planning failure, TTS failure, and turn-in-progress.
3. Add privacy-safe structured logs.
4. Add tests for duplicate starts and planning fallback.

Done looks like:

- Voice backend errors degrade into user-visible retry states, not vague failure.

Manual test steps:

1. Trigger voice while backend is restarted.
2. Trigger voice with financial context present.
3. Confirm app recovers without stale transcript duplication.

Acceptance criteria:

- [ ] `voice_stream_session.py` < 500 lines
- [ ] Voice route tests pass
- [ ] Manual stress test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/voice_stream_session.py` | 614 | target < 450 | `voice_turn_coordinator.py`, `voice_audio_event_writer.py` |

## Phase 5 - Simplify Memory Candidate Review

Goal: Reduce pending-memory noise and make the Memory tab reflect what Rex knows vs what needs review.

Files to change:

- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_writer.py`
- `services/rex-api/app/services/memory_candidate_decision_formatter.py`
- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- `apps/mobile/lib/features/assistant/memory/presentation/widgets/*`

Steps:

1. Dedupe pending candidates by topic fingerprint and payload fingerprint.
2. Merge correction candidates that target the same fact.
3. Add explicit “saved memory” vs “review item” copy.
4. Add tests for the mom birthday and correction examples.

Done looks like:

- Pending count does not increase repeatedly for the same topic.

Manual test steps:

1. Tell Rex one birthday fact in chat.
2. Confirm it.
3. Ask the same thing again.
4. Confirm pending count does not grow.

Acceptance criteria:

- [ ] Duplicate pending candidate tests pass
- [ ] Memory tab copy no longer implies pending equals saved
- [ ] Manual memory review test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `memory_page.dart` | 483 | target < 400 | widgets only if needed |

## Phase 6 - Split Rex Brain Router

Goal: Reduce deterministic routing complexity and make launch-safe routing easier to tune.

Files to change:

- `services/rex-api/app/services/rex_brain.py`
- `services/rex-api/app/services/rex_model_router.py`
- `services/rex-api/tests/test_rex_brain.py`

Steps:

1. Extract term catalogs into `rex_brain_terms.py`.
2. Extract score calculators into `rex_brain_scoring.py`.
3. Extract decision builder into `rex_brain_decision_builder.py`.
4. Preserve public `RexThinkingRouter.route()`.

Done looks like:

- `rex_brain.py` contains orchestration only and route behavior is unchanged.

Manual test steps:

1. Ask fast/casual question.
2. Ask budget analysis question.
3. Ask Deep Think question.
4. Confirm expected routing metadata in logs/tests.

Acceptance criteria:

- [ ] `rex_brain.py` < 500 lines
- [ ] `test_rex_brain.py` passes
- [ ] Launch-safe routing remains default for production

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/rex_brain.py` | 1186 | target < 450 | terms/scoring/decision modules |

## Phase 7 - Split Accountability And Goals Services

Goal: Make goals/accountability reliable enough for daily use and safe to extend.

Files to change:

- `services/rex-api/app/services/accountability_service.py`
- `services/rex-api/app/routes/accountability.py`
- `services/rex-api/app/services/plan_intelligence_service.py`
- `services/rex-api/tests/test_accountability_service.py`
- `services/rex-api/tests/test_accountability_routes.py`

Steps:

1. Extract rule-risk detection.
2. Extract plan-drift detection.
3. Extract repeated-pattern detection.
4. Replace broad silent `except Exception` list loaders with diagnostic results.
5. Add module contract for accountability.

Done looks like:

- Accountability failures are visible and diagnosable.

Manual test steps:

1. Open Goals tab.
2. Confirm active goals, commitments, and risks load.
3. Simulate missing memory subresource and confirm degraded copy.

Acceptance criteria:

- [ ] `accountability_service.py` < 500 lines
- [ ] `routes/accountability.py` < 500 lines
- [ ] Route/service tests pass

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `accountability_service.py` | 1323 | target < 450 | risk detectors |
| `routes/accountability.py` | 698 | target < 400 | context loader/formatter |
| `plan_intelligence_service.py` | 1036 | target < 500 | scoring/classification modules |

## Phase 8 - Split Mobile Finance And Import God-Files

Goal: Prepare finance UI/data architecture for Plaid without adding Plaid to oversized CSV/dashboard files.

Files to change:

- `apps/mobile/lib/features/transactions/data/csv_import_service.dart`
- `apps/mobile/lib/features/transactions/data/csv_parser.dart`
- `apps/mobile/lib/features/finance/application/financial_read_model_service.dart`
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart`
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_transactions.dart`

Steps:

1. Extract CSV validation, preview, import persistence, and category repair.
2. Extract dashboard section widgets.
3. Extract transaction selection policy for Rex financial context.
4. Add Plaid-vs-CSV dedupe contract tests.

Done looks like:

- Plaid can be added through a focused sync service, not by editing CSV god-files.

Manual test steps:

1. Import CSV.
2. Review dashboard.
3. Ask Rex about transactions.

Acceptance criteria:

- [ ] Key finance/import files below hard limit or documented exception
- [ ] Existing finance tests pass
- [ ] Plaid insertion boundary documented

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `csv_import_service.dart` | 1037 | target < 500 | import steps/services |
| `financial_dashboard_view.dart` | 939 | target < 500 | section widgets |
| `financial_dashboard_transactions.dart` | 1001 | target < 500 | transaction list widgets |

## Phase 9 - Create Plaid Module Contract And ADR

Goal: Define Plaid boundaries before implementation begins.

Files to change:

- `docs/clarity/plaid/MODULE_CONTRACT_PLAID_SYNC.md`
- `docs/clarity/plaid/ADR_PLAID_SYNC_ARCHITECTURE.md`
- `services/rex-api/app/services/plaid_sync_service.py` (skeleton only if needed)

Steps:

1. Define link token, access token, account sync, transaction sync, dedupe, and deletion boundaries.
2. Define what mobile owns vs backend owns.
3. Define how Rex consumes Plaid-derived financial context.
4. Define rollback and data deletion behavior.

Done looks like:

- Plaid implementation can begin without touching Rex chat/memory internals.

Manual test steps:

1. Review contract before adding Plaid SDK.
2. Confirm privacy/data deletion obligations are covered.

Acceptance criteria:

- [ ] Module contract complete
- [ ] ADR accepted
- [ ] No Plaid code added to god-files

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| New docs | 0 | target concise | n/a |

## Phase 10 - Documentation And Release Gate Cleanup

Goal: Make project-level docs and release gates match the actual repo.

Files to change:

- `docs/CODEX_SYSTEM_INSTRUCTIONS.md`
- `docs/REX_SERVICES_ARCHITECTURE.md`
- `docs/clarity/release_checklists/*`
- `docs/deployment.md`

Steps:

1. Add or intentionally document missing root docs.
2. Either move or link the Rex architecture doc from its current nested path.
3. Create one launch gate checklist for backend, mobile, web, Supabase migrations, and device smoke tests.
4. Add known exceptions for generated files only.

Done looks like:

- Future audits find the requested docs in predictable locations.

Manual test steps:

1. Run the release checklist from a clean terminal.
2. Confirm commands match Mac/VPS reality.

Acceptance criteria:

- [ ] Docs paths are consistent
- [ ] Release gate has exact commands
- [ ] Known exceptions are documented

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `docs/clarity/rex_assistant_polish_plan/REX_SERVICES_ARCHITECTURE.md` | 48 | linked/copied | `docs/REX_SERVICES_ARCHITECTURE.md` |

## Verification Commands

Backend:

```bash
cd services/rex-api
python3 -m pytest tests -q
```

Frontend/mobile:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Web:

```bash
cd apps/web
npm run build
```

Schema:

```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('memory_confirmations', 'memory_candidates', 'long_term_memory');
```

Manual:

- iPhone release install.
- Text memory save/recall.
- Voice call with screenshot/minimize/resume.
- Memory pending approve/reject/edit.
- Dashboard and Rex financial context smoke test.

## Execution Order

1. Phase 1 - Fix Security And Schema Gaps
2. Phase 2 - Add Action Truth Contract
3. Phase 3 - Split Mobile Voice Controller
4. Phase 4 - Harden Voice Backend Session
5. Phase 5 - Simplify Memory Candidate Review
6. Phase 6 - Split Rex Brain Router
7. Phase 7 - Split Accountability And Goals Services
8. Phase 8 - Split Mobile Finance And Import God-Files
9. Phase 9 - Create Plaid Module Contract And ADR
10. Phase 10 - Documentation And Release Gate Cleanup

## Release Gate

Ship only when:

- [ ] Backend tests pass.
- [ ] Flutter analyze passes.
- [ ] Flutter tests pass.
- [ ] Web build passes.
- [ ] Supabase migrations are applied and RLS checks pass.
- [ ] No non-generated production file exceeds 500 lines without documented exception.
- [ ] Voice manual test passes on iPhone.
- [ ] Memory manual test passes on iPhone.
- [ ] Known risks are documented.
- [ ] VPS restart and rollback path are clear.
