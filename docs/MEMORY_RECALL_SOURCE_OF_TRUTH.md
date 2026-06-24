# Rex Memory And Recall Source Of Truth

This document starts Plan 03 by recording the current production memory and
recall boundaries.

## Non-Negotiable Truth Rules

- Saved memory is durable only after backend confirmation.
- Chat history is not saved memory.
- Knows shows saved/categorized backend memory, not unsaved chat search hits.
- Rex can search old chats for recall questions, but those results must be
  labeled as chat history unless explicitly saved later.
- Voice and chat use the same production Rex Brain path.
- No topic-specific recall branches are allowed for one smoke phrase, person,
  device, date, payment, employer, game, or family member.

## Current Production Paths

| Area | Backend | Mobile |
| --- | --- | --- |
| Chat turn | `ChatService`, `ChatTurnOrchestrator`, `SimpleRexBrain` | `ChatController`, `ChatApi` |
| Saved flat memory | `/memory`, `long_term_memory_repository.py` | `MemoryApi.getMemories`, `MemoryPage` |
| Structured memory | `/entities`, `/rules`, `/plans`, `/commitments` | `memory_structured_api.dart`, Knows tiles |
| Person/entity cards | `entity_service.py`, `person_memory_materializer.py` | person memory models and saved memory group list |
| Old chat search | `conversation_repository.py`, `chat_search_*`, `chat_recall_*` | Chats tab search and Rex recall context |
| Prompt labels | `prompt_memory_context.py`, `prompt_structured_context.py` | Not built on mobile |
| Truth enforcement | `chat_response_truth.py`, `action_truth_policy.py` | Chat UI displays backend response/action state |

## Current UX Decision

For MVP, Knows remains primarily read/edit/archive for backend-confirmed memory.
Manual memory creation in Knows is not yet marked required. If this changes, it
must use Rex API create routes or a new backend-confirmed create path and must
not bypass Rex memory truth rules.

## Recall Failure Classes

Fix recall by naming and addressing one of these generic classes:

- Query too broad or too narrow.
- Recent noisy chats outrank older factual chats.
- Excerpts drop nearby factual details.
- Search source is empty, filtered, partial, degraded, or unavailable.
- Prompt/truth labeling misstates what was retrieved.

## Source Labels Rex Must Preserve

| Source | Labeling rule |
| --- | --- |
| Saved flat memory | Saved memory / Clarity knows |
| Structured entity/person/rule/plan/commitment | Saved structured memory / Knows |
| Old chat result | Chat history / found in a past conversation |
| Failed or unavailable source | Degraded or unavailable; do not say nothing was found |

## Plan 03 Start Status

- Source-of-truth boundaries are documented here.
- Knows now labels flat durable records as `Saved memory`.
- Knows now labels structured records as `Structured memory`.
- The `Rules` memory group label is fixed so rules no longer appear under a
  duplicate `Preferences` label.
- The next implementation step should run targeted recall tests before changing
  retrieval code.
