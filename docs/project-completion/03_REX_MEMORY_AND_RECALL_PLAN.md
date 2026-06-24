# Rex Memory And Recall Completion Plan

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

### 4. Memory Corrections

- Decide whether memory correction history is user-facing.
- If user-facing:
  - Add Knows correction history or memory detail view.
  - Surface backend `/memory/corrections`.
- If backend-only:
  - Document it as internal audit history.

### 5. Entity Memory

- Complete entity/person cards as the primary structured Knows view.
- Avoid duplicate active flat and structured records for the same fact.
- Add entity event UI only if it improves the product now.
- Keep entity grouping clear: People, Places, Events, Goals, Preferences, Facts.

### 6. Cleanup Oversized Services

Priority backend modules:

- `memory_correction_service.py`
- `person_memory_materializer.py`
- `memory_turn_direct_helpers.py`
- `memory_reference_resolver.py`
- `chat_recall_search.py`
- `chat_recall_excerpts.py`
- `memory_retrieval_ranker.py`

Split by responsibility, not by arbitrary helper extraction.

## Acceptance Criteria

- Rex never treats chat history as saved memory.
- Rex reports degraded recall honestly.
- Knows reflects backend saved memory truth.
- Recall tests pass for arbitrary people, places, dates, goals, payments, devices, and exact phrases.
- No production recall logic contains smoke-topic-specific branches.

## Suggested Tests

- Backend recall tests.
- Memory turn service tests.
- Memory correction tests.
- Chat context service tests.
- Voice memory parity tests.
- Mobile memory page and memory controller tests.

## Manual Smoke

1. Tell Rex a fact and ask it to save it.
2. Confirm backend save and Knows display.
3. Ask Rex what it remembers.
4. Ask Rex about something from old chat that is not saved memory.
5. Confirm Rex labels it as chat history.
6. Archive memory in Knows.
7. Confirm Rex no longer treats it as active saved knowledge.
