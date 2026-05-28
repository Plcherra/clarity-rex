# File 03 - Context Retrieval And Budgets

Purpose: build the controlled context selection layer for Rex Brain. This is Master Plan Phase 3 / Workstream 00.03.

Current implementation status: Phase 3 is implemented as a pure context builder and tests only. It is not yet wired into live chat or voice prompt construction.

## Production Guardrail

`RexBrainContext` is a selection contract, not a live prompt integration. It must not replace `PromptService`, change financial context payloads sent by mobile, or alter chat/voice behavior until a later integration phase enables Rex Brain routing.

## Context Contract

The context builder accepts:

- `RexBrainDecision`
- recent chat messages
- optional unified Clarity financial context
- optional relevant long-term memories
- optional structured memory context
- optional accountability signals

It returns `RexBrainContext` with:

- context budget tier
- financial scope
- selected financial context
- selected relevant memories
- selected structured context
- selected accountability signals
- selected recent messages
- diagnostics
- estimated character count

All metadata must remain safe: no secrets, no raw credentials, and no raw private context in diagnostics.

## Phase 3.1 - Context Requirements Map

Status: done.

Map each layer to needed context:

- Fast: recent chat only
- Contextual: memory and recent chat
- Analytical: financial read model snapshot when available
- Strategic: financial read model, goals/plans, memory, pending commitments
- Reflective: selected memory/context plus assumptions/debug metadata later
- Coaching: memory, rules, commitments, goals

Acceptance:

- Router decisions already expose expected context sources.
- Context builder respects those expected sources.

## Phase 3.2 - Budget Limit Contract

Status: done.

Create budget tiers matching router decisions:

- tiny
- small
- medium
- high

Each tier defines character budgets for:

- total context
- financial context
- memory context
- structured context
- accountability context
- recent chat

Acceptance:

- Tests verify large context is capped.
- Context truncation creates diagnostics instead of crashes.

## Phase 3.3 - Financial Context Scope

Status: done.

Create financial scopes:

- none
- summary only
- current month rollup
- full rollup
- selected records

Acceptance:

- Normal analysis avoids raw transaction dumps.
- Strategic planning uses rollups by default.
- High-budget analytical requests may include capped selected records.
- Degraded/missing financial context creates diagnostics.

## Phase 3.4 - Memory Ranking

Status: done.

Rank memories by:

1. corrections first
2. importance
3. recency

Acceptance:

- Durable corrections beat older facts.
- Memory context is capped by budget.

## Phase 3.5 - Goals And Pending Items

Status: done.

Select from structured context:

- plans
- plan milestones
- commitments
- personal rules
- entities/events when available
- accountability signals

Acceptance:

- Strategic/coaching turns can carry goals and pending work.
- Accountability signals rank critical/high before lower severity.

## Phase 3.6 - Context Safety Filter

Status: done.

Remove sensitive keys containing:

- access tokens
- authorization
- credentials
- passwords
- private keys
- refresh tokens
- secrets
- service role values

Acceptance:

- Tests verify secrets are removed from memories, structured context, financial context, and accountability signals.

## Phase 3.7 - Context Summary Builder

Status: done.

Create:

- `services/rex-api/app/services/rex_brain_context.py`
- `RexBrainContext`
- `RexFinancialContextScope`
- `build_rex_brain_context`

Acceptance:

- Chat and voice can eventually call the same builder.
- Existing `financial_context_service` payload shape remains compatible because this builder consumes plain dictionaries.

## Phase 3.8 - Context Tests

Status: done.

Required checks:

```sh
cd services/rex-api
python3 -m pytest tests/test_rex_brain_context.py
python3 -m pytest tests/test_rex_brain.py tests/test_rex_brain_prompts.py tests/test_rex_brain_context.py tests/test_prompt_service.py
```

Acceptance:

- Empty/missing context is graceful.
- Degraded financial context creates metadata.
- Large transaction history is capped.
- Corrected memory ranks first.
- Goals and pending items are selected.
- Safety filter removes secrets.

## Phase 3 Exit Criteria

Phase 3 is complete when:

- `rex_brain_context.py` exists.
- Context budget tiers exist and are tested.
- Financial scope selection exists and is tested.
- Memory ranking prioritizes corrections.
- Strategic/coaching context can include goals and pending items.
- Safety filtering removes sensitive fields.
- Live chat/voice behavior remains unchanged.

## Next Workstream

Move to File 04 / Model Routing And Cost Control only after context selection tests are green and the builder remains non-invasive.
