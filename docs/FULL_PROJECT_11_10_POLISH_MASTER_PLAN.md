# Master Plan: Full Project 11/10 Polish

Status: Draft

Last updated: June 3, 2026

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

- `services/rex-api/app/services/action_truth_policy.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/app/services/rex_brain_prompts.py`
- `services/rex-api/app/services/rex_brain_chat_service.py`
- `services/rex-api/app/services/clarity_action_parser.py`
- `services/rex-api/tests/test_chat_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`
- `services/rex-api/tests/test_rex_brain_prompts.py`
- `apps/mobile/lib/features/assistant/voice/data/audio_capture_service.dart`
- `apps/mobile/lib/features/assistant/voice/data/streaming_audio_capture_service.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`

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

- [x] Text chat action-claim tests pass
- [x] Voice action-claim tests pass
- [x] No prompt duplicates drift from the shared contract
- [x] Contextual "yes keep that in memory" saves a recent simple birthday fact directly
- [x] Contextual "no don't save that" rejects without durable memory
- [x] Mobile voice endpointing waits longer before cutting off longer speech
- [ ] Manual phone test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/action_truth_policy.py` | 0 | 9 | new shared action truth prompt contract |
| `services/rex-api/app/services/memory_intent_service.py` | 429 | 500 | contextual save/reject detection added in place |
| `services/rex-api/app/services/memory_turn_service.py` | 487 | 500 | contextual direct save/reject branch added in place |
| `services/rex-api/app/services/prompt_service.py` | 864 | 865 | imports shared truth policy; full split remains future cleanup |
| `services/rex-api/app/services/rex_brain_prompts.py` | 203 | 203 | imports shared truth policy; removed duplicate reminder rule |
| `services/rex-api/tests/test_chat_simple_memory_flow.py` | 276 | 353 | added contextual memory save/reject regression tests |
| `apps/mobile/lib/features/assistant/voice/data/audio_capture_service.dart` | 238 | 238 | longer default post-speech silence |
| `apps/mobile/lib/features/assistant/voice/data/streaming_audio_capture_service.dart` | 314 | 314 | longer streaming post-speech silence |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart` | 1791 | 409 | transcript idle timeout increased; Phase 3 split completed |

## Phase 3 - Split Mobile Voice Controller

Status: Completed on June 3, 2026. Manual device smoke test remains deferred
until the release/device test pass.

Goal: Reduce `voice_call_controller.dart` from 1,791 lines into focused controller, streaming, lifecycle, playback, and fallback modules.

Files to change:

- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_providers.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_commands.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_lifecycle.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_streaming.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_native.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_timers.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_dependencies.dart`
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

- [x] `voice_call_controller.dart` < 500 lines
- [x] `flutter analyze` passes
- [x] `flutter test test/voice_call_controller_test.dart` passes
- [ ] Device voice smoke test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller.dart` | 1791 | 409 | provider wiring and helper methods moved out |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_providers.dart` | 0 | 113 | provider wiring and voice timeout providers |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_commands.dart` | 0 | 180 | internal transcript/interrupt/reset commands |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_lifecycle.dart` | 0 | 65 | lifecycle resume and background restart handling |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_streaming.dart` | 0 | 445 | streaming WebSocket turns and cloud fallback path |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_native.dart` | 0 | 202 | native iOS voice session handling |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_timers.dart` | 0 | 337 | endpointing, no-speech, thinking timeout, barge-in helpers |
| `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_dependencies.dart` | 0 | 95 | cached service dependency getters |

## Phase 4 - Harden Voice Backend Session

Status: Completed on June 3, 2026. Manual stress/device test remains deferred
to the release gate.

Goal: Make voice streaming resilient to planning failures, duplicate turn starts, TTS failures, and network interruptions.

Files to change:

- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/services/voice_stream_config.py`
- `services/rex-api/app/services/voice_stream_response_writer.py`
- `services/rex-api/app/services/voice_stream_live_transcription.py`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/tests/test_voice_stream_routes.py`
- `services/rex-api/tests/test_voice_stream_reliability.py`
- `services/rex-api/tests/voice_stream_fakes.py`
- `services/rex-api/tests/test_rex_brain_voice_integration.py`

Steps:

1. Split `voice_stream_session.py` into event loop, turn coordinator, and audio response writer.
2. Add typed error events for planning failure, TTS failure, and turn-in-progress.
3. Add privacy-safe structured logs.
4. Add tests for duplicate starts and planning fallback.

Done looks like:

- Voice backend errors degrade into user-visible retry states, not vague failure.
- Voice session orchestration, response audio writing, live transcription, and
  voice token configuration are separate focused modules.

Manual test steps:

1. Trigger voice while backend is restarted.
2. Trigger voice with financial context present.
3. Confirm app recovers without stale transcript duplication.

Acceptance criteria:

