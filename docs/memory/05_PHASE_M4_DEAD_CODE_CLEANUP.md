# Phase M4 — Dead Code and Doc Cleanup

## Goal

Remove or wire orphaned memory subsystems, consolidate scripts, and document legacy migration story.

## Prerequisites

- [M3 acceptance criteria pass](04_PHASE_M3_MOBILE_ENTITY_ALIGNMENT.md)

## Current Gaps

- [`memory_verification_service.py`](../../services/rex-api/app/services/memory_verification_service.py) — orphaned after candidate/confirmation tables dropped.
- [`MemoryDisciplineService`](../../services/rex-api/app/services/memory_discipline_service.py) — should be wired by M1; if not, wire or delete here.
- Duplicate [`backfill_structured_memory.py`](../../services/rex-api/scripts/backfill_structured_memory.py) and [`backend/scripts/backfill_structured_memory.py`](../../services/rex-api/backend/scripts/backfill_structured_memory.py).
- [`apply_memory_discipline.py`](../../services/rex-api/scripts/apply_memory_discipline.py) — misleading name (runs corrections, not discipline).
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

- [ ] No unused `MemoryVerificationService` in production imports.
- [ ] One canonical backfill script path documented.
- [ ] Ops script name matches behavior.
- [ ] Legacy migration drops documented in source-of-truth.
- [ ] Full memory test suite passes.

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
