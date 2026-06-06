# Master Plan: Full Project 11/10 Polish

Status: Superseded by the Clarity subsystem plan set in `docs/clarity/product/CLARITY_PREBUILD_FOUNDATION_MASTER_PLAN.md`.

This file is retained as historical execution context only. New product, Plaid,
usage tracking, UI, Assistant, and release work must use the current Clarity
plans under `docs/clarity/product/` and `docs/clarity/plaid/`.

Status: In progress - automated cleanup phases active; manual device testing deferred to final phase

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
| Supabase schema | `memory_confirmations` RLS migration and tests exist | Production Supabase application still needs final verification |
| Voice auth/logging | WebSocket query-token flow has been removed in code/tests | Manual log verification on VPS still deferred |
| Rex memory | Natural confirmation and direct-save paths are implemented and tested | Pending-candidate UX and chat-visible review state still need final cleanup/verification |
| Rex voice | Backend session and mobile controller have been split and tests pass | Long-form voice input, background behavior, and device audio route still need manual/device validation |
| Rex brain/accountability | Rex brain and accountability services and the accountability page were split into focused modules | Remaining context/prompt/accountability model files still exceed size targets |
| Mobile finance/import | CSV/import/read-model files were split and tests pass | Remaining budget/category/dashboard files exceed size targets |
| Plaid | Module contract, ADR, and fail-closed service skeleton exist | No Plaid Link/runtime sync is implemented yet |
| Docs/contracts | Universal standards exist; root docs are being normalized | Release gate and exception ledger must match repo reality before manual testing |

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

Status: Completed on June 3, 2026. Manual checklist execution remains deferred to Phase 24.

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

- [x] Docs paths are consistent
- [x] Release gate has exact commands
- [x] Known exceptions are documented

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `docs/CODEX_SYSTEM_INSTRUCTIONS.md` | 0 | 58 | new root audit instructions summary |
| `docs/REX_SERVICES_ARCHITECTURE.md` | 0 | 67 | new root Rex architecture guide |
| `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md` | 0 | 205 | new single release gate/checklist; file-size targets reconciled after Phase 18 page split |

## Phase 11 - Plan Ledger Reconciliation

Status: Completed on June 3, 2026 for automated/doc reconciliation. Manual release checks remain deferred to Phase 24.

Goal: Make the master plan itself an accurate operational source of truth.

Files to change:

- `docs/FULL_PROJECT_11_10_POLISH_MASTER_PLAN.md`
- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`

Steps:

1. Reconcile every phase status with the actual completed work.
2. Move stale "current state" risks into follow-up phases or remove them.
3. Record the latest automated verification commands and results.
4. Keep manual device checks explicitly deferred until the final phase.
5. Add a short "known not done" list so Plaid/runtime readiness is not overstated.

Done looks like:

- The plan no longer contradicts the repository.
- A future audit can tell exactly what is code-complete, test-complete, and manually unverified.

Manual test steps:

1. None. This is documentation reconciliation only.

Acceptance criteria:

- [x] Current state table reflects post-refactor reality
- [x] Phase statuses are no longer contradicted by the current-state table
- [x] Verification commands include latest pass/fail result section
- [x] Manual checks remain grouped in final phase

## Phase 12 - File Size Exception Ledger

Status: Completed and reconciled on June 3, 2026. Actual file cleanup continues in Phases 14-18 and follow-up targets.

Goal: Separate acceptable large/generated files from real god-files that still need work.

Files to change:

- `docs/FULL_PROJECT_11_10_POLISH_MASTER_PLAN.md`
- `docs/UNIVERSAL_CODE_ARCHITECTURE_STANDARDS.md`
- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`
- `docs/clarity/release_checklists/FILE_SIZE_EXCEPTION_LEDGER.md`

Steps:

1. Generate a production file-size report for backend, mobile, web, and Supabase functions.
2. Mark generated files as explicit exceptions.
3. Mark production files over 500 lines as follow-up cleanup targets.
4. Add a release-gate command for repeating the file-size check.
5. Require an exception note for any large file intentionally left as-is.

Done looks like:

- No large file is invisible.
- Every oversized production file either has a phase, an owner, or a documented exception.

Manual test steps:

1. None. This is static analysis and documentation.

Acceptance criteria:

- [x] Generated-file exceptions are documented
- [x] Oversized production files are listed with next action
- [x] File-size command exists in release checklist
- [x] Stale Phase 16 budget cleanup targets removed after successful budget refactor

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `docs/clarity/release_checklists/FILE_SIZE_EXCEPTION_LEDGER.md` | 0 | 47 | new file-size source of truth; reconciled after Phase 18 page split |
| `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md` | 199 | 205 | stale budget/accountability page targets removed; current oversized targets listed |
| `docs/UNIVERSAL_CODE_ARCHITECTURE_STANDARDS.md` | 414 | 416 | added project-ledger guidance |

