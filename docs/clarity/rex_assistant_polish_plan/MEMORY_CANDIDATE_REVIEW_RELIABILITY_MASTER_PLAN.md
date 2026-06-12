# Memory Candidate Review Reliability Master Plan

Status: In progress

Last updated: June 2, 2026

## Purpose

Fix the phone-test failure where conversational confirmation of pending memories
creates more pending memories instead of resolving the existing review queue.

This plan follows `docs/UNIVERSAL_CODE_ARCHITECTURE_STANDARDS.md`: explicit
state over hidden contracts, no silent failures, small phases, behavior tests
first, and no god-file growth.

## Core Outcome

By the end of this plan:

- Pending memory review can be handled naturally from chat.
- Memory-management turns do not run general memory extraction.
- Mixed confirmation plus correction does not create unrelated duplicate pending
  cards.
- Rex only claims memory changed when backend apply/verification succeeds.

## Non-Goals

- Full Memory tab redesign.
- Large voice UI refactor.
- Plaid integration.
- Bulk destructive high-risk apply without explicit confirmation.

## Current State

| Area | Current State | Risk |
| --- | --- | --- |
| Candidate decisions | Phrase-list parser only | Natural approval language falls through |
| Review state | Inferred from pending candidates | Rex can ask "confirm those" without explicit operation semantics |
| Extraction | Runs after ordinary AI turns | Memory-management conversations can create more candidates |
| Mixed edit/approval | Unsupported | "Yes, but..." creates a new correction candidate |
| Voice | Turn overlap can emit 409 | Voice retry/lifecycle needs separate follow-up |

## Target State

| Area | Target State | Benefit |
| --- | --- | --- |
| Candidate decisions | Deterministic review commands and phone-test phrases supported | No more pending-count growth from confirmation attempts |
| Memory-management turns | Classified before AI/extraction | Prevents meta-conversation extraction noise |
| Mixed correction | Captured as update/review of existing pending candidate | No duplicate correction cards |
| User copy | Backend-authored for candidate review turns | Rex does not imply writes that did not happen |

## Phase 1 - Phone-Test Regression Tests

Goal: Lock the exact failed phrases into behavior tests.

Status: Completed. Added behavior tests for the phone-test phrases and verified
that handled memory-management turns do not call AI or general extraction.

Files changed:

- `services/rex-api/tests/test_chat_candidate_phone_phrases.py`
- `services/rex-api/tests/test_chat_candidate_decisions.py`
- `services/rex-api/tests/test_memory_candidate_decision_service.py`

Steps:

1. Add test for `Yes, we should review and finish all the pending memory.`
2. Add test for `Confirm those as saved.`
3. Add test for `Yes. But Summerville...`
4. Assert extraction is not called on memory-management turns.

Done looks like:

- Tests fail before implementation.
- Tests describe user-visible behavior, not internals.

Acceptance criteria:

- [x] Phone-test phrases are covered.
- [x] Pending count does not grow in tested flow.

## Phase 2 - Candidate Review Intent Classifier

Goal: Move fragile phrase logic into a focused classifier/policy.

Status: Completed. Added `memory_candidate_review_intent.py` and moved natural
approval/reject/review/mixed-correction classification out of the candidate
decision coordinator.

Files to change:

- New: `services/rex-api/app/services/memory_candidate_review_intent.py`
- `services/rex-api/app/services/memory_candidate_decision_service.py`

Steps:

1. Add normalized phrase classifier.
2. Classify approve-all, reject-all, review/list, approve-single, reject-single,
   edit, and mixed approve-with-correction.
3. Keep the existing public service API stable.

Done looks like:

- Candidate decision service becomes a coordinator, not a parser dump.
- File line count stays under 500.

Acceptance criteria:

- [x] Phone-test phrase tests pass.
- [x] Existing candidate-decision tests pass.

## Phase 3 - Extraction Gate For Memory-Management Turns

Goal: Prevent general memory extraction from processing pending-review
meta-conversation.

Status: Completed for handled candidate-review turns. Review/approve/reject/edit
pending-memory commands now return deterministic backend responses and skip AI
and extraction. A no-pending review response is also deterministic.

Files changed:

- `services/rex-api/app/services/chat_service.py`
- New or existing classifier module from Phase 2
- `services/rex-api/tests/test_chat_candidate_decisions.py`
- `services/rex-api/tests/test_chat_candidate_phone_phrases.py`

Steps:

1. Classify memory-management turns before AI.
2. If candidate decision handles the turn, return immediately.
3. If the turn is memory-management but no candidates exist, answer
   deterministically and skip extraction.

Done looks like:

- Memory-management turns do not create new memory candidates.

