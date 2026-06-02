# Rex Memory Refactor Master Plan

Status: Draft for execution
Date: June 1, 2026

## Purpose

Refactor the Rex memory system without breaking the app. The goal is to make memory reliable, simple to reason about, and easier to extend while preserving the current working behavior: natural memory confirmation, durable saves, pending candidate review, saved-memory browsing, and recall in both text and voice.

This plan focuses on large files and high-risk coupling. Each phase should be completed, tested, and committed before starting the next phase.

## Current Big Files To Refactor

| File | Approx. lines | Problem | Refactor target |
| --- | ---: | --- | --- |
| `services/rex-api/app/services/chat_service.py` | 498 after guardrail cleanup, down from 2,225 | Chat orchestration still owns text/streaming flow; turn prep, memory turns, candidates, actions, Rex Brain glue, prompt context, corrections, and extraction summaries are extracted. | Mark complete; keep below 500 as Plaid/Stripe work begins. |
| `services/rex-api/app/services/chat_context_service.py` | 218 | New extracted service for prompt context gathering, memory/profile merge, structured context fallback, time context, accountability signals, and prompt message building. | Keep as the focused home for context assembly; do not let it grow past 500 lines. |
| `services/rex-api/app/services/chat_turn_context.py` | 145 | New extracted service for file text, conversation validation/creation, prompt context fetch, accountability signals, and user message persistence. | Keep duplicated send/stream setup out of `chat_service.py`. |
| `services/rex-api/app/services/memory_post_turn_service.py` | 245 | New extracted service for memory correction candidates, correction prompts, memory-change summaries, and best-effort extraction scheduling. | Keep as the focused home for post-response memory side effects; do not let it grow past 500 lines. |
| `services/rex-api/app/services/rex_brain_chat_service.py` | 434 | New extracted service for Rex Brain chat planning, routing metadata, model kwargs, and chat contract application. | Keep as the focused home for Rex Brain chat glue; do not let it grow past 500 lines. |
| `services/rex-api/app/services/memory_turn_service.py` | 275 | New extracted service for simple memory turn orchestration. | Keep as the focused home for natural confirmation, direct durable save/reject/failure summaries, and public message marker stripping. |
| `services/rex-api/app/services/memory_candidate_decision_service.py` | 289 | Extracted service for pending memory candidate decisions. | Keep as the focused home for approve/reject/edit chat commands and high-risk safeguards. |
| `services/rex-api/app/services/memory_candidate_decision_formatter.py` | 264 | Extracted formatter for pending candidate response payloads. | Keep as the focused home for candidate cards, payload previews, verification summaries, and decision summaries. |
| `services/rex-api/app/services/clarity_action_parser.py` | 134 | Extracted parser/filter for `clarity_action` blocks. | Keep as the focused home for parsing proposed Clarity actions and hiding action blocks from streams. |
| `services/rex-api/app/services/memory_extraction_service.py` | 402 after active refactor, down from 1,879 | Extraction orchestration facade. Prompt, parsing, structured normalization, reference resolution, and candidate writing have been extracted; unused correction-upsert dead code was removed. | Mark complete unless new behavior requires more extraction work. |
| `services/rex-api/app/services/memory_extraction_prompt.py` | 175 | Extracted constant for the AI extraction prompt. | Keep prompt text out of service orchestration. |
| `services/rex-api/app/services/memory_extraction_parser.py` | 127 | Extracted parser for turn payloads, JSON extraction, structured section filtering, long-term memory candidate normalization, and noisy-content detection. | Keep AI payload parsing independently testable. |
| `services/rex-api/app/services/memory_structured_candidate_normalizer.py` | 327 | Extracted structured candidate normalization for entities, events, rules, plans, milestones, and commitments. | Keep validation/payload shaping out of extraction orchestration. |
| `services/rex-api/app/services/memory_reference_resolver.py` | 164 | Extracted entity and plan reference resolution. | Keep existing-record lookup and key caching out of extraction orchestration. |
| `services/rex-api/app/services/memory_candidate_writer.py` | 174 | Extracted pending candidate creation, risk mapping, brain metadata merging, and discipline decision payload handling. | Keep candidate persistence out of extraction orchestration. |
| `services/rex-api/app/services/memory_service.py` | 493 after final Phase 5 pass, down from 1,706 | Thin compatibility facade; transport, storage repositories, retrieval orchestration, ranking, structured CRUD, and candidate/correction CRUD are extracted. | Mark complete unless a future contract change requires more work. |
| `services/rex-api/app/services/memory_retrieval_service.py` | 210 | Extracted relevant-memory retrieval and structured-memory context assembly. | Keep retrieval orchestration out of `memory_service.py`. |
| `services/rex-api/app/services/supabase_memory_transport.py` | 185 | Extracted Supabase request, auth/scoping, generic record helpers, and protected-field filtering. | Keep transport details out of `memory_service.py`. |
| `services/rex-api/app/services/conversation_repository.py` / `long_term_memory_repository.py` | 166 / 199 | Extracted conversation/message/voice-turn storage and long-term memory CRUD. | Keep storage details out of `memory_service.py`. |
| `services/rex-api/app/services/memory_retrieval_ranker.py` | 471 | Extracted retrieval scoring, token expansion, structured ranking, related-record merge, recency scoring, and stale correction filtering. | Keep under 500 lines; split concept expansion or correction filtering if it grows. |
| `services/rex-api/app/services/structured_memory_repository.py` | 300 | Extracted structured entities, events, rules, plans, milestones, and commitments CRUD. | Keep as structured table repository facade. |
| `services/rex-api/app/services/memory_candidate_repository.py` | 212 | Extracted pending candidate and memory correction CRUD plus validation. | Keep candidate/correction persistence out of `memory_service.py`. |
| `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart` | 483 after Phase 8, down from 2,196 | Page shell plus state/action wiring; dialogs, archive prompts, filters, headers, pending review widgets, saved sections, tiles, and chips are extracted. | Mark complete unless action wiring needs its own coordinator. |
| `apps/mobile/lib/features/assistant/memory/presentation/widgets/memory_edit_dialogs.dart` / `memory_pending_review_widgets.dart` | 436 / 351 | Extracted edit dialogs and pending review UI. | Keep both under 500 lines. |
| `apps/mobile/lib/features/assistant/memory/presentation/widgets/saved_memory_tiles.dart` / `saved_memory_group_list.dart` | 349 / 161 | Extracted saved-memory tiles and group assembly. | Keep saved-memory presentation split by responsibility. |
| `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart` | 111 after Phase 9, down from 647 | Provider/state/controller shell remain; read, action, and error logic moved to focused part files at 164/344/40 lines. | Mark complete; largest controller part stays below 500. |
| `apps/mobile/lib/features/assistant/memory/data/memory_api.dart` | 161 after Phase 9, down from 411 | Constructor, provider, and shared HTTP transport remain; saved, structured, and candidate endpoints moved to focused part files at 68/171/54 lines. | Mark complete; public `MemoryApi` and provider stayed stable. |
| `services/rex-api/tests/test_chat_service.py` | 399 after Phase 10, down from 2,137 | Core smoke, action proposal, correction/extraction, streaming, AI failure, and Supabase config tests remain. | Mark complete unless we want tiny single-purpose files. |
| `services/rex-api/tests/chat_service_fakes.py` / focused chat test files | 390 / 185-424 | Extracted shared fakes plus Rex Brain, candidate decision, simple memory, and prompt context suites. | Keep all below 500 lines. |
| `services/rex-api/tests/test_memory_extraction.py` | 461 after Phase 10, down from 1,396 | Core parser/dedupe/filter tests remain; fakes, correction tests, and structured candidate tests moved to focused files at 307/390/248 lines. | Mark complete unless we want smaller edge-case suites. |
| `apps/mobile/test/memory_page_test.dart` | 69 after Phase 10, down from 588 | Saved overview/filter tests remain; pending, archive/error, and shared fake helpers moved to focused files at 118/93/279 lines. | Mark complete; all memory page test files stay below 500. |

