# Rex Brain Trust And Reliability Plan

Single follow-up plan for making Rex Brain trustworthy at 500–1k users. Tracks P0/P1/P2 work, failure classes, file splits, and PR order so context is not lost across sessions.

**Related plans:** [04_GOALS_ACCOUNTABILITY_PLAN](../project-completion/04_GOALS_ACCOUNTABILITY_PLAN.md) · [03_REX_MEMORY_AND_RECALL_PLAN](../project-completion/03_REX_MEMORY_AND_RECALL_PLAN.md) · [07_BACKEND_INFRASTRUCTURE_PLAN](../project-completion/07_BACKEND_INFRASTRUCTURE_PLAN.md)

**Enforcement:** `.cursor/rules/FILE-SIZE-AND-SPLIT-md.mdc` (always applied)

---

## Problem Statement

- **Parser/guard fragility does not scale** — one regex or phrase-order bug affects every user.
- **God files make fixes riskier** — `goal_command_service.py` is ~1,408 lines (2.8× the hard limit).
- **Three truth paths can disagree** — Goals tab (`/accountability/overview`), Rex context loaders, and direct pre-LLM handlers filter goals/commitments differently.
- **Pre-LLM parsers and post-LLM truth guards fight each other** — inventory questions rewritten as delete clarifications; valid list answers blocked.

```text
User message
  -> ChatTurnOrchestrator
  -> GoalCommandService (may short-circuit, no LLM)
  -> MemoryTurnService (may short-circuit, no LLM)
  -> SimpleRexBrain + Grok
  -> ChatResponseTruthService (may rewrite answer)
```

---

## Recently Fixed (Pre-P0 Baseline)

**Verified 2026-06-25:** Committed and pushed as `902398c` on `main`. Tests: **43 passed** (`test_goal_command_*`, `test_goal_context_service`, `test_memory_delete_reference`, `test_action_truth_policy`). **Deploy Rex API to VPS before treating as live.**

| Item | Files | Code | Committed | Deployed |
|------|-------|------|-----------|----------|
| Goals/commitments inventory detection | `goal_command_parsing.py` | [x] | [x] | [ ] |
| Direct list handler | `goal_command_service.py` — `_try_list_goals_and_commitments()` | [x] | [x] | [ ] |
| Standalone commitment filter | `goal_context_service.py` — `_is_related_commitment()` | [x] | [x] | [ ] |
| Skip delete clarification for inventory | `memory_delete_reference.py`, `action_truth_policy.py` | [x] | [x] | [ ] |
| Goal/commitment delete before generic memory delete | `memory_correction_intent_parser.py` | [x] | [x] | [ ] |
| Regression tests | `test_goal_context_service.py` (new), others updated | [x] | [x] | n/a |
| Brain trust plan + master/backend plan links | `REX_BRAIN_TRUST_RELIABILITY_PLAN.md`, completion plans | [x] | [x] | n/a |

**Next step:** Deploy Rex API, then start P0-1.

**Symptoms addressed:** "What commitments do we have?" returning delete fallback; delete commitment failures; malformed single goal bodies from numbered lists.

---

## P0 — Trust Blockers (Do First)

Run P0 **before** adding more goal/memory parser patches.

| ID | Status | Issue | Generic failure class | Primary files | Acceptance criteria |
|----|--------|-------|----------------------|---------------|---------------------|
| P0-1 | [ ] | **Single accountability snapshot** | UI and Rex read different filtered sets | `accountability_context_loader.py`, `goal_context_service.py`, new `accountability_snapshot.py` | "What commitments do we have?" matches Goals tab exactly |
| P0-2 | [ ] | **AccountabilityQueryService** | Ad-hoc list logic in god file | Extract from `goal_command_service.py` | All inventory/list/show turns use one read-only service |
| P0-3 | [ ] | **Unified delete/update resolver** | Competing parsers (memory vs goal vs commitment) | `memory_reference_resolver.py`, `memory_correction_intent_parser.py`, `goal_command_parsing.py` | Delete/update via TABLE_SPECS + resolver; no phrase-order luck |
| P0-4 | [ ] | **Explicit pending_action state** | History marker scavenging misroutes follow-ups | New `conversation_pending_action.py` + orchestrator wiring | "Yes delete it" uses stored pending action, not regex on last N messages |

