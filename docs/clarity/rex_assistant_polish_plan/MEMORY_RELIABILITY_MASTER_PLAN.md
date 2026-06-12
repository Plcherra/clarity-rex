# Memory Reliability Master Plan

Last updated: June 1, 2026

## Purpose

Make Rex Memory feel reliable, natural, and human in daily use. This plan focuses only on memory reliability. It does not cover Plaid, Stripe, general UI polish, or broad assistant redesign.

## Core Goal

Replace fragile hidden confirmation markers in assistant messages with explicit pending confirmation records. Simple facts should flow naturally:

1. User says something memorable.
2. Rex confirms naturally in chat.
3. User confirms.
4. Rex saves durable memory immediately.
5. Rex can recall it reliably in text and voice.

## Current Main Risk

The simple memory confirmation flow currently stores pending confirmation state inside assistant message content with a hidden HTML marker. That works in tests, but it is fragile if message content is stripped, summarized, migrated, edited, truncated, or loaded through an API path that removes markers.

Primary files involved today:

- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/chat_service.py`
- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/memory_retrieval_service.py`
- `services/rex-api/app/services/memory_candidate_service.py`
- `services/rex-api/app/services/memory_correction_service.py`
- `services/rex-api/app/services/memory_discipline_service.py`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/memory/application/memory_controller.dart`

## Phase 1 Deliverable

Phase 1 produced the explicit contract in
`docs/clarity/rex_assistant_polish_plan/MEMORY_CONFIRMATION_CONTRACT.md`.

Implementation decision: use a dedicated Supabase table named
`memory_confirmations`. Conversation metadata is not the primary path because it
would keep pending memory state coupled to conversation serialization.

Hidden assistant-message markers are deprecated. They should remain readable
only as a temporary compatibility fallback for old conversations.

## Phase 1 - Design Explicit Pending Confirmation Contract

Goal: Define the new data contract before changing runtime behavior.

Files to change:

- New: `docs/clarity/rex_assistant_polish_plan/MEMORY_CONFIRMATION_CONTRACT.md`
- Updated: `docs/clarity/rex_assistant_polish_plan/MEMORY_RELIABILITY_MASTER_PLAN.md`
- Optional: Supabase migration draft, kept in the contract until Phase 2

Steps:

1. Define a lightweight `memory_confirmations` record shape.
2. Include fields: `id`, `user_id`, `conversation_id`, `source_message_id`, `status`, `memory_type`, `content`, `importance`, `source`, `expires_at`, `confirmed_at`, `rejected_at`, `created_at`, `metadata`.
3. Decide whether the first implementation uses a real DB table or temporary conversation metadata.
4. Define allowed statuses: `pending`, `confirmed`, `rejected`, `expired`, `failed`.
5. Define lookup rule: latest pending confirmation for the same conversation and user.
6. Define expiration policy, ideally 24-72 hours.
7. Define compatibility behavior for old hidden-marker messages during migration.

Done looks like:

- The contract is written and reviewed.
- The implementation target is chosen: DB table preferred, conversation metadata acceptable only as a short bridge.
- Existing hidden-marker behavior is marked deprecated, not immediately deleted.

Manual test steps:

1. Review the contract.
2. Confirm the contract can represent mom birthday confirmation.
3. Confirm the contract can represent rejection and save failure.

Acceptance criteria:

- No runtime behavior changed yet.
- The next phase can implement against a clear contract.
- The contract keeps user scope explicit.

## Phase 2 - Add Backend Storage For Pending Confirmations

Goal: Add explicit persistence for pending simple-memory confirmations.

Status: Completed in storage-only mode. Runtime chat flow is intentionally still
unchanged until Phase 3.

Files to change:

- New: `services/rex-api/app/services/memory_confirmation_repository.py`
- New: `services/rex-api/app/services/memory_confirmation_facade.py`
- Update: `services/rex-api/app/services/memory_service.py`
- Update: `services/rex-api/app/config.py`
- Update: `services/rex-api/app/services/supabase_memory_transport.py` only if shared helpers are needed
- New: `supabase/migrations/000023_create_memory_confirmations.sql`
- New tests: `services/rex-api/tests/test_memory_confirmation_repository.py`

Steps:

1. Add create/list/update methods for memory confirmations.
2. Add `create_memory_confirmation`.
3. Add `get_latest_pending_memory_confirmation`.
4. Add `confirm_memory_confirmation`.
5. Add `reject_memory_confirmation`.
6. Add expiration filtering.
7. Preserve user scoping through existing Supabase transport rules.
8. Add repository tests with fake transport or mocked storage.

Done looks like:

- Backend can create and resolve pending confirmation records.
- No hidden marker is required to store pending confirmation state.
- Old chat behavior is not switched yet.

Manual test steps:

1. Create a pending record from a test or local script.
2. Confirm the record.
3. Reject another record.
4. Verify user scoping.

Acceptance criteria:

- Tests pass for create, latest-pending lookup, confirm, reject, expire.
- Storage file stays below 500 lines.
- `memory_service.py` remains a thin facade.

## Phase 3 - Replace Hidden Marker Creation In Simple Memory Flow

Goal: Rex asks natural confirmation questions while storing pending state in explicit records.

Status: Completed. New simple-memory confirmations create
`memory_confirmations` records and save assistant confirmation messages as plain
public text. Legacy hidden markers remain readable as fallback only.

Files to change:

- `services/rex-api/app/services/memory_turn_service.py`
- New: `services/rex-api/app/services/memory_turn_confirmation_helpers.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/chat_service.py` only if wiring is needed
- `services/rex-api/tests/test_memory_turn_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`

Steps:

1. Inject confirmation storage into `MemoryTurnService`.
2. On detected simple memory, create `memory_confirmations` record.
3. Save assistant message with only public confirmation text.
4. Stop writing `<!-- rex_memory_confirmation:... -->` for new messages.
5. Keep marker parsing as fallback for old conversation history.
6. Return `memory_changes` with `confirmation_required: 1` and the confirmation id.
7. Ensure stream and non-stream paths use the same confirmation creation.

Done looks like:

- New confirmations no longer depend on hidden markers.
- User still sees the same natural text.
- Old marker-based confirmations can still be confirmed during transition.

Manual test steps:

1. In chat, say: `My mom's birthday is on the 18th.`
2. Confirm Rex asks: `So your mom's birthday is June 18, correct?`
3. Inspect backend storage and confirm a pending confirmation record exists.
4. Confirm assistant message content contains no hidden marker.