## Phase 13 - Silent Failure And Exception Handling Audit

Status: Completed on June 3, 2026.

Goal: Stop broad exception handling from hiding user-visible failures.

Files to review/change:

- `services/rex-api/app/services/memory_post_turn_service.py`
- `services/rex-api/app/services/memory_extraction_service.py`
- `services/rex-api/app/services/memory_candidate_writer.py`
- `services/rex-api/app/services/memory_turn_confirmation_helpers.py`
- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/rex_brain_chat_service.py`
- `services/rex-api/app/routes/voice_stream.py`
- `services/rex-api/app/routes/accountability_context_loader.py`
- `docs/clarity/release_checklists/SILENT_FAILURE_EXCEPTION_LEDGER.md`

Steps:

1. List every broad `except Exception` in user-facing flows.
2. Classify each as allowed degraded fallback, telemetry-required failure, or bug.
3. Replace silent catches with structured logs and explicit degraded metadata.
4. Add tests for memory extraction failure, context failure, and voice failure recovery.
5. Document allowed circuit breakers.

Done looks like:

- Failures either recover visibly or are logged with enough context to debug.
- Memory does not silently pretend a save happened.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [x] Broad exception ledger complete
- [x] Silent memory failures produce explicit metadata/logging
- [x] Backend tests cover degraded memory/context behavior

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `docs/clarity/release_checklists/SILENT_FAILURE_EXCEPTION_LEDGER.md` | 0 | 63 | new exception handling ledger |
| `services/rex-api/app/services/memory_failure_reporting.py` | 0 | 48 | new privacy-safe degraded metadata/logging helper |
| `services/rex-api/app/services/memory_post_turn_service.py` | 279 | 336 | added explicit degraded post-turn/correction failure reporting |
| `services/rex-api/app/services/memory_candidate_writer.py` | 284 | 361 | added degraded candidate-write results and warning logs |
| `services/rex-api/app/services/memory_turn_service.py` | 500 | 426 | summary builders moved to `memory_turn_summaries.py` |
| `services/rex-api/app/services/memory_turn_summaries.py` | 0 | 111 | extracted simple memory summary builders |
| `services/rex-api/tests/test_memory_post_turn_service.py` | 144 | 198 | added correction/extraction failure coverage |
| `services/rex-api/tests/test_memory_turn_service.py` | 475 | 483 | added direct-save degraded metadata assertions |
| `services/rex-api/tests/test_memory_candidate_writer.py` | 202 | 233 | added candidate-create degraded result coverage |

## Phase 14 - Backend God-File Cleanup: Prompt And Context

Status: Completed on June 3, 2026.

Goal: Reduce the remaining backend orchestration files that still exceed standards.

Files to change:

- `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/app/services/rex_brain_context.py`
- New focused prompt/context helper files as needed
- Related backend tests

Steps:

1. Measure current line counts.
2. Split prompt assembly from prompt policy.
3. Split financial context selection from generic Rex brain context building.
4. Keep public APIs stable.
5. Add focused tests for moved behavior.
6. Re-run full backend tests.

Done looks like:

- `prompt_service.py` and `rex_brain_context.py` are under 500 lines or have documented exceptions.
- Moved files remain focused and under 500 lines.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [x] Line-count ledger complete
- [x] Backend tests pass
- [x] No public API breakage

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `services/rex-api/app/services/prompt_service.py` | 865 | 125 | constants, financial, accountability, structured, and memory/trim prompt mixins |
| `services/rex-api/app/services/prompt_constants.py` | 0 | 49 | new prompt policy/constants module |
| `services/rex-api/app/services/prompt_financial_context.py` | 0 | 215 | financial prompt section builder |
| `services/rex-api/app/services/prompt_accountability_context.py` | 0 | 133 | accountability/time/conversation prompt sections |
| `services/rex-api/app/services/prompt_structured_context.py` | 0 | 224 | structured memory prompt sections |
| `services/rex-api/app/services/prompt_memory_context.py` | 0 | 180 | long-term memory/file/trim prompt helpers |
| `services/rex-api/app/services/rex_brain_context.py` | 693 | 78 | facade preserving existing imports/API |
| `services/rex-api/app/services/rex_brain_context_models.py` | 0 | 131 | context dataclasses, budgets, constants |
| `services/rex-api/app/services/rex_brain_context_budgeting.py` | 0 | 217 | total budget enforcement |
| `services/rex-api/app/services/rex_brain_context_selection.py` | 0 | 188 | financial/memory/structured/accountability selection |
| `services/rex-api/app/services/rex_brain_context_utils.py` | 0 | 135 | sanitization, ranking, fitting utilities |
| `services/rex-api/tests/test_chat_service.py` | 399 | 406 | updated degraded metadata assertion |

## Phase 15 - Backend God-File Cleanup: Entity And Plan Services

Goal: Reduce backend entity/plan services without breaking memory, goals, or accountability.

Files to change:

- `services/rex-api/app/services/entity_service.py`
- `services/rex-api/app/services/plan_service.py`
- Related route/service tests

Steps:

1. Split repository/transport access from business decisions.
2. Extract formatting/normalization helpers.
3. Keep route-facing service methods stable.
4. Add tests around create/update/archive/list behavior.
5. Re-run full backend tests.

Done looks like:

- Entity and plan files move toward the 500-line standard.
- Goals and memory entity behavior remain stable.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] Line-count ledger complete
- [ ] Backend tests pass
- [ ] No route contract changes without documentation

## Phase 16 - Mobile Budget God-File Cleanup

Status: Completed on June 3, 2026. Manual budget/category smoke testing remains deferred to Phase 24.

Goal: Reduce the largest remaining mobile budget files.

Files to change:

- `apps/mobile/lib/features/budgets/presentation/category_management_sheet.dart`
- `apps/mobile/lib/features/budgets/presentation/budgets_viewmodel.dart`
- `apps/mobile/lib/features/budgets/presentation/budgets_screen.dart`
- Related mobile tests

Steps:

1. Extract category sheet sections into widgets.
2. Split budget view-model state from commands.
3. Keep providers and routes stable.
4. Add or update widget/view-model tests.
5. Run `flutter analyze` and targeted tests.

Done looks like:

- Budget files are meaningfully smaller and easier to maintain.
- No budget workflow is manually tested until final phase.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [x] Line-count ledger complete
- [x] Flutter analyze passes
- [x] Adjacent category/dashboard tests pass
- [ ] Dedicated budget widget tests added

Verification completed:

- `flutter analyze`
- `flutter test test/category_creation_normalization_test.dart test/dashboard_transaction_groups_test.dart`

Notes:

- This phase intentionally kept the existing route/widget entry points stable.
- The repo does not currently have dedicated budget widget tests; add them before changing budget editing behavior again.

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `category_management_sheet.dart` | 1175 | 485 | category section widgets, row widgets, dialog helper, pure helpers |
| `category_management_sheet_sections.dart` | 0 | 401 | bottom-sheet header/tabs/section rendering |
| `category_management_sheet_widgets.dart` | 0 | 476 | category rows, merchant-rule rows, audit rows, stats, empty state |
| `category_management_sheet_dialogs.dart` | 0 | 36 | category-name dialog |
| `category_management_sheet_helpers.dart` | 0 | 17 | manageable category and merchant-rule title helpers |
| `budgets_viewmodel.dart` | 826 | 348 | core budget state/draft orchestration only |
| `budgets_viewmodel_models.dart` | 0 | 59 | presentation DTOs |
| `budgets_viewmodel_periods.dart` | 0 | 429 | period/date helpers and date/month picker UI |
| `budgets_screen.dart` | 646 | 421 | screen state and command orchestration only |
| `budgets_screen_widgets.dart` | 0 | 356 | scaffold, loaded body, summary strip, notifier/data holder |

## Phase 17 - Mobile Transaction And Dashboard Cleanup

Goal: Reduce transaction/category/dashboard complexity before Plaid adds more data paths.

Files to change:

- `apps/mobile/lib/features/transactions/presentation/widgets/transaction_category_dropdown.dart`
- `apps/mobile/lib/features/transactions/application/category_workflow_service.dart`
- `apps/mobile/lib/features/dashboard/presentation/transaction_review_screen.dart`
- `apps/mobile/lib/features/dashboard/presentation/financial_dashboard_view.dart`
- Related tests

Steps:

1. Split category dropdown UI from data/search logic.
2. Extract transaction review sections into focused widgets.
3. Keep financial read-model contracts stable.
4. Add tests for category selection and dashboard grouping behavior.
5. Run mobile tests.

Done looks like:

- The dashboard/transaction files are ready for Plaid-driven data without becoming god-files.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] Line-count ledger complete
- [ ] Mobile tests pass
- [ ] No financial display regression in automated tests

## Phase 18 - Accountability UI And Model Cleanup

Status: Partially completed on June 3, 2026. Page split is done; model cleanup and manual testing remain deferred.

Goal: Reduce the remaining accountability mobile files and keep Goals/Rex behavior clear.

Files to change:

- `apps/mobile/lib/features/assistant/accountability/presentation/pages/accountability_page.dart`
- `apps/mobile/lib/features/assistant/accountability/data/accountability_models.dart`
- Related tests

Steps:

1. Split page sections into focused widgets.
2. Separate data DTOs from presentation helpers where practical.
3. Keep API parsing stable.
4. Add tests for empty/loading/error/success states.
5. Run mobile tests.

Done looks like:

- Accountability UI is maintainable and state-specific.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [x] Accountability page split into files under 500 lines
- [x] Flutter analyze passes
- [x] Assistant/accountability label tests pass
- [ ] Accountability model cleanup complete
- [ ] Dedicated empty/loading/error/success widget tests added
- [ ] State handling remains clear

Verification completed:

- `flutter analyze`
- `flutter test test/memory_label_test.dart test/assistant_navigation_test.dart`

Line-count ledger:

| File | Before | After | Moved To |
| --- | ---: | ---: | --- |
| `accountability_page.dart` | 1084 | 104 | page shell, refresh, provider wiring only |
| `accountability_page_sections.dart` | 0 | 210 | overview summary and top-level accountability sections |
| `accountability_page_tiles.dart` | 0 | 417 | signal/rule/commitment/plan/milestone/warning tiles |
| `accountability_page_shared.dart` | 0 | 360 | shared section chrome, chips, empty/loading/error states, helpers |
| `accountability_models.dart` | 690 | 690 | still oversized; model split remains in this phase |

## Phase 19 - Memory Review State Contract Cleanup

Goal: Ensure Rex, the Memory tab, and backend agree on saved vs pending vs correction state.

Files to review/change:

- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_writer.py`
- `services/rex-api/app/services/memory_post_turn_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `apps/mobile/lib/features/assistant/memory/**`
- Memory-related tests

Steps:

1. Define one source of truth for "pending review count".
2. Make chat answers about pending memory use the same backend source as the Memory tab.
3. Prevent duplicate pending candidates for the same topic/session.
4. Ensure direct saves do not also create pending candidates for the same fact.
5. Add tests for "mom birthday" and "pending memory count" after direct save.

Done looks like:

- Rex cannot say "no pending memories" while the Memory tab shows pending items from the same backend.
- Direct-save confirmations do not leave duplicate pending cards behind.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] Pending count source-of-truth test exists
- [ ] Direct-save/no-duplicate test exists
- [ ] Mobile Memory tab copy matches backend state

## Phase 20 - Voice Long-Form Input Reliability

Goal: Make voice better for long explanations, not just short commands.

Files to review/change:

- `apps/mobile/lib/features/assistant/voice/application/**`
- `apps/mobile/lib/features/assistant/voice/data/**`
- `services/rex-api/app/services/voice_stream_session.py`
- `services/rex-api/app/routes/voice_stream.py`
- Voice tests

Steps:

1. Audit voice idle timeout, silence detection, and transcript finalization.
2. Increase tolerance for long-form storytelling where safe.
3. Avoid cutting off the user mid-thought.
4. Improve "did not catch audio" behavior so it does not obscure chat.
5. Add tests for long transcript chunks and timeout boundaries.

Done looks like:

- Voice can accept longer turns without premature failure in automated/controller tests.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] Long-form voice unit/controller tests pass
- [ ] Error banner behavior is less disruptive
- [ ] Manual long-form phone test remains queued

## Phase 21 - Legacy And Dead Code Cleanup

Goal: Remove or clearly document old fallback paths and unused code.

Files to review/change:

- `apps/mobile/lib/core/rex/rex_config.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_native.dart`
- `apps/mobile/lib/features/assistant/voice/application/voice_call_controller_providers.dart`
- Any unused routes, services, widgets, and docs discovered by static scans

Steps:

1. Scan for unused imports, dead routes, and legacy flags.
2. Decide keep/remove/document for each legacy path.
3. Remove dead code only when tests prove it is unused.
4. Document emergency fallbacks that intentionally remain.
5. Run backend/mobile tests.

Done looks like:

- The repo has fewer unknown legacy branches.
- Remaining fallback code has a reason.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] Legacy voice fallback decision documented
- [ ] Dead code candidates listed
- [ ] Tests pass after removals

## Phase 22 - Dependency And Flutter Upgrade Risk Cleanup

Goal: Make the Flutter 3.44.1 upgrade intentional and avoid future build surprises.

Files to review/change:

- `apps/mobile/pubspec.yaml`
- `apps/mobile/pubspec.lock`
- `apps/mobile/ios/**`
- `apps/mobile/macos/**` if applicable
- Release docs

Steps:

1. Document the Flutter 3.44.1 baseline.
2. Decide whether Swift Package Manager generated files should be committed.
3. Track plugins without Swift Package Manager support.
4. Add a future-upgrade warning to the release gate.
5. Run `flutter analyze`, `flutter test`, and release-run smoke command when ready.

Done looks like:

- The Flutter upgrade state is deliberate, not accidental.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] Flutter baseline documented
- [ ] SwiftPM generated file decision documented
- [ ] Unsupported plugin warning documented

## Phase 23 - Supabase And VPS Release Readiness

Goal: Ensure backend deployment, migrations, and rollback commands are exact and repeatable.

Files to review/change:

- `docs/deployment.md`
- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`
- `scripts/vps_restart_rex_api.sh`
- Supabase migration docs/scripts

Steps:

1. Verify VPS pull/restart commands.
2. Add the Git SSH command fix for the VPS remote if needed.
3. Add Supabase migration verification SQL.
4. Add backend rollback commands.
5. Add log commands for memory/voice debugging.

Done looks like:

- Release and rollback can be executed from docs without guessing.

Manual test steps:

1. Deferred to final phase.

Acceptance criteria:

- [ ] VPS restart commands documented
- [ ] Rollback commands documented
- [ ] Supabase verification commands documented

## Phase 24 - Final Manual Device And Release Validation

Goal: Run the phone/VPS/manual validation only after all cleanup phases are complete.

Files to use:

- `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`
- `docs/clarity/device_release_checklist.md`
- `docs/deployment.md`

Steps:

1. Install release build on iPhone.
2. Test text memory direct save, recall, no duplicate pending cards, and pending count agreement.
3. Test voice short command, long-form explanation, screenshot/minimize/resume, earbuds/audio route, and interruption.
4. Test dashboard, CSV import, category review, budgets, and Rex financial context.
5. Test Goals/accountability.
6. Verify Supabase RLS/migrations in production.
7. Restart backend and verify `/ready`.
8. Document any release-blocking defects.

Done looks like:

- The app is ready for the next real beta/release cycle or has a short, concrete blocker list.

Manual test steps:

1. This phase is the manual test.

Acceptance criteria:

- [ ] iPhone release install passes
- [ ] Memory manual flow passes
- [ ] Voice manual flow passes
- [ ] Finance/import manual flow passes
- [ ] Goals/accountability manual flow passes
- [ ] Supabase production verification passes
- [ ] VPS restart and rollback path verified

## Verification Commands

Latest recorded automated baseline after Phases 1-9, before manual testing:

| Check | Result |
| --- | --- |
| Backend full tests | `623 passed` |
| Flutter analyze | `No issues found` |
| Flutter full tests | `134 passed` |
| Web build | Passed |
| File-size scan | Generated exception plus production cleanup targets remain |

Backend:

```bash
cd services/rex-api
.venv/bin/python -m pytest tests -q
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

File-size:

```bash
rg --files apps/mobile/lib services/rex-api/app apps/web/src supabase/functions \
  -g '*.dart' -g '*.py' -g '*.ts' -g '*.tsx' -g '*.astro' \
  | rg -v '\.(g|freezed)\.dart$' \
  | xargs wc -l \
  | awk '$1 > 500 && $2 != "total" {print $0}' \
  | sort -nr
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
11. Phase 11 - Plan Ledger Reconciliation
12. Phase 12 - File Size Exception Ledger
13. Phase 13 - Silent Failure And Exception Handling Audit
14. Phase 14 - Backend God-File Cleanup: Prompt And Context
15. Phase 15 - Backend God-File Cleanup: Entity And Plan Services
16. Phase 16 - Mobile Budget God-File Cleanup
17. Phase 17 - Mobile Transaction And Dashboard Cleanup
18. Phase 18 - Accountability UI And Model Cleanup
19. Phase 19 - Memory Review State Contract Cleanup
20. Phase 20 - Voice Long-Form Input Reliability
21. Phase 21 - Legacy And Dead Code Cleanup
22. Phase 22 - Dependency And Flutter Upgrade Risk Cleanup
23. Phase 23 - Supabase And VPS Release Readiness
24. Phase 24 - Final Manual Device And Release Validation

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

Detailed release commands live in `docs/clarity/release_checklists/FULL_PROJECT_RELEASE_GATE.md`.
