# Rex Memory And Recall Completion Plan

> **Execution:** Memory structure refactor and fixes follow the phased plan in
> [`docs/memory/00_MEMORY_REFACTOR_MASTER_PLAN.md`](../memory/00_MEMORY_REFACTOR_MASTER_PLAN.md)
> (M0–M4). This document remains the recall-quality and product goals reference.

## Goal

Make Rex reliably remember, search, label, edit, and explain user context without creating a second brain or topic-specific recall hacks.

## Current State

- Saved memory is durable only after backend confirmation.
- Old chat search is part of Rex recall but must be labeled as chat history, not saved memory.
- Knows can read, edit, and archive flat and structured memory.
- Memory creation mainly happens through chat and voice.
- Backend recall and memory code is real but complex and spread across many modules.
- Started: `docs/MEMORY_RECALL_SOURCE_OF_TRUTH.md` now records the production
memory and recall boundaries.

## Generic Failure Classes To Fix

Use these classes before changing recall behavior:

- Query too broad or too narrow.
- Recent noisy chats outrank older factual chats.
- Excerpts drop nearby factual details.
- Search source is empty, filtered, partial, degraded, or unavailable.
- Prompt/truth labeling misstates what was retrieved.

Do not add topic-specific logic for one smoke phrase, person, date, game, device, payment, employer, or family member.

## Work Plan

### 1. Saved Memory Truth

- Confirm all saved memories are backend-confirmed before Rex claims success.
- Keep Knows aligned with backend saved memory.
- Ensure archived/inactive records do not appear as active knowledge.
- Completed first source-label pass in Knows:
  - Flat durable records now show `Saved memory`.
  - Structured records now show `Structured memory`.
  - Rules group label now renders as `Rules`.
- Continue showing source category clearly:
  - Saved memory.
  - Structured entity.
  - Chat history.
  - Degraded/unavailable source.

### 2. Manual Memory Management Decision

- Current MVP decision pending UX audit: Knows remains read/edit/archive for
backend-confirmed memory.
- Decide if MVP needs manual create in Knows.
- If yes:
  - Add create flows for people, preferences, facts, rules, plans, and commitments through Rex API.
  - Preserve backend confirmation messaging.
- If no:
  - Label Knows as edit/archive for Rex-saved knowledge.
  - Keep creation through chat/voice only.

### 3. Recall Quality

- Keep one reusable recall pipeline:
  - Recall intent detection.
  - Query expansion.
  - User-scoped chat search.
  - Ranking.
  - Conversation-level excerpts.
  - Prompt labels.
  - Truth/status reporting.
- Improve ranking and excerpts for arbitrary topics.
- Add tests with unrelated examples, not only the observed smoke failure.
- Verification started: prompt labeling, chat search ranking, memory intent, and
memory reliability tests pass for the current code.
- Fixed generic failure class: memory intent construction was too narrow for
birthday corrections and contextual birthday replies. Equivalent people now use
the same generic birthday path instead of only the original family smoke terms.
- Fixed generic failure class: memory lookup/topic-shift protection included
specific family/birthday topic terms. It now uses generic recall/search
language so arbitrary people can still be saved as memory.
- Fixed generic failure class: inverted birthday parsing could steal
  `DATE as PERSON's birthday` phrases and produce invalid person labels such as
  `as my mom`. Date-as-birthday detection now runs first, accepts `your`, and
  resolves pronoun-only birthday follow-ups from recent relationship context.

### 4. Memory Corrections

- Completed MVP decision: memory correction history is backend/internal audit
history for now.
- Backend `/memory/corrections` remains available for diagnostics.
- Knows should not show a Corrections tab in MVP.
- If correction history becomes user-facing later, add it as a memory detail or
audit view, not as active saved knowledge.

### 5. Entity Memory

- Complete entity/person cards as the primary structured Knows view.
- Avoid duplicate active flat and structured records for the same fact.
- Add entity event UI only if it improves the product now.
- Keep entity grouping clear: People, Places, Events, Goals, Preferences, Facts.

### 6. Cleanup Oversized Services

**M2 god-file splits complete** (memory refactor phases M0–M3). Remaining
oversized modules below are optional hardening, not blockers for Plan 04.

Priority backend modules still eligible for future splits:

- `memory_correction_service.py`
- `person_memory_materializer.py`
- `memory_turn_direct_helpers.py`
- `memory_reference_resolver.py`
- `chat_recall_search.py`
- `chat_recall_excerpts.py`
- `memory_retrieval_ranker.py`

Split by responsibility, not by arbitrary helper extraction. Handle this as a
separate cleanup pass after Goals/Accountability work is underway or before a
dedicated backend hardening pass.

Plan 03 should not mix these large move/split refactors with behavior work unless
a concrete bug is found in one of the modules.

## Acceptance Criteria

- Rex never treats chat history as saved memory.
- Rex reports degraded recall honestly.
- Knows reflects backend saved memory truth.
- Recall tests pass for arbitrary people, places, dates, goals, payments, devices, and exact phrases.
- No production recall logic contains smoke-topic-specific branches.
- M2 memory god-file splits are complete (see `docs/memory/03_PHASE_M2_SPLIT_GOD_FILES.md`).
- Optional future service splits do not block Plan 04.

## Suggested Tests

- Backend recall tests.
- Memory turn service tests.
- Memory correction tests.
- Chat context service tests.
- Voice memory parity tests.
- Mobile memory page and memory controller tests.

## Verification Log

- `python -m pytest tests/test_prompt_service.py tests/test_chat_search_ranking.py tests/test_memory_intent_service.py tests/test_memory_reliability_flow.py -q`
  - Result: 54 passed.
- `python -m pytest tests/test_prompt_service.py tests/test_chat_search_ranking.py tests/test_memory_intent_service.py tests/test_memory_reliability_flow.py tests/test_chat_service_rex_brain.py -q`
  - Result: 65 passed.
- `python -m pytest tests/test_prompt_service.py tests/test_chat_search_ranking.py tests/test_memory_intent_service.py tests/test_memory_reliability_flow.py tests/test_chat_service_rex_brain.py tests/test_memory_retrieval.py -q`
  - Result: 85 passed.
- `flutter test test/memory_label_test.dart test/memory_api_test.dart test/memory_page_test.dart`
  - Result: passed after making scroll expectations target unique memory tile content.

## Manual Smoke

1. Tell Rex a fact and ask it to save it.
2. Confirm backend save and Knows display.
3. Ask Rex what it remembers.
4. Ask Rex about something from old chat that is not saved memory.
5. Confirm Rex labels it as chat history.
6. Archive memory in Knows.
7. Confirm Rex no longer treats it as active saved knowledge.