Acceptance criteria:

- Existing simple-memory tests pass after updating expectations.
- Conversation APIs never expose hidden markers.
- New pending confirmation id is included in memory metadata where useful.

## Phase 4 - Confirm Or Reject From Explicit Records

Goal: User confirmation should resolve the explicit pending record and immediately save durable memory.

Status: Completed. Explicit pending records now confirm, reject, or fail through
the confirmation lifecycle; unrelated replies continue normal chat without
saving; repeated confirmations do not create duplicate durable memories.

Files to change:

- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/memory_turn_confirmation_helpers.py`
- `services/rex-api/app/services/long_term_memory_repository.py` if metadata needs improvement
- `services/rex-api/tests/test_memory_turn_service.py`
- `services/rex-api/tests/test_chat_simple_memory_flow.py`

Steps:

1. On each turn, look up latest pending confirmation by conversation/user.
2. Classify user reply as confirm/reject/other.
3. If confirm, save durable long-term memory immediately.
4. Mark pending confirmation as `confirmed`.
5. If reject, mark as `rejected`.
6. If save fails, mark as `failed` or leave pending with failure metadata.
7. If user reply is unrelated, continue normal chat without saving.
8. Keep fallback marker confirmation only for old messages.

Done looks like:

- Confirmation no longer depends on last assistant message content.
- Durable save is immediate after confirmation.
- Rejection and unrelated replies are cleanly handled.

Manual test steps:

1. Say: `My mom's birthday is on the 18th.`
2. Reply: `yes`.
3. Confirm durable memory exists.
4. Repeat with `no` and confirm no durable memory is saved.
5. Repeat with unrelated reply and confirm no accidental save.