- [x] `voice_stream_session.py` < 500 lines
- [x] Voice route tests pass
- [x] Duplicate turn starts return `turn_in_progress`
- [x] Planning/TTS/transcription failures return typed error codes
- [ ] Manual stress test passes during final release gate

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/voice_stream_session.py` | 614 | 385 | response writing and live transcription moved out |
| `services/rex-api/app/services/voice_stream_config.py` | 0 | 28 | voice response prompt/token constants |
| `services/rex-api/app/services/voice_stream_response_writer.py` | 0 | 166 | chat streaming, TTS audio chunks, transcript events |
| `services/rex-api/app/services/voice_stream_live_transcription.py` | 0 | 95 | live transcription lifecycle and endpointing |
| `services/rex-api/tests/test_voice_stream_routes.py` | 510 | 321 | fakes moved to `voice_stream_fakes.py` |
| `services/rex-api/tests/voice_stream_fakes.py` | 0 | 208 | reusable voice stream fakes/helpers |
| `services/rex-api/tests/test_voice_stream_reliability.py` | 0 | 101 | duplicate turn and typed error regression tests |

## Phase 5 - Simplify Memory Candidate Review

Status: Backend source-of-truth pass completed on June 3, 2026. Mobile copy polish
and final device smoke test remain deferred to the release gate.

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

- [x] Duplicate pending candidate tests pass
- [ ] Memory tab copy no longer implies pending equals saved
- [ ] Manual memory review test passes during final release gate

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `memory_page.dart` | 483 | target < 400 | widgets only if needed |
| `memory_candidate_writer.py` | 285 | 284 | global duplicate lookup |
| `memory_candidate_decision_service.py` | 349 | 357 | global review intent fallback |
| `test_memory_candidate_phase5_reliability.py` | 0 | 229 | new focused regression suite |

## Phase 6 - Split Rex Brain Router

Status: Completed on June 3, 2026.

Goal: Reduce deterministic routing complexity and make launch-safe routing easier to tune.

Files to change:

- `services/rex-api/app/services/rex_brain.py`
- `services/rex-api/app/services/rex_model_router.py`
- `services/rex-api/tests/test_rex_brain.py`
- `services/rex-api/app/services/rex_brain_config.py`
- `services/rex-api/app/services/rex_brain_terms.py`
- `services/rex-api/app/services/rex_brain_scoring.py`
- `services/rex-api/app/services/rex_brain_decision_builder.py`
- `services/rex-api/tests/test_rex_brain_capabilities.py`
- `services/rex-api/tests/test_rex_brain_contracts.py`

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

- [x] `rex_brain.py` < 500 lines
- [x] `test_rex_brain.py` passes
- [x] Launch-safe routing remains default for production

Verification completed:

- `.venv/bin/python -m py_compile app/services/rex_brain.py app/services/rex_brain_config.py app/services/rex_brain_terms.py app/services/rex_brain_scoring.py app/services/rex_brain_decision_builder.py app/services/rex_model_router.py`
- `.venv/bin/python -m pytest tests/test_rex_brain.py tests/test_rex_brain_capabilities.py tests/test_rex_brain_contracts.py tests/test_rex_brain_observability.py tests/test_rex_model_router.py tests/test_rex_brain_voice_integration.py -q`
- `.venv/bin/python -m pytest tests/ -q`

Notes:

- Public imports from `app.services.rex_brain` remain stable for `RexBrain`, `RexBrainInput`, `RexThinkingRouter`, and `RexThinkingRouterConfig`.
- `RexModelRouter` already preserves launch-safe rollout gating through the `launch_safe` stage and aliases for `mvp`, `launch`, `production`, and `prod`.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/rex_brain.py` | 1186 | 101 | facade/orchestration only |
| `services/rex-api/app/services/rex_brain_config.py` | 0 | 9 | router config |
| `services/rex-api/app/services/rex_brain_terms.py` | 0 | 477 | deterministic term catalogs |
| `services/rex-api/app/services/rex_brain_scoring.py` | 0 | 307 | score calculation and intent extraction |
| `services/rex-api/app/services/rex_brain_decision_builder.py` | 0 | 407 | layer/model/context decision construction |
| `services/rex-api/tests/test_rex_brain.py` | 876 | 417 | core routing examples |
| `services/rex-api/tests/test_rex_brain_capabilities.py` | 0 | 325 | research/proactive/planning/action routing |
| `services/rex-api/tests/test_rex_brain_contracts.py` | 0 | 143 | metadata and pending action contracts |

## Phase 7 - Split Accountability And Goals Services

Status: Completed on June 2, 2026. Manual Goals/Assistant device QA remains
deferred to the release gate.

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