### P0 Tests To Add

- Parity: `AccountabilityQueryService.list_open_commitments()` == `/accountability/overview` open commitments for same user.
- Inventory: "What commitments do we have saved?" never triggers delete clarification or truth rewrite.
- Delete flow: confirm → "yes" resolves via pending_action, not substring on history.
- Resolver: goal delete, commitment delete, memory delete each hit correct TABLE_SPEC regardless of message order.

---

## P1 — Structural Hardening

| ID | Status | Issue | Work |
|----|--------|-------|------|
| P1-1 | [ ] | **Split GoalCommandService** | See split map below; no behavior change PR |
| P1-2 | [ ] | **Intent router alignment** | `SimpleRexBrain.classify` intents match direct-handler coverage |
| P1-3 | [ ] | **Scoped truth guards** | `action_truth_policy.py` scoped by action type, not global "saved"/"delete" substring |
| P1-4 | [ ] | **Goal save quality** | Reject meta bodies; split numbered lists before persist; validation in writer module |

### GoalCommandService Split Map

Target: all modules under 300 lines.

| Module | Responsibility |
|--------|----------------|
| `goal_command_service.py` | Thin `handle_turn` orchestrator (~80 lines) |
| `goal_command_parsing.py` | Exists — patterns, detection, inventory scope |
| `goal_command_queries.py` | **NEW** — inventory list, read-only formatting |
| `goal_command_writer.py` | **NEW** — save goal/commitment/multiple |
| `goal_command_reclassify.py` | **NEW** — memory→goal move |
| `goal_command_formatting.py` | **NEW** (optional) — titles, categories, response text |

---

## P2 — Polish And Ops

| ID | Status | Issue | Work |
|----|--------|-------|------|
| P2-1 | [ ] | **Unified user language** | Goal vs Commitment vs Saved memory labels in prompts and direct answers |
| P2-2 | [ ] | **Legacy data repair** | One-off script: split malformed numbered-list goals (e.g. "2 goals. 1 buy…") |
| P2-3 | [ ] | **Turn observability** | Structured log per turn: handler short-circuit, resolver result, guard rewrites |
| P2-4 | [ ] | **Recall file splits** | `chat_recall_search.py`, `recall_intent_helper.py`, `memory_correction_service.py` |

---

## Multi-User (500–1k) Notes

- Prefer **deterministic read paths** over LLM for inventory, list, and delete confirmation.
- Every direct handler must stay **user-scoped** via Supabase RLS — no new global parser state.
- **No topic-specific patches** — fixes must improve generic failure classes (see REX recall guardrail).
- Add **regression tests per failure class**, not per screenshot phrase.
- Ship in **small PRs** — snapshot first, then resolver, then god-file split.

---

## Recommended PR Sequence

1. [x] Rule file + this plan doc + master plan index
2. [x] Commit/push recent goals/commitments fixes (`902398c`); [ ] deploy Rex API
3. [ ] P0-1 + P0-2 — snapshot + AccountabilityQueryService + parity tests
4. [ ] P0-4 — pending_action conversation state
5. [ ] P0-3 — unified delete/update resolver
6. [ ] P1-1 — GoalCommandService split (refactor only)
7. [ ] P1-3 + P1-4 — scoped guards and save quality
8. [ ] P2 items

---

## Current Oversized Files

| Lines | File | Priority |
|-------|------|----------|
| 1,408 | `goal_command_service.py` | P1-1 (after P0) |
| ~780 | `memory_correction_service.py` | P2-4 |
| ~596 | `chat_recall_search.py` | P2-4 |
| ~592 | `recall_intent_helper.py` | P2-4 |
| ~454 | `chat_turn_orchestrator.py` | Monitor; split if it grows |

---

## Progress Log

| Date | Change |
|------|--------|
| 2026-06-25 | Created plan; added FILE-SIZE-AND-SPLIT rule; linked from completion master plan |
| 2026-06-25 | Verified pre-P0 baseline: 43 tests pass; committed and pushed as `902398c` |
