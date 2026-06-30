# Phase M1 — Memory Lifecycle, Discipline, and Manual Knows Create

## Goal

Define one write lifecycle, wire `MemoryDisciplineService` into saves, add manual create in Knows, and document the lifecycle in source-of-truth docs.

## Prerequisites

- [M0 acceptance criteria pass](01_PHASE_M0_STABILIZE_TRUTH.md)

## Current Gaps

- `MemoryDisciplineService` (~461 lines) is tested in isolation but never called from production save/create paths.
- No `POST /memory` for flat fact create; mobile has no create UI.
- POST routes exist for entities, rules, plans, commitments but mobile only uses PATCH/DELETE.
- Lifecycle is implicit across `memory_turn_service`, materializer, and Knows refresh.

## Target Lifecycle

```text
UserIntent → DisciplineCheck → BackendConfirmedWrite → OptionalMaterialize → memory_changes → KnowsRefresh
```

## Files to Create

### Backend

- [`services/rex-api/app/models/memory.py`](../../services/rex-api/app/models/memory.py) — add `MemoryCreateRequest`
- [`services/rex-api/tests/test_memory_create_routes.py`](../../services/rex-api/tests/test_memory_create_routes.py)
- [`services/rex-api/tests/test_memory_discipline_integration.py`](../../services/rex-api/tests/test_memory_discipline_integration.py)

### Mobile

- [`apps/mobile/lib/rex/memory/presentation/widgets/memory_create_sheets.dart`](../../apps/mobile/lib/rex/memory/presentation/widgets/memory_create_sheets.dart)
- [`apps/mobile/test/memory_create_flow_test.dart`](../../apps/mobile/test/memory_create_flow_test.dart)

## Files to Modify

### Backend

- [`services/rex-api/app/routes/memory.py`](../../services/rex-api/app/routes/memory.py) — `POST /memory`
- [`services/rex-api/app/services/entity_service.py`](../../services/rex-api/app/services/entity_service.py) — discipline before `create_entity`
- [`services/rex-api/app/services/memory_turn_service.py`](../../services/rex-api/app/services/memory_turn_service.py) — discipline before confirmed saves
- Plan/rule/commitment create services or route handlers — discipline before insert
- [`services/rex-api/app/dependencies.py`](../../services/rex-api/app/dependencies.py) — wire `MemoryDisciplineService`
- [`docs/MEMORY_RECALL_SOURCE_OF_TRUTH.md`](../MEMORY_RECALL_SOURCE_OF_TRUTH.md) — lifecycle diagram

### Mobile

- [`apps/mobile/lib/rex/memory/data/memory_saved_api.dart`](../../apps/mobile/lib/rex/memory/data/memory_saved_api.dart) — `createMemory`
- [`apps/mobile/lib/rex/memory/data/memory_structured_api.dart`](../../apps/mobile/lib/rex/memory/data/memory_structured_api.dart) — create methods
- [`apps/mobile/lib/rex/memory/application/memory_action_controller.dart`](../../apps/mobile/lib/rex/memory/application/memory_action_controller.dart) — create actions
- [`apps/mobile/lib/rex/memory/presentation/pages/memory_page.dart`](../../apps/mobile/lib/rex/memory/presentation/pages/memory_page.dart) — Add FAB / type picker
- [`apps/mobile/lib/l10n/app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb) — create flow strings

## Step-by-Step Work Plan

### 1. Document lifecycle

- Add write lifecycle diagram to `MEMORY_RECALL_SOURCE_OF_TRUTH.md`.
- Define when materialization runs (save only, post-M0).

### 2. Wire MemoryDisciplineService

- Inject into entity create, plan/rule/commitment create, memory turn confirmed save, and new `POST /memory`.
- On duplicate detection: merge, update, or return 409 with related records — follow existing `decide()` / `apply_decision()` semantics.
- Add integration tests proving duplicate person/plan is blocked or merged.

### 3. Add POST /memory

- `MemoryCreateRequest`: content, memory_type, optional metadata (memory_category, entity_label).
- Run discipline + category inference via `long_term_memory_repository`.
- Return 201 with id; verify active visibility before success.

### 4. Mobile create API

- `createMemory`, `createPerson`, `createRule`, `createPlan`, `createCommitment` on `MemoryApi`.
- Map errors to l10n via `memory_controller_errors.dart`.

### 5. Knows create UI

- Header FAB or “Add” → type picker (Fact, Preference, Person, Rule, Plan, Commitment).
- Bottom sheet forms reusing patterns from edit sheets.
- Success: snackbar only after 201 + `loadSavedOverview()`.
- Category picker aligned with [`memory_categories.py`](../../services/rex-api/app/services/memory_categories.py).

### 6. Person create materialization

- After person or person-category fact create, run materializer on save path if applicable.

## Acceptance Criteria

- [x] Lifecycle documented in `MEMORY_RECALL_SOURCE_OF_TRUTH.md`.
- [x] `MemoryDisciplineService` runs on all structured and flat creates.
- [x] `POST /memory` creates backend-confirmed flat memory.
- [x] Knows can create each supported record type.
- [x] Success UI only after backend returns id.
- [x] Duplicate entity/plan attempts are handled by discipline policy (not silent duplicates).
- [x] Integration tests pass.

## Verification

```bash
cd services/rex-api
python -m pytest tests/test_memory_create_routes.py tests/test_memory_discipline_integration.py tests/test_memory_discipline_service.py tests/test_entity_service.py tests/test_structured_memory_routes.py -q

cd apps/mobile
flutter test test/memory_create_flow_test.dart test/memory_page_test.dart test/memory_api_test.dart
flutter gen-l10n
```

## Manual Smoke

1. Knows → Add → create a fact; appears in correct group.
2. Knows → Add → create a person; appears under People.
3. Try creating duplicate person name; confirm discipline behavior (merge or clear error).
4. Rex chat save still works; Knows refreshes.

## Deferred

- Entity events create UI
- Plan milestone create UI
- Corrections history tab