Acceptance criteria:

- Text chat simple memory flow passes.
- Voice stream simple memory flow passes.
- No duplicate durable memory is created on repeated `yes`.

## Phase 5 - Improve Recall Reliability For Profile Facts

Goal: Rex should reliably recall confirmed personal facts such as birthdays, location, timezone, names, preferences, and important dates.

Status: Completed. Retrieval now expands birthday, family, important-date, and
profile concepts; profile-memory context explicitly asks for birthdays and
family facts; memory ranking considers simple-memory metadata such as
`fact_kind`, `entity_label`, `normalized_date`, and `topic_fingerprint`.

Files to change:

- `services/rex-api/app/services/memory_retrieval_service.py`
- `services/rex-api/app/services/memory_retrieval_ranker.py`
- New: `services/rex-api/app/services/memory_retrieval_terms.py`
- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- Tests: `services/rex-api/tests/test_memory_retrieval.py`, `services/rex-api/tests/test_chat_simple_memory_flow.py`, `services/rex-api/tests/test_memory_profile_recall.py`

Steps:

1. Add profile-fact tags or metadata when direct simple memories are saved.
2. Add specific concept terms for birthdays, family members, important dates, names, and profile facts.
3. Ensure `Do you remember my mom's birthday?` retrieves `User's mom's birthday is June 18.`
4. Ensure high-importance profile facts survive prompt context trimming.
5. Add recall tests for text and voice channel setup.
6. Ensure archived memories do not appear in recall.

Done looks like:

- Birthday/profile recall is deterministic in tests.
- Prompt context includes the confirmed memory before AI generation.
- Rex does not need pending candidate approval for simple confirmed facts.

Manual test steps:

1. Save mom birthday.
2. Ask: `Do you remember my mom's birthday?`
3. Ask in voice.
4. Archive the memory.
5. Ask again and confirm Rex no longer uses it.

Acceptance criteria:

- Recall smoke tests pass.
- Retrieval does not over-include unrelated high-priority facts.
- Prompt context remains concise.

## Phase 6 - Prevent Duplicate Pending And Durable Memories

Goal: Avoid creating multiple pending candidates or durable facts for the same topic.

Status: Completed. Rex now reuses an existing pending confirmation for the same
`topic_fingerprint`, skips confirmation when an equivalent active durable memory
already exists, avoids duplicate durable writes if the same fact is confirmed
again, and reuses equivalent pending memory candidates instead of creating
duplicate candidate cards.

Files to change:

- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/services/memory_turn_confirmation_helpers.py`
- `services/rex-api/app/services/memory_candidate_writer.py`
- `services/rex-api/app/services/memory_extraction_service.py`
- `services/rex-api/app/services/memory_candidate_service.py`
- Tests: `services/rex-api/tests/test_memory_turn_service.py`, `services/rex-api/tests/test_chat_simple_memory_flow.py`, `services/rex-api/tests/test_memory_candidate_writer.py`, extraction

Steps:

1. Before creating a simple confirmation, check for existing pending confirmation in the same conversation.
2. Before saving confirmed durable memory, check for equivalent active memory.
3. If an equivalent memory exists, update it only when the new fact is clearer or newer.
4. Before creating pending extraction candidates, check active pending candidates for equivalent payload/topic.
5. Add topic fingerprints for simple facts where possible.
6. Add duplicate tests for mom birthday, remember-that preference, and correction candidates.

Done looks like:

- Repeating the same birthday fact does not create multiple pending confirmations.
- Confirming twice does not save duplicate durable records.
- Extraction does not create duplicate pending candidates for an already confirmed simple fact.

Manual test steps:

1. Say mom birthday twice before confirming.
2. Confirm once.
3. Say the same birthday again.
4. Open Memory and verify one active saved fact.

Acceptance criteria:

- Duplicate tests pass.
- User-facing response is natural: `I already have that saved.`
- No duplicate pending cards in chat or Memory tab.

## Phase 7 - Clarify Pending Candidate Vs Direct Save Rules

Goal: Make the system behavior internally clear and user-facing language consistent.

Status: Completed. Direct simple memories now carry `direct_save` metadata after
explicit chat confirmation, simple memory confirmation records carry
`pending_confirmation` metadata, and extraction/correction candidates carry
`pending_review` metadata with review reasons. Candidate review copy now uses
"memory card" language instead of leaking "candidate card" terminology, and
mobile review models prefer the clean `review_reason` field.

Files to change:

- `services/rex-api/app/services/memory_candidate_writer.py`
- `services/rex-api/app/services/memory_extraction_service.py`
- `services/rex-api/app/services/memory_post_turn_service.py`
- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `apps/mobile/lib/rex/chat/presentation/widgets/chat_message_bubble.dart`
- Tests for chat memory candidate cards and candidate decisions

Steps:

1. Define direct-save rules: low-risk simple facts after explicit confirmation.
2. Define pending-candidate rules: corrections, complex structured memory, high-risk changes, ambiguous facts.
3. Add metadata explaining why each memory path was chosen.
4. Standardize user-facing copy for pending candidates.
5. Ensure high-risk candidates require explicit confirmation, not vague `yes`.
6. Ensure direct simple memories do not also become pending extraction candidates.

Done looks like:

- Engineers can answer why a memory was direct-saved vs pending.
- Users see consistent copy.
- Memory cards do not appear for simple facts that were already saved directly.

Manual test steps:

1. Save mom birthday and confirm it direct-saves.
2. Correct an old memory and confirm it becomes pending/high-risk.
3. Approve the correction from chat.
4. Verify copy is clear in chat and Memory tab.

Acceptance criteria:

- Direct vs pending behavior is documented in code comments or tests.
- Candidate cards only show when review is actually needed.
- No hidden implementation terms appear in UI.

## Phase 8 - Split Remaining Large Memory Logic Hubs

Goal: Reduce future reliability risk by splitting the largest remaining policy-heavy files.

Status: Completed. The remaining memory hubs were split into focused backend
and mobile modules while preserving public facades and provider/import
compatibility. `memory_correction_service.py`, `memory_discipline_service.py`,
`memory_candidate_service.py`, `chat_controller.dart`, and
`memory_models.dart` are now at or below the line-count guardrail, with new
helper modules kept small.

Files to change:

- `services/rex-api/app/services/memory_candidate_service.py`
- `services/rex-api/app/services/memory_correction_service.py`
- `services/rex-api/app/services/memory_discipline_service.py`
- `apps/mobile/lib/rex/chat/application/chat_controller.dart`
- `apps/mobile/lib/rex/memory/data/memory_models.dart`

Steps:

1. Split candidate apply/write logic from `memory_candidate_service.py`.
2. Move candidate preview helpers into a focused formatter/helper file.
3. Split correction intent parsing from correction application in `memory_correction_service.py`.
4. Split discipline similarity/scoring helpers from `memory_discipline_service.py`.
5. Move mobile chat memory/action card parsing out of `chat_controller.dart`.
6. Split mobile memory labels/cards/models only if tests remain stable.

Done looks like:

- No new replacement god file is created.
- Each extracted file stays below 500 lines where practical.
- Public API facades remain stable.

Manual test steps:

1. Run chat, memory, candidate, correction, and mobile memory tests.
2. Manually approve/reject a pending candidate.
3. Manually save and recall a simple memory.

Acceptance criteria:

- Full backend suite passes.
- `flutter analyze` passes.
- No file grows unexpectedly beyond 500 lines without explicit reason.

## Phase 9 - Add Reliability-Focused Test Suite

Goal: Create tests that match the way users actually expect memory to work.

Status: Completed. Added a single behavior-focused reliability suite covering
mom birthday confirmation/save/recall, rejection, duplicate prevention,
pending correction review, voice streaming save/recall, voice metadata,
archived-memory non-recall, and old hidden-marker fallback.

Files to change:

- New: `services/rex-api/tests/test_memory_reliability_flow.py`
- Update: `services/rex-api/tests/test_chat_simple_memory_flow.py`
- Update: `services/rex-api/tests/test_memory_retrieval.py`
- Update mobile tests if UI cards/copy change

Steps:

1. Add mom birthday full flow: ask, confirm, save, recall.
2. Add rejection flow.
3. Add duplicate prevention flow.
4. Add correction pending flow.
5. Add streaming flow.
6. Add voice-channel setup flow.
7. Add archived-memory non-recall flow.
8. Add migration fallback test for old hidden markers.

Done looks like:

- A single reliability suite exercises the highest-value user stories.
- Tests fail when memory becomes bureaucratic or unreliable.
- Tests are behavior-focused, not implementation-focused.

Manual test steps:

1. Run the reliability suite.
2. Run full backend tests.
3. Run mobile memory/chat targeted tests.

Acceptance criteria:

- Reliability suite passes locally.
- Full Rex API suite passes.
- Mobile targeted tests pass.

## Phase 10 - Manual Release Smoke And Monitoring

Goal: Verify the new memory system on a real device before moving to Plaid integration.

Files to change:

- Optional: update release notes or QA checklist
- Optional: add lightweight logs for confirmation lifecycle

Steps:

1. Deploy backend.
2. Build and run mobile app on phone.
3. Test text memory save/recall.
4. Test voice memory save/recall.
5. Test pending correction candidate.
6. Test duplicate prevention.
7. Test archive and non-recall.
8. Check backend logs for confirmation lifecycle errors.

Done looks like:

- Memory feels natural on the phone.
- No hidden marker appears anywhere.
- No duplicate pending cards appear.
- Recall works in text and voice.

Manual test steps:

1. `My mom's birthday is on the 18th.`
2. `yes`
3. `Do you remember my mom's birthday?`
4. Repeat recall in voice.
5. `Actually my mom's birthday is June 19.`
6. Confirm correction goes through pending review.
7. Approve correction.
8. Ask recall again.