- [x] `accountability_service.py` < 500 lines
- [x] `routes/accountability.py` < 500 lines
- [x] Route/service tests pass
- [x] Accountability module contract added

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `accountability_service.py` | 1323 | 95 | detector modules |
| `accountability_shared.py` | 0 | 283 | shared constants, time/date/text helpers |
| `accountability_rule_risk.py` | 0 | 141 | rule-risk detection |
| `accountability_commitment_detector.py` | 0 | 237 | commitment signals |
| `accountability_plan_drift.py` | 0 | 342 | plan and milestone signals |
| `accountability_pattern_detector.py` | 0 | 187 | repeated-pattern signals |
| `routes/accountability.py` | 698 | 138 | context loader/filter/overview modules |
| `routes/accountability_context_loader.py` | 0 | 183 | context loading and loader diagnostics |
| `routes/accountability_signal_filters.py` | 0 | 62 | analyze wrapper and filters |
| `routes/accountability_overview_builder.py` | 0 | 419 | overview buckets and warnings |
| `plan_intelligence_service.py` | 1036 | 471 | models/rules/text/payload modules |
| `plan_intelligence_models.py` | 0 | 39 | plan intelligence contracts/constants |
| `plan_intelligence_text.py` | 0 | 130 | text/context helpers |
| `plan_intelligence_rules.py` | 0 | 402 | plan scoring and classification heuristics |
| `plan_intelligence_payloads.py` | 0 | 156 | payload builders |
| `ACCOUNTABILITY_MODULE_CONTRACT.md` | 0 | 178 | module boundaries and test contract |

## Phase 8 - Split Mobile Finance And Import God-Files

Status: Completed on June 3, 2026. Manual device/import smoke test remains
deferred to the release gate.

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

- [x] Key finance/import files below hard limit or documented exception
- [x] Existing finance tests pass
- [x] Plaid insertion boundary documented
- [ ] Manual CSV import/dashboard/Rex finance smoke test passes

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `csv_import_service.dart` | 1037 | 493 | import models, categorizer, and helpers |
| `csv_import_models.dart` | 0 | 146 | import result/progress/preview contracts |
| `csv_import_categorizer.dart` | 0 | 414 | learned rules, AI category suggestions, fallback categories |
| `csv_import_helpers.dart` | 0 | 45 | account stamping, spend reference, date range helpers |
| `csv_parser.dart` | 798 | 165 | parser models, layout detection, value parsing |
| `csv_parser_models.dart` | 0 | 58 | parse result and diagnostics contracts |
| `csv_parser_layout.dart` | 0 | 456 | header detection, table inference, column mapping |
| `csv_parser_values.dart` | 0 | 126 | money/date parsing helpers |
| `financial_dashboard_view.dart` | 939 | 339 | shell, summary sections, and card widgets |
| `financial_dashboard_shell.dart` | 0 | 301 | dashboard scroll/loading/upload shell |
| `financial_dashboard_summary_sections.dart` | 0 | 306 | cash-flow and monthly summary sections |
| `financial_dashboard_transactions.dart` | 1001 | 390 | transaction controls and list widgets |
| `financial_dashboard_transaction_controls.dart` | 0 | 266 | mode picker, search field, filter controls |
| `financial_dashboard_transaction_lists.dart` | 0 | 347 | grouped/inline transaction lists |
| `financial_read_model_service.dart` | 718 | 149 | read model contract and helpers |
| `financial_read_model.dart` | 0 | 466 | financial read model data/derived totals |
| `financial_read_model_helpers.dart` | 0 | 114 | budget identity, import comparison, date helpers |
| `financial_context_service.dart` | 539 | 334 | Rex transaction selection policy |
| `rex_financial_transaction_policy.dart` | 0 | 205 | Rex transaction context/drilldown selection |
| `financial_integration_contracts_test.dart` | 427 | 447 | Plaid-vs-CSV dedupe fingerprint contract |
| `PLAID_CSV_IMPORT_BOUNDARY.md` | 0 | 62 | Plaid insertion boundary and dedupe contract |

## Phase 9 - Create Plaid Module Contract And ADR

Status: Completed on June 3, 2026. No Plaid SDK/runtime integration added.

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

- [x] Module contract complete
- [x] ADR accepted
- [x] No Plaid code added to god-files
- [x] Fail-closed backend skeleton added with contract tests

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `MODULE_CONTRACT_PLAID_SYNC.md` | 0 | 186 | new Plaid module contract |
| `ADR_PLAID_SYNC_ARCHITECTURE.md` | 0 | 134 | new accepted architecture decision |
| `plaid_sync_service.py` | 0 | 147 | fail-closed Plaid service skeleton |
| `test_plaid_sync_service_contract.py` | 0 | 44 | fail-closed service contract tests |

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
3. Phase 5 - Simplify Memory Candidate Review
4. Phase 4 - Harden Voice Backend Session
5. Phase 3 - Split Mobile Voice Controller
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