Acceptance criteria:

- [x] Extraction service is not called for review/approve/reject/edit pending
  memory turns.

## Phase 4 - Mixed Approve-With-Correction

Goal: Stop "yes, but..." from creating a new unrelated correction candidate.

Status: Completed for the one-pending-correction case. Mixed confirmation plus
correction now updates the existing pending correction candidate instead of
falling through to correction extraction.

Files changed:

- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_review_intent.py`
- `services/rex-api/tests/test_chat_candidate_phone_phrases.py`

Steps:

1. Detect mixed approval plus correction language.
2. If one correction candidate is pending, update that candidate payload.
3. If several candidates are pending, ask the user to identify which one.
4. Do not call general correction extraction for this turn.

Done looks like:

- User can correct a pending card without increasing pending count.

Acceptance criteria:

- [x] Existing pending correction candidate is updated.
- [x] No new correction candidate is created.

## Phase 5 - Explicit Review Session Contract

Goal: Formalize "these/those pending memories" so Rex never relies on vague
conversation state.

Status: Backend completed. Candidate review responses now include persisted
`review_session` records with selected candidate IDs and high-risk candidate IDs.
Manual phone validation remains pending after deploy.

Files changed:

- `docs/clarity/rex_assistant_polish_plan/ADR_MEMORY_CANDIDATE_REVIEW_SESSIONS.md`
- `supabase/migrations/000024_create_memory_candidate_review_sessions.sql`
- `services/rex-api/app/services/memory_candidate_review_session_service.py`
- `services/rex-api/app/services/memory_candidate_review_session_repository.py`
- `services/rex-api/app/services/memory_candidate_review_session_facade.py`
- `services/rex-api/app/services/memory_candidate_decision_service.py`
- `services/rex-api/app/services/memory_candidate_review_intent.py`
- `services/rex-api/app/services/memory_service.py`
- `services/rex-api/app/config.py`
- `services/rex-api/tests/test_memory_candidate_decision_service.py`
- `services/rex-api/tests/chat_service_fakes.py`

Steps:

1. Decide whether sessions live in DB or conversation metadata.
2. Record selected candidate IDs when Rex lists pending review items.
3. Resolve `these`, `those`, and `confirm them` against the explicit session.
4. Expire stale sessions.

Done looks like:

- Candidate review state is explicit, inspectable, and testable.

Acceptance criteria:

- [x] No hidden marker or implicit-only state.
- [x] Session can be recovered across requests.
- [x] Explicit `approve all pending` still applies all eligible pending items,
  not only the stored session.
- [ ] Manual phone test confirms persisted review-session behavior after deploy.

## Phase 6 - Voice Turn Overlap Follow-Up

Goal: Address voice overlap after memory review reliability is stable.

Files to change:

- `apps/mobile/lib/rex/voice/application/voice_call_controller.dart`
- Possible new voice coordinator modules
- `services/rex-api/app/services/voice_stream_session.py`

Steps:

1. Add tests around `turn_in_progress`.
2. Prevent mobile from sending `utterance.end` while waiting for assistant done.
3. Split voice controller by lifecycle/stream/playback responsibility.

Done looks like:

- No "Rex is still answering previous voice turn" during screenshot/background
  resume smoke test.

Acceptance criteria:

- [ ] Voice controller starts shrinking toward standards guardrails.
- [ ] Phone smoke test passes.

## Verification Commands

Backend:

```bash
cd services/rex-api
python3 -m pytest tests/test_chat_candidate_decisions.py tests/test_chat_candidate_phone_phrases.py tests/test_memory_candidate_decision_service.py -q
```

Broader memory:

```bash
cd services/rex-api
python3 -m pytest tests/test_chat_candidate_decisions.py tests/test_chat_candidate_phone_phrases.py tests/test_memory_candidate_decision_service.py tests/test_memory_reliability_flow.py tests/test_chat_simple_memory_flow.py tests/test_memory_turn_service.py tests/test_memory_post_turn_service.py tests/test_memory_candidate_service.py -q
```

## Execution Order

1. Phase 1 - Phone-Test Regression Tests
2. Phase 2 - Candidate Review Intent Classifier
3. Phase 3 - Extraction Gate For Memory-Management Turns
4. Phase 4 - Mixed Approve-With-Correction
5. Phase 5 - Explicit Review Session Contract
6. Phase 6 - Voice Turn Overlap Follow-Up

## Release Gate

Ship only when:

- [ ] Phone-test phrase tests pass.
- [ ] Existing memory reliability tests pass.
- [ ] Pending count does not increase during candidate review.
- [ ] Manual phone test confirms pending review behavior.
