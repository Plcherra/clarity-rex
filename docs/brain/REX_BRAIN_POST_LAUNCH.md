# REX_BRAIN_POST_LAUNCH.md

## 1. Purpose

This file tracks Rex Brain work that is important but too large or risky for launch on the 25th.

The active pre-launch plan lives in `docs/brain/REX_BRAIN_FINAL_RESET.md`. Do not pull items from this file into launch scope unless they directly fix a launch blocker.

Post-launch work should still follow the MVP architecture: one production Rex Brain, one saved-memory truth, one chat-search path, and no hidden memory saves.

## 2. Post-Launch Themes

- Make Knows and Rex recall share one coherent saved-knowledge model.
- Move long-term memory toward entity-first organization.
- Improve arbitrary old-chat recall beyond the launch keyword path.
- Continue shrinking large services after launch pressure is gone.
- Keep experimental brain work clearly outside production until there is a proven need.

## 3. Entity-First Knows And Rex Recall

**Goal**

Unify Knows and Rex recall around saved entities, while keeping existing flat memories visible and usable.

**Key files**

- `services/rex-api/app/services/structured_memory_repository.py`
- `services/rex-api/app/services/memory_retrieval_service.py`
- `services/rex-api/app/services/long_term_memory_repository.py`
- `services/rex-api/app/services/memory_turn_service.py`
- `services/rex-api/app/routes/entities.py`
- `services/rex-api/app/routes/memory.py`
- `apps/mobile/lib/rex/memory/application/memory_read_controller.dart`
- `apps/mobile/lib/rex/memory/data/person_memory_model.dart`
- `apps/mobile/lib/rex/memory/presentation/widgets/saved_memory_group_list.dart`
- `apps/mobile/lib/rex/memory/presentation/widgets/memory_page_filters.dart`

**Desired changes**

- Treat saved knowledge as entity-first: People, Places, Events, Goals, Preferences, and Other.
- Make Person cards the main saved-knowledge experience for people.
- Keep flat long-term memories as compatibility records.
- Make Rex recall retrieve the same saved entity source that Knows displays.
- Keep chat history out of Knows unless explicitly saved.
- Keep active/inactive filtering consistent across UI and assistant recall.

**Success criteria**

- If Knows shows a Person card, Rex can recall and summarize that person.
- A person with multiple clear facts appears as one coherent card, not scattered rows.
- Existing flat memories remain visible, searchable, and editable where currently supported.
- Chat search results never appear in Knows unless explicitly saved.

## 4. Rich Person Cards

**Goal**

Make People memory useful as a real card, not only a name and summary.

**Possible attributes**

- Name
- Relationship
- Location
- Job or workplace
- Important dates
- Preferences
- Notes
- Linked source memory ids
- Linked conversations or messages
- Active/inactive status

**Guardrails**

- Do not force uncertain facts onto a person.
- Preserve source references where possible.
- Make wrong-name corrections safe and reversible.
- Avoid creating duplicate person cards for aliases or corrections.

## 5. Places, Events, Goals, Preferences, And Other

**Goal**

Extend entity-first memory beyond People without building a large new framework.

**Desired direction**

- Places should group location-related facts.
- Events should group birthdays, deadlines, appointments, and dated memories.
- Goals should connect saved goals, plans, milestones, and commitments.
- Preferences should remain easy to review and edit.
- Other should be a safe fallback for useful facts that do not fit cleanly.

**Success criteria**

- Knows can display these categories clearly.
- Rex can retrieve and summarize them as saved knowledge.
- Flat memories remain available when a fact is not safe to group.

## 6. Safe Flat-Memory Migration

**Goal**

Backfill only high-confidence flat memories into structured entities.

**Key files**

- `services/rex-api/app/services/structured_memory_backfill.py`
- `services/rex-api/tests/test_structured_memory_backfill.py`
- `services/rex-api/app/services/entity_normalization_service.py`
- `services/rex-api/app/services/entity_service.py`

**Rules**

- Migrate only clear, high-confidence facts.
- Leave uncertain, generic, or ambiguous memories flat.
- Never migrate chat history automatically.
- Preserve source memory ids.
- Keep migrated flat memories visible or traceable until the replacement model is proven.

**Examples**

- Good: named person facts that clearly refer to the same person.
- Good: a clear location fact such as a saved home city.
- Risky: vague references like "the girl from work" unless a confirmed entity exists.
- Bad: old chat mentions that were never explicitly saved.

## 7. Hybrid Chat Search

**Goal**

Improve old-chat recall beyond simple keyword search while keeping chat history distinct from saved memory.

**Reference**

Use `docs/brain/REX_BRAIN_HYBRID_CHAT_SEARCH.md` as the direction for future retrieval.

**Desired changes**

- Combine keyword and semantic search.
- Rank at the conversation level, not only isolated messages.
- Keep strict current-user scoping.
- Return compact, useful excerpts.
- Clearly label results as chat history.
- Report unavailable or degraded search honestly.

**Success criteria**

- Rex can answer arbitrary recall questions with fewer aliases and patches.
- Search works from fresh chats and older conversations.
- Chat search never becomes durable memory without explicit save action.

## 8. Larger Service Cleanup

**Goal**

Continue splitting large files after launch without destabilizing MVP behavior.

**Candidates**

- `services/rex-api/app/services/chat_context_service.py`
- `services/rex-api/app/services/memory_intent_service.py`
- `services/rex-api/app/services/entity_service.py`
- `services/rex-api/app/services/plan_service.py`
- `services/rex-api/app/services/rex_intent_router.py`

**Rules**

- Extract one clear responsibility at a time.
- Keep tests passing after each split.
- Prefer small services over broad manager files.
- Do not create another production brain or context god file.

## 9. Advanced Rex Brain Work

**Goal**

Revisit advanced routing only if launch data proves the simple brain is not enough.

**Allowed future work**

- Better intent checks.
- Better context ranking.
- Optional model routing for cost and latency.
- Better observability.
- Better prompt budgeting.

**Guardrails**

- Advanced routing must plug into the same production flow.
- It must not create a separate memory system.
- It must not make Grok less responsible for natural reasoning.
- It should remain disabled unless there is a measured need.

## 10. Post-Launch Verification Checklist

- Knows and Rex recall use the same saved entity source.
- Chat history remains searchable history, not saved memory.
- Person cards can hold multiple related facts.
- Places, Events, Goals, Preferences, and Other have minimal useful support.
- Flat memories remain visible and safe.
- High-confidence backfill works without unsafe grouping.
- Hybrid chat search improves arbitrary recall.
- Large brain services keep shrinking over time.
- Experimental brain routing is either clearly deprecated or deliberately promoted with tests and rollout controls.