Acceptance criteria:

- Rex recalls the correct date.
- Rex explains pending corrections clearly.
- Memory tab shows one current saved memory, not duplicates.
- Backend readiness stays healthy.

Phase 10 completion notes:

- Added `MEMORY_RELEASE_SMOKE_CHECKLIST.md` for local preflight, VPS deploy,
  phone release run, text/voice memory smoke tests, correction tests, duplicate
  checks, archive checks, and backend log review.
- Added privacy-safe confirmation lifecycle logs through
  `memory_confirmation_lifecycle_logger.py` and call sites in
  `memory_turn_service.py`. Logs include confirmation/memory IDs, memory type,
  topic fingerprint, and fact kind only. They do not log raw memory content.
- Phase 10 is ready for manual phone validation before Plaid integration.

## Recommended Execution Order

1. Phase 1 - Design Explicit Pending Confirmation Contract
2. Phase 2 - Add Backend Storage For Pending Confirmations
3. Phase 3 - Replace Hidden Marker Creation In Simple Memory Flow
4. Phase 4 - Confirm Or Reject From Explicit Records
5. Phase 5 - Improve Recall Reliability For Profile Facts
6. Phase 6 - Prevent Duplicate Pending And Durable Memories
7. Phase 7 - Clarify Pending Candidate Vs Direct Save Rules
8. Phase 9 - Add Reliability-Focused Test Suite
9. Phase 8 - Split Remaining Large Memory Logic Hubs
10. Phase 10 - Manual Release Smoke And Monitoring

## Verification Commands

Backend:

```bash
cd services/rex-api
python3 -m py_compile app/services/memory_turn_service.py app/services/memory_intent_service.py app/services/memory_service.py app/services/chat_service.py
python3 -m pytest tests/test_chat_simple_memory_flow.py tests/test_memory_turn_service.py tests/test_memory_intent_service.py tests/test_memory_retrieval.py -q
python3 -m pytest tests/ -q
```

Mobile:

```bash
cd apps/mobile
flutter analyze
flutter test test/memory_page_test.dart test/memory_page_pending_test.dart test/memory_page_archive_errors_test.dart test/chat_memory_candidate_card_test.dart
```
