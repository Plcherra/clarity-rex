# Phase M2 — Split God Files

## Goal

Reduce memory module complexity with behavior-neutral file splits. Target 150–300 lines per file; hard stop at 500.

## Prerequisites

- [M1 acceptance criteria pass](02_PHASE_M1_LIFECYCLE_AND_CREATE.md)

## Current Gaps

Backend files over limit:

| File | Lines | Issue |
|------|------:|-------|
| `person_memory_materializer.py` | ~664 | Save, read materialization, archival, parsing |
| `memory_turn_direct_helpers.py` | ~540 | Save dedup, equivalence, verification |
| `memory_turn_delete_helpers.py` | ~500 | Delete confirmation flow |
| `memory_reference_resolver.py` | ~503 | Knows matching |
| `entity_merge_service.py` | ~445 | Merge logic |

Mobile:

| File | Lines | Issue |
|------|------:|-------|
| `memory_edit_sheets.dart` | ~414 | All edit forms in one file |

## Split Order (one chunk per commit or PR)

### 1. `person_memory_materializer.py`

Extract:

- `person_card_builder.py` — build card payload from memory
- `person_memory_archival.py` — `_archive_covered_person_source_memories`, entity deactivate archival
- Keep thin `person_memory_materializer.py` orchestrating save-path materialize

### 2. `memory_turn_direct_helpers.py`

Extract:

- `memory_save_matcher.py` — topic/equivalence matching
- `memory_save_verifier.py` — post-save visibility verification

### 3. `memory_turn_delete_helpers.py`

Extract:

- `memory_delete_confirmation_flow.py` — pending action + confirmation UX steps

### 4. `memory_reference_resolver.py`

Extract:

- `memory_reference_scoring.py` — match scoring and ranking

### 5. `entity_merge_service.py`

Extract:

- `entity_merge_strategies.py` — merge decision helpers

### 6. `memory_edit_sheets.dart`

Extract per-type files:

- `memory_edit_person_sheet.dart`
- `memory_edit_rule_sheet.dart`
- `memory_edit_plan_sheet.dart`
- `memory_edit_commitment_sheet.dart`
- `memory_edit_flat_sheet.dart`
- Thin `memory_edit_sheets.dart` re-exports / routes to type

## Rules

- Move tests with extracted modules.
- No behavior changes in the same PR as a split unless fixing a test that exposed a bug.
- Run full memory test suite after each split.
- Do not introduce new abstractions or second memory systems.

## Files to Modify

All import sites of split modules across `services/rex-api/app/` and `apps/mobile/lib/rex/memory/`.

## Acceptance Criteria

- [x] Each listed file is under 500 lines (target under 300).
- [x] All existing memory/recall tests pass after each split (126+ backend; hardware goal and discipline gaps fixed).

## Bugfixes During M2 Verification

- `memory_discipline_writes.execute_disciplined_create`: long-term memory writes route through `_execute_long_term_memory_write` before the generic confirmation gate (fixes chat direct saves blocked by M1 discipline wiring).
- `memory_reference_models.py`: extracted `KnowsReferenceMatch` to break circular import with scoring module.
- `memory_discipline_confirmed_writes.py`: confirmed service-write channels so PlanService / EntityService / RuleService keep merge/dedup behavior instead of plan-intelligence or duplicate-update gates blocking user-confirmed creates.
- `PlanService`: tags confirmed writes, skips chat plan-intelligence routing, strips internal discipline metadata from persisted records.
- `RuleService`: restores create-or-merge by rule text/title for Knows and API creates.
- `EntityService`: confirmed-write channel + metadata stripping so merge_service owns dedup.

## Discipline Gap Review (M1 wiring)

| Write path | Gap | Fix |
|------------|-----|-----|
| Chat direct memory save | LTM blocked by ASK_CONFIRMATION | LTM fast-path in `execute_disciplined_create` |
| Explicit goal commands | Plan intelligence returned ASK_CONFIRMATION | Confirmed plan service channel |
| PlanService API / Knows | Merge/archive bypassed by discipline UPDATE | Skip duplicate discipline for confirmed service writes |
| EntityService / RuleService | Merge dedup bypassed by discipline UPDATE | Same confirmed channel pattern |
| Chat plan intelligence | Still applies for raw PLAN candidates without confirmed channel | Unchanged — `test_memory_discipline_service` routing tests still pass |
- [x] No new production imports of experimental brain paths.
- [x] Mobile edit flows unchanged from user perspective.

## Split Results

| Original | New modules | Lines (approx.) |
|----------|-------------|-----------------|
| `person_memory_materializer.py` | `person_card_builder.py`, `person_card_builder_text.py`, `person_card_constants.py`, `person_memory_archival.py`, thin orchestrator | 288 + 243 + 25 + 168 + 110 |
| `memory_turn_direct_helpers.py` | `memory_save_matcher.py`, `memory_save_verifier.py` | 310 + 249 + 31 |
| `memory_turn_delete_helpers.py` | `memory_delete_confirmation_flow.py` | 390 + 152 |
| `memory_reference_resolver.py` | `memory_reference_scoring.py`, `memory_reference_models.py` | 399 + 148 + 14 |
| `entity_merge_service.py` | `entity_merge_strategies.py` | 182 + 383 |
| `memory_edit_sheets.dart` | `memory_edit_shared_widgets.dart`, `memory_edit_flat_sheet.dart`, `memory_edit_structured_sheet.dart`, barrel | 52 + 39 + 161 + 226 |

## Bugfix During M2 Verification

- `memory_discipline_writes.execute_disciplined_create`: long-term memory writes now route through `_execute_long_term_memory_write` before the generic confirmation gate (fixes chat direct saves blocked by M1 discipline wiring).
- `memory_reference_models.py`: extracted `KnowsReferenceMatch` to break circular import with scoring module.

## Known Pre-existing Failure (M1, not M2)

- ~~`test_hardware_goal_message_creates_two_plans_without_llm`~~ Fixed via confirmed plan service writes.

## Verification

```bash
cd services/rex-api
python -m pytest tests/test_memory_turn_service.py tests/test_memory_reliability_flow.py tests/test_chat_simple_memory_flow.py tests/test_memory_correction_service.py tests/test_memory_reference_resolver.py tests/test_entity_service.py tests/test_memory_retrieval.py -q

cd apps/mobile
flutter test test/memory_page_test.dart test/memory_page_archive_errors_test.dart
```

## Manual Smoke

1. Save memory via chat.
2. Edit person and flat memory in Knows.
3. Delete memory with confirmation.
4. Recall question returns labeled context.

## Deferred

- Splitting `memory_intent_service.py` (lower priority if under 500 after M1)
- Splitting `chat_recall_search.py` (recall plan, not memory refactor)
