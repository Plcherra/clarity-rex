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

- [ ] Each listed file is under 500 lines (target under 300).
- [ ] All existing memory/recall tests pass after each split.
- [ ] No new production imports of experimental brain paths.
- [ ] Mobile edit flows unchanged from user perspective.

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
