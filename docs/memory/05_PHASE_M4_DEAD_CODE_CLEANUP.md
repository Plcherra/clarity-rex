# Phase M4 — Dead Code and Doc Cleanup

## Goal

Remove or wire orphaned memory subsystems, consolidate scripts, and document legacy migration story.

## Prerequisites

- [M3 acceptance criteria pass](04_PHASE_M3_MOBILE_ENTITY_ALIGNMENT.md)

## Current Gaps

- ~~[`memory_verification_service.py`](../../services/rex-api/app/services/memory_verification_service.py) — orphaned after candidate/confirmation tables dropped.~~ Removed in M4.
- [`MemoryDisciplineService`](../../services/rex-api/app/services/memory_discipline_service.py) — wired by M1 on create hot paths.
- ~~Duplicate [`backfill_structured_memory.py`](../../services/rex-api/scripts/backfill_structured_memory.py) and [`backend/scripts/backfill_structured_memory.py`](../../services/rex-api/backend/scripts/backfill_structured_memory.py).~~ Consolidated to `scripts/` in M4.
- ~~[`apply_memory_discipline.py`](../../services/rex-api/scripts/apply_memory_discipline.py) — misleading name (runs corrections, not discipline).~~ Renamed to `apply_memory_corrections.py` in M4.
- Legacy migrations created then dropped: `memory_candidates`, `memory_confirmations`, review sessions.
- `SupabaseMemoryService` mixes conversations + memory — naming confusion.

## Files to Modify

- Delete or wire `memory_verification_service.py` and its tests if unused.
- Consolidate to one canonical backfill script path; update README/runbook references.
- Rename `apply_memory_discipline.py` → `apply_memory_corrections.py` (or document clearly).
- [`docs/MEMORY_RECALL_SOURCE_OF_TRUTH.md`](../MEMORY_RECALL_SOURCE_OF_TRUTH.md) — legacy table drop story, facade naming note.
- [`docs/project-completion/03_REX_MEMORY_AND_RECALL_PLAN.md`](../project-completion/03_REX_MEMORY_AND_RECALL_PLAN.md) — mark god-file splits complete.

## Step-by-Step Work Plan

### 1. Audit orphans

- Grep for `MemoryVerificationService`, `memory_candidates`, `memory_confirmations` in production code.
- Delete dead modules or wire to discipline applier if still needed.

### 2. Consolidate scripts

- Keep one `scripts/backfill_structured_memory.py`; remove duplicate or make it a thin wrapper.

### 3. Fix ops script naming

- Rename correction script; update any docs/CI references.

### 4. Document facade

- In source-of-truth doc, note `SupabaseMemoryService` scope (conversations + memory). Defer rename unless trivial.

### 5. Final test pass

- Full memory + recall test suite.

## Acceptance Criteria

- [x] No unused `MemoryVerificationService` in production imports.
- [x] One canonical backfill script path documented.
- [x] Ops script name matches behavior.
- [x] Legacy migration drops documented in source-of-truth.
- [x] Full memory test suite passes.

## Verification

```bash
cd services/rex-api
python -m pytest tests/ -q -k "memory or recall or entity" --ignore=tests/integration 2>/dev/null || python -m pytest tests/test_memory_turn_service.py tests/test_memory_discipline_service.py tests/test_memory_correction_service.py tests/test_chat_context_service.py -q

cd apps/mobile
flutter test test/memory_page_test.dart test/memory_api_test.dart test/memory_label_test.dart
```

## Manual Smoke

1. Run backfill script dry-run or help — correct path works.
2. No import errors on API startup.

## Deferred

- Renaming `SupabaseMemoryService` to `SupabaseAssistantStore` (large blast radius)
- Hybrid chat search implementation

---

## Post-M4 reminder — wire chat-derived plan discipline

**Do this immediately after M4 acceptance passes.** Do not start during M0–M4; it is new product behavior, not refactor cleanup.

### Context (from M2)

Today every **live** plan write goes through `PlanService` with `discipline_write_channel: confirmed_plan_service`, which skips chat plan-intelligence gating. That fixed explicit goal commands, Knows/API creates, and merge/dedup.

What is **not wired yet**: conversational plan candidates where Rex infers a plan from chat (not an explicit goal phrase) and discipline would return `ASK_CONFIRMATION`, `CREATE_MILESTONE`, or `CREATE_COMMITMENT` via raw `MemoryDisciplineService.decide()` on a PLAN payload **without** the confirmed channel.

That routing code exists and is tested (`test_memory_discipline_service.py`, `test_plan_intelligence_service.py`), but **no chat/voice path calls it today**. See M2 gap table: [`03_PHASE_M2_SPLIT_GOD_FILES.md`](03_PHASE_M2_SPLIT_GOD_FILES.md) — “Chat plan intelligence”.

### Policy until this ships

- **All durable plan writes must go through `PlanService`** (confirmed channel).
- Do not call `execute_disciplined_create(PLAN, …)` from chat/brain without confirmation UX or the confirmed channel.

### Work to do (post-M4)

1. **Product decision** — When Rex proposes a plan from conversation (not `GoalCommandService`), what does the user see?
   - Confirm save as top-level plan?
   - Confirm route under existing plan as milestone/commitment?
   - Decline / clarify?

2. **Chat confirmation UX** — Map discipline outcomes to pending actions:
   - `ASK_CONFIRMATION` → “Rex wants to save this as a plan — confirm?”
   - `CREATE_MILESTONE` / `CREATE_COMMITMENT` → explain parent plan + confirm before write
   - On confirm → write through `PlanService` or disciplined apply with explicit user consent metadata

3. **Backend wiring** — One entry point from chat orchestrator (after user confirms):
   - Either always `PlanService.create_plan` with appropriate metadata, **or**
   - `execute_disciplined_create` with a new channel such as `chat_confirmed_plan` after confirmation (not before)

4. **Voice parity** — Same flow as chat; no separate brain or truth policy.

5. **Tests** — End-to-end: ambiguous plan phrase → confirmation prompt → backend-confirmed write → Knows shows plan (or milestone/commitment as chosen). No fake success.

### Suggested acceptance criteria

- [ ] Ambiguous chat plan phrase does not silently fail or save without confirmation.
- [ ] Confirmed write appears in Knows with backend-confirmed `memory_changes`.
- [ ] Plan intelligence milestone/commitment routing is user-visible when it applies.
- [ ] Explicit goal commands and Knows manual create still use confirmed service channels (regression tests pass).
- [ ] Voice turn matches chat behavior.

### References

- `app/services/plan_intelligence_service.py` — routing rules
- `app/services/memory_discipline_confirmed_writes.py` — confirmed write channels
- `app/services/goal_command_service.py` — explicit goals (already wired; do not break)
- M2 discipline gap review: [`03_PHASE_M2_SPLIT_GOD_FILES.md`](03_PHASE_M2_SPLIT_GOD_FILES.md)