## Refactor Rules
- Do one phase at a time.
- Each phase has one active target file. Do not move to the next large file until the active target is reduced by at least 150-250 lines where practical, or explicitly marked as finished.
- Do not create a replacement god file. New extracted production files should stay below 500 lines unless there is a written exception.
- Keep public API responses compatible unless the phase explicitly changes a contract.
- Add or move tests before moving complex logic.
- Prefer extracting pure helpers first, then services, then route/controller changes.
- Do not combine backend and mobile refactors in the same phase unless the contract requires it.
- Run the focused tests after each phase, then the full Rex API suite before deployment.
- Manual phone testing is last, after automated tests pass.

## Phase 1 - Stabilize The New Simple Memory Path

Status: Complete
Primary files:

- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/tests/test_chat_service.py`
- `services/rex-api/tests/test_conversation_routes.py`

Goal: make the natural confirmation path explicit and safe before deeper refactors.

Steps:

1. Add direct unit tests for `MemoryIntentService` instead of testing all intent behavior through `ChatService`.
2. Cover birthday detection, explicit `remember that`, confirmation replies, rejection replies, date normalization, and marker stripping.
3. Move simple-memory summary payload tests out of broad chat tests if they become noisy.
4. Confirm internal confirmation markers never leak through chat, voice, conversation list, or conversation messages.
5. Add tests for non-confirmation replies after Rex asks to save a memory.
6. Document the temporary marker-based confirmation storage and its eventual replacement path.
7. Run focused backend tests.
8. Run the full Rex API suite.

Acceptance criteria:

- Simple memory behavior has its own service-level tests.
- `ChatService` tests only verify integration, not every detector edge case.
- Hidden markers never appear in user-facing route responses.
- Existing candidate approval behavior still works.

Implementation notes:

- The first implementation stores pending simple-memory confirmation state as an internal marker appended to Rex's assistant confirmation message.
- This marker is stripped at all user-facing boundaries: chat responses, voice streaming done payloads, conversation list previews, conversation messages, and prompt context sent back into Rex.
- This is intentionally temporary. Phase 2 may keep it behind `MemoryTurnService`; a later storage phase can replace it with a dedicated confirmation table if the flow needs longer-lived or cross-device pending state.
- The marker should never be used for complex or high-risk memory changes. Those should remain pending candidates until explicitly approved.
- Completed Phase 1 coverage adds direct `MemoryIntentService` tests plus a chat integration test for non-confirmation replies after Rex asks to save a simple memory.

## Phase 2 - Extract Memory Turn Orchestration From `chat_service.py`

Status: Complete

Primary files:

- `services/rex-api/app/services/chat_service.py`
- New: `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/tests/test_chat_service.py`
- New: `services/rex-api/tests/test_memory_turn_service.py`

Goal: remove simple memory confirmation/save/reject logic from `ChatService`.

Steps:

1. Create `MemoryTurnService` for early memory-turn decisions.
2. Move `_handle_simple_memory_turn`, `_save_confirmed_simple_memory`, and simple-memory summary builders into the new service.
3. Keep `ChatService` responsible only for calling the memory turn service before candidate/AI flow.
4. Define a small return object or dict contract for memory turn results.
5. Keep streaming and non-streaming behavior identical by sharing the same service.
6. Add tests around the new service using fake memory storage.
7. Keep existing `ChatService` tests as integration coverage.
8. Run backend tests before moving to candidate logic.

Acceptance criteria:

- `chat_service.py` loses the simple-memory helper block.
- Text and voice still use the same simple-memory path.
- New tests prove direct durable save works without invoking AI or extraction.
- No mobile changes required.

Refactor ledger:

- `services/rex-api/app/services/chat_service.py`
  - Before Phase 2: 2,225 lines.
  - After simple-memory extraction: 2,015 lines.
  - After candidate-decision extraction: 1,507 lines.
  - After splitting candidate formatter and clarity action parsing: 1,382 lines.
  - After extracting Rex Brain chat glue: 982 lines.
  - After extracting prompt/context assembly: 802 lines.
  - After extracting post-turn memory correction/extraction work: 595 lines.
  - Total Phase 2 reduction so far: 1,630 lines.
- New file: `services/rex-api/app/services/memory_turn_service.py`
  - After Phase 2: 275 lines.
  - Owns the extracted simple-memory turn flow.
- New file: `services/rex-api/app/services/memory_candidate_decision_service.py`
  - After Phase 2 continuation: 289 lines.
  - Owns extracted pending candidate decision behavior.
- New file: `services/rex-api/app/services/memory_candidate_decision_formatter.py`
  - After Phase 2 continuation: 264 lines.
  - Owns extracted pending candidate cards and decision payload formatting.
- New file: `services/rex-api/app/services/clarity_action_parser.py`
  - After Phase 2 continuation: 134 lines.
  - Owns extracted clarity action proposal parsing and stream filtering.
- New file: `services/rex-api/app/services/rex_brain_chat_service.py`
  - After Phase 2 continuation: 434 lines.
  - Owns extracted Rex Brain chat planning, observability logging, model kwargs, memory metadata, prompt context limits, and chat contract application.
  - This file is intentionally below the 500-line guardrail so the refactor does not create a replacement god file.
- New file: `services/rex-api/app/services/chat_context_service.py`
  - After Phase 2 continuation: 218 lines.
  - Owns prompt context gathering, profile-memory merge, structured context fallback, time context, accountability signals, and prompt message building.
- New file: `services/rex-api/app/services/memory_post_turn_service.py`
  - After Phase 2 continuation: 245 lines.
  - Owns correction candidate creation, correction prompts, extraction blocking checks, memory-change summaries, best-effort extraction, and background extraction scheduling.
- New test file: `services/rex-api/tests/test_memory_turn_service.py`
  - After Phase 2: 249 lines.
  - Owns focused tests for the extracted service.
- New test file: `services/rex-api/tests/test_memory_candidate_decision_service.py`
  - After Phase 2 continuation: 254 lines.
  - Owns focused tests for pending candidate chat decisions.
- New test file: `services/rex-api/tests/test_clarity_action_parser.py`
  - After Phase 2 continuation: 86 lines.
  - Owns focused tests for clarity action parsing and stream filtering.
- New test file: `services/rex-api/tests/test_chat_context_service.py`
  - After Phase 2 continuation: 106 lines.
  - Owns focused tests for prompt context fetching, memory dedupe, structured context fallback, and accountability signal delegation.
- New test file: `services/rex-api/tests/test_memory_post_turn_service.py`
  - After Phase 2 continuation: 107 lines.
  - Owns focused tests for pending correction candidate creation, memory-change summaries, and best-effort extraction failure handling.

Moved out of `chat_service.py`:

- `_handle_simple_memory_turn` moved to `MemoryTurnService.handle_turn`.
- `_save_confirmed_simple_memory` moved to `MemoryTurnService._save_confirmed_simple_memory`.
- Simple-memory rejection handling moved to `MemoryTurnService._reject_simple_memory`.
- `_simple_memory_confirmation_summary` moved to `MemoryTurnService._simple_memory_confirmation_summary`.
- `_simple_memory_saved_summary` moved to `MemoryTurnService._simple_memory_saved_summary`.
- `_simple_memory_rejected_summary` moved to `MemoryTurnService._simple_memory_rejected_summary`.
- `_simple_memory_failed_summary` moved to `MemoryTurnService._simple_memory_failed_summary`.
- `_recent_public_messages` moved to `MemoryTurnService.recent_public_messages`.
- `_public_messages` moved to `MemoryTurnService.public_messages`.
- `_public_message` moved to `MemoryTurnService.public_message`.
- `_handle_memory_candidate_decision` moved to `MemoryCandidateDecisionService.handle_decision`.
- `_memory_candidate_decision_intent` moved to `MemoryCandidateDecisionService._decision_intent`.
- `_is_vague_approval` moved to `MemoryCandidateDecisionService._is_vague_approval`.
- `_candidate_from_confirmation_text` moved to `MemoryCandidateDecisionService._candidate_from_confirmation_text`.
- `_edit_pending_memory_candidate` moved to `MemoryCandidateDecisionService._edit_pending_memory_candidate`.
- `_edited_candidate_payload` moved to `MemoryCandidateDecisionService._edited_candidate_payload`.
- `_candidate_primary_text_key` moved to `MemoryCandidateDecisionService._candidate_primary_text_key`.
- `_pending_candidates_response` moved to `MemoryCandidateDecisionFormatter.pending_candidates_response`.
- `_candidate_decision_response` moved to `MemoryCandidateDecisionFormatter.candidate_decision_response`.
- `_candidate_card` moved to `MemoryCandidateDecisionFormatter.candidate_card`.
- `_candidate_expected_action` moved to `MemoryCandidateDecisionFormatter.candidate_expected_action`.
- `_payload_preview` moved to `MemoryCandidateDecisionFormatter.payload_preview`.
- `_verification_summary` moved to `MemoryCandidateDecisionFormatter.verification_summary`.
- `_remaining_conflict_text` moved to `MemoryCandidateDecisionFormatter.remaining_conflict_text`.
- `_normalized_confirmation_text` moved to `MemoryCandidateDecisionService._normalized_confirmation_text`.
- `_extract_clarity_action_proposals` moved to `ClarityActionParser.extract_proposals`.
- `_normalize_clarity_action_proposal` moved to `ClarityActionParser.normalize_proposal`.
- `_memory_changes_with_clarity_actions` moved to `ClarityActionParser.with_memory_changes`.
- `_ClarityActionStreamFilter` moved to `ClarityActionStreamFilter`.
- `_plan_rex_brain_chat_turn` moved to `RexBrainChatService.plan_chat_turn`.
- `_safe_plan_rex_brain_chat_turn` moved to `RexBrainChatService.safe_plan_chat_turn`.
- `_rex_brain_request_id` moved to `RexBrainChatService.request_id`.
- `_log_rex_brain_turn` moved to `RexBrainChatService.log_turn`.
- `_apply_rex_brain_chat_contract` moved to `RexBrainChatService.apply_chat_contract`.
- `_rex_brain_chat_contract_section` moved to `RexBrainChatService.chat_contract_section`.
- `_rex_brain_ai_kwargs` moved to `RexBrainChatService.ai_kwargs`.
- `_user_requested_deep_thinking` moved to `RexBrainChatService.user_requested_deep_thinking`.
- `_rex_brain_memory_metadata` moved to `RexBrainChatService.memory_metadata`.
- `_rex_brain_prompt_context` moved to `RexBrainChatService.prompt_context`.
- `_rex_brain_prompt_context_limit` moved to `RexBrainChatService.prompt_context_limit`.
- `_fetch_prompt_context`, `_merge_memories`, `_fetch_structured_context`, `_build_prompt_messages`, `_build_prompt_messages_for_rex_brain`, `_current_time_context`, `_accountability_signals`, `_last_message_timestamp`, and `_conversation_timestamp` moved to `ChatContextService`.
- `_memory_candidate_metadata`, `_apply_memory_correction`, `_memory_correction_prompt`, `_correction_blocks_extraction`, `_memory_change_summary`, `_extract_memory_after_success`, and `_schedule_memory_extraction` moved to `MemoryPostTurnService`.

Results:

- Focused Phase 2 continuation tests after context and post-turn extraction: 102 passed.
- Full Rex API suite: 536 passed.

## Phase 3 - Extract Pending Candidate Decisions From `chat_service.py`

Status: Complete during Phase 2 continuation

Primary files:

- `services/rex-api/app/services/chat_service.py`
- New: `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_service.py`
- `services/rex-api/tests/test_chat_service.py`
- New: `services/rex-api/tests/test_memory_candidate_decision_service.py`

Goal: move pending candidate approve/reject/edit/chat-confirmation logic out of `ChatService`.

Steps:

1. Create `MemoryCandidateDecisionService`.
2. Move candidate intent parsing, vague/high-risk approval checks, candidate selection by id, edit parsing, response summaries, and candidate card mapping.
3. Keep `ChatService` as the caller that saves the assistant decision message.
4. Preserve current response shape for mobile cards.
5. Add focused tests for approve, reject, approve all, reject all, edit, high-risk vague confirmation, and multiple candidate selection.
6. Reduce duplicated candidate setup in tests with small fixtures/builders.
7. Run candidate route/service tests.
8. Run full Rex API tests.

Completion note:

- This phase was completed before moving on because `chat_service.py` was still too large after the first Phase 2 extraction.
- See the Phase 2 refactor ledger for exact line counts, moved methods, and verification results.

## Phase 4 - Split Prompt Context From `chat_service.py`

Status: Complete during Phase 2 continuation. Rex Brain chat glue, prompt context assembly, and post-turn memory side effects were extracted while `chat_service.py` was still the active target.

Primary files:

- `services/rex-api/app/services/chat_service.py`
- New: `services/rex-api/app/services/chat_context_service.py`
- Existing: `services/rex-api/app/services/rex_brain_chat_service.py`
- Existing: `services/rex-api/app/services/rex_brain_context.py`
- Existing: `services/rex-api/app/services/prompt_service.py`
- `services/rex-api/tests/test_chat_service.py`
- New: `services/rex-api/tests/test_chat_context_service.py`

Goal: separate context gathering and prompt-building from chat request orchestration.

Steps:

1. Create `ChatContextService` to fetch conversation history, long-term memory, profile memory, structured context, time context, and accountability signals.
2. Move `_fetch_prompt_context`, `_merge_memories`, `_fetch_structured_context`, `_current_time_context`, and `_accountability_signals`.
3. Keep hidden-marker stripping in the context boundary so internal metadata never enters prompts.
4. Keep Rex Brain chat planning in `RexBrainChatService`; only move prompt-context preparation here if it belongs with the fetched context object.
5. Add tests for profile-memory merge, structured-context failure handling, time context, and marker stripping.
6. Update `ChatService` to receive one context object instead of many loose variables.
7. Run prompt, Rex Brain context, and chat tests.
8. Verify text and voice prompt context still includes approved durable memories.

## Phase 5 - Decompose `memory_service.py` Storage Responsibilities
Status: Complete. `memory_service.py` is below the 500-line guardrail.
Primary files:
- `services/rex-api/app/services/memory_service.py`
- New: `services/rex-api/app/services/conversation_repository.py`
- New: `services/rex-api/app/services/long_term_memory_repository.py`
- New: `services/rex-api/app/services/structured_memory_repository.py`
- New: `services/rex-api/app/services/memory_candidate_repository.py`
- New: `services/rex-api/app/services/supabase_memory_transport.py`
- Existing memory route/service tests
Goal: stop one Supabase service from owning every memory table and retrieval concern.
Steps:

1. Extract shared Supabase request/auth/scoping helpers first.
2. Move conversation CRUD into `ConversationRepository`.
3. Move long-term memory CRUD into `LongTermMemoryRepository`.
4. Move candidate CRUD into `MemoryCandidateRepository`.
5. Move structured memory table CRUD into `StructuredMemoryRepository`.
6. Keep `SupabaseMemoryService` temporarily as a facade so existing dependencies do not break.
7. Migrate callers gradually from facade methods to repositories only after tests are stable.
8. Run all memory, candidate, route, and user-scoping tests.
Ledger: `memory_service.py` 1,263 -> 1,022 -> 829 -> 650 -> 493 lines. Moved retrieval orchestration to `memory_retrieval_service.py` at 210 lines, transport to `supabase_memory_transport.py` at 185 lines, conversation/message/voice-turn storage to `conversation_repository.py` at 166 lines, long-term memory CRUD to `long_term_memory_repository.py` at 199 lines, structured CRUD to `structured_memory_repository.py` at 300 lines, candidate/correction CRUD and validation to `memory_candidate_repository.py` at 212 lines, and shared error class to `memory_errors.py` at 5 lines. Latest verification: focused retrieval/context tests 71 passed; full Rex API suite 554 passed.

## Phase 6 - Extract Retrieval Ranking From `memory_service.py`
Status: Complete. `memory_service.py` lost retrieval ranking/scoring complexity.
Primary files:
- `services/rex-api/app/services/memory_service.py`
- New: `services/rex-api/app/services/memory_retrieval_ranker.py`
- `services/rex-api/tests/test_memory_retrieval.py`
- New: `services/rex-api/tests/test_memory_retrieval_ranker.py`
Goal: make memory recall scoring explainable and independently testable.
Steps:
1. Move `_score_memory`, `_rank_structured_records`, `_score_structured_record`, token expansion, exact-match boost, recency score, and stale-correction filtering into retrieval-focused services/helpers.
2. Keep database fetching separate from ranking.
3. Add tests for profile facts, birthday/family facts, exact match, stale correction filtering, recency, and high-importance boost.
4. Add fixtures for the real symptom: birthday saved, later “Do you remember my mom’s birthday?” retrieves it.
5. Keep ranking deterministic.
6. Avoid semantic/vector search in this phase.
7. Run retrieval tests and chat integration tests.
8. Document when a future semantic retrieval layer should be added.
Acceptance criteria:

- Retrieval ranking can be improved without editing Supabase CRUD code. Complete.
- Critical personal facts recall reliably in tests.
- `memory_service.py` loses ranking/scoring complexity. Complete: 1,706 -> 1,263 lines.

Refactor ledger: moved scoring, structured ranking, related-record merging, token/concept expansion, recency scoring, and stale corrected-memory filtering to `memory_retrieval_ranker.py` at 471 lines. Added `test_memory_retrieval_ranker.py` at 83 lines. Verification: focused retrieval tests 16 passed; full Rex API suite 554 passed.

## Phase 7 - Decompose `memory_extraction_service.py`

Status: Complete. `memory_extraction_service.py` is below the 500-line guardrail.

Primary files:

- `services/rex-api/app/services/memory_extraction_service.py`
- New: `services/rex-api/app/services/memory_extraction_parser.py`
- New: `services/rex-api/app/services/memory_extraction_planner.py`
- New: `services/rex-api/app/services/structured_memory_writer.py`
- New: `services/rex-api/app/services/memory_candidate_writer.py`
- `services/rex-api/tests/test_memory_extraction.py`

Goal: separate AI extraction from parsing, validation, candidate creation, and durable writes.

Steps:

1. Move the static extraction prompt into `memory_extraction_prompt.py`. Complete: 1,879 -> 1,703 lines.
2. Extract AI payload/result parsing into `MemoryExtractionParser`. Complete: 1,703 -> 1,592 lines.
3. Extract structured candidate normalization. Complete: 1,592 -> 1,286 lines.
4. Extract entity/plan reference resolution. Complete: 1,286 -> 1,164 lines.
5. Extract candidate creation into `MemoryCandidateWriter`. Complete: 1,164 -> 942 lines.
6. Remove unused correction-upsert dead code. Complete: 942 -> 402 lines.
7. Keep `extract_and_save` as the stable facade and run backend tests.

Current verification:

- Focused extraction/chat suite: 97 passed.

## Phase 8 - Split Mobile `memory_page.dart`

Status: Complete

Primary files:

- `apps/mobile/lib/features/assistant/memory/presentation/pages/memory_page.dart`
- New widgets/helpers: `memory_edit_dialogs.dart`, `memory_archive_dialogs.dart`, `memory_page_filters.dart`, `memory_page_header_widgets.dart`, `memory_quick_filter.dart`, `memory_pending_review_widgets.dart`, `memory_meta_chip.dart`, `saved_memory_results.dart`, `saved_memory_group_list.dart`, `saved_memory_tiles.dart`
- `apps/mobile/test/memory_page_test.dart`

Goal: make the Memory tab maintainable while preserving its current product feel.

Steps:

1. Extract stateless widgets first without changing behavior.
2. Move pending candidate tile/list widgets.
3. Move saved group list and saved memory tiles.
4. Move empty/loading/error states.
5. Move edit/archive dialogs.
6. Move filtering helpers into a small presentation helper/model file.
7. Keep `MemoryPage` as page shell plus event wiring.
8. Run widget tests after each extraction.

Acceptance criteria:

- `memory_page.dart` becomes a page shell, not a 2,000-line UI file.
- Existing UI screenshots should look unchanged.
- Saved and pending memory flows still work.

Ledger: `memory_page.dart` 2,196 -> 1,765 -> 1,393 -> 850 -> 483 lines. Moved edit/archive dialogs, quick filter, filtering helpers, header/empty widgets, pending review UI, saved grouping/list/tiles, and shared chip into focused files; largest extracted file is `memory_edit_dialogs.dart` at 436 lines. Latest verification: `flutter test test/memory_page_test.dart` 10 passed; `flutter analyze` no issues.

Suggested verification:

```bash
cd apps/mobile
flutter test test/memory_page_test.dart test/memory_api_test.dart test/memory_label_test.dart
```

## Phase 9 - Split Mobile Memory Controller/API Carefully
Status: Complete

Primary files:

- `apps/mobile/lib/features/assistant/memory/application/memory_controller.dart`
- `apps/mobile/lib/features/assistant/memory/data/memory_api.dart`
- New: `memory_read_controller.dart`, `memory_action_controller.dart`, `memory_controller_errors.dart`
- New: `memory_saved_api.dart`, `memory_structured_api.dart`, `memory_candidate_api.dart`

Goal: reduce controller/API coupling after the UI is already split.

Steps:

1. Do not start this until Phase 8 is stable.
2. Group controller methods into read/load paths and mutation/action paths.
3. Extract private helper methods before changing providers.
4. Keep provider names stable unless tests prove a clean migration path.
5. Split API methods only if the call sites become clearer.
6. Update tests for pending candidate decisions, saved overview refresh, edit, and archive.
7. Run memory mobile tests.
8. Run broader assistant tests.

Ledger: `memory_controller.dart` 647 -> 111 lines; `memory_api.dart` 411 -> 161 lines. Moved read/query methods, mutation/action methods, error copy, saved-memory endpoints, structured-memory endpoints, and candidate endpoints into focused files; all new files are below 500 lines. Verification: focused memory tests 21 passed; `flutter analyze` no issues.

## Phase 10 - Split Oversized Tests Into Behavior Suites
Status: Complete. Primary files: `test_chat_service.py`, `test_memory_extraction.py`, `memory_page_test.dart`.

Goal: make future memory changes faster and safer.

Steps:
1. Split `test_chat_service.py` into:
   - `test_chat_service_core.py`
   - `test_chat_simple_memory_flow.py`
   - `test_chat_candidate_decisions.py`
   - `test_chat_prompt_context.py`
   - `test_chat_streaming.py`
2. Complete: split `test_memory_extraction.py` 1,396 -> 461 lines; moved fakes, corrections, and structured candidate coverage into focused files.
3. Complete: split `memory_page_test.dart` 588 -> 69 lines; moved pending, archive/error, and helpers into focused files.
4. Move shared fakes/builders into `conftest.py` or focused fixture helpers. Complete for chat, extraction, and mobile memory page tests.
5. Avoid changing assertions while moving tests.
6. Run moved tests after each file split.
7. Run full backend and mobile targeted tests.
8. Keep test names behavior-focused.

Acceptance criteria:
- Refactors no longer require scanning one massive test file.
- Test failures point to a specific memory subsystem.
- No test coverage is lost during file moves.

Ledger: chat tests 2,137 -> 399 plus focused suites at 185-424; extraction tests 1,396 -> 461 plus focused files at 248-390; mobile page tests 588 -> 69 plus focused files at 93-279. Verification: backend split suites 71 passed; mobile memory tests 21 passed; `flutter analyze` no issues.

## Final Manual Release And Phone Test

Do this only after the relevant phase has passed automated tests.

Backend:

```bash
ssh rex@209.126.87.50
cd /opt/clarity/current
git pull
./scripts/vps_restart_rex_api.sh
```

Mobile:

```bash
cd apps/mobile
flutter clean
flutter pub get
flutter build ios --release
```

Manual memory smoke test:

1. Open Rex Chat.
2. Say: `My mom's birthday is on the 18th.`
3. Confirm Rex asks: `So your mom's birthday is June 18, correct?`
4. Reply: `yes`.
5. Ask: `Do you remember my mom's birthday?`
6. Confirm Rex recalls June 18.
7. Repeat the recall question in Voice.
8. Open Memory and confirm the saved memory appears in saved memory, not pending review.
9. Confirm no internal marker text appears in chat history or conversation history.
10. Archive the memory and verify future recall no longer uses it.

## Recommended Execution Order

1. Phase 1 - Stabilize The New Simple Memory Path
2. Phase 2 - Extract Memory Turn Orchestration From `chat_service.py`
3. Phase 3 - Extract Pending Candidate Decisions From `chat_service.py`
4. Phase 4 - Split Prompt Context And Rex Brain Glue From `chat_service.py`
5. Phase 5 - Decompose `memory_service.py` Storage Responsibilities
6. Phase 6 - Extract Retrieval Ranking From `memory_service.py`
7. Phase 7 - Decompose `memory_extraction_service.py`
8. Phase 8 - Split Mobile `memory_page.dart`
9. Phase 9 - Split Mobile Memory Controller/API Carefully
10. Phase 10 - Split Oversized Tests Into Behavior Suites
