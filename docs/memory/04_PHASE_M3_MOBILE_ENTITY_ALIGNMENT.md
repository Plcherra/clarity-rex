# Phase M3 — Mobile Entity Alignment and Knows Polish

## Goal

Align mobile Knows with the full backend entity model, remove legacy layers, localize labels, and handle pagination.

## Prerequisites

- [M2 acceptance criteria pass](03_PHASE_M2_SPLIT_GOD_FILES.md)

## Current Gaps

- Mobile fetches only `entity_type=person` from `/entities`.
- `MemoryLayer` / `loadMemories()` still in state but unused by UI.
- Group and type labels hardcoded English in [`memory_labels.dart`](../../apps/mobile/lib/rex/memory/data/memory_labels.dart).
- JSON parsing duplicated across memory models.
- 50-item limit per resource with no pagination UI.

## Files to Create

- [`apps/mobile/lib/rex/memory/data/memory_json_parsing.dart`](../../apps/mobile/lib/rex/memory/data/memory_json_parsing.dart)
- [`apps/mobile/lib/rex/memory/presentation/widgets/entity_memory_tile.dart`](../../apps/mobile/lib/rex/memory/presentation/widgets/entity_memory_tile.dart) (or type-specific place/org tiles)
- [`apps/mobile/test/memory_entity_types_test.dart`](../../apps/mobile/test/memory_entity_types_test.dart)

## Files to Modify

- [`apps/mobile/lib/rex/memory/data/memory_structured_api.dart`](../../apps/mobile/lib/rex/memory/data/memory_structured_api.dart) — fetch all entity types
- [`apps/mobile/lib/rex/memory/data/person_memory_model.dart`](../../apps/mobile/lib/rex/memory/data/person_memory_model.dart) — generalize or add `EntityMemoryItem` with `entityType`
- [`apps/mobile/lib/rex/memory/application/memory_controller.dart`](../../apps/mobile/lib/rex/memory/application/memory_controller.dart) — remove `MemoryLayer`, `selectedLayer`
- [`apps/mobile/lib/rex/memory/application/memory_read_controller.dart`](../../apps/mobile/lib/rex/memory/application/memory_read_controller.dart) — remove `loadMemories()`
- [`apps/mobile/lib/rex/memory/presentation/widgets/saved_memory_group_list.dart`](../../apps/mobile/lib/rex/memory/presentation/widgets/saved_memory_group_list.dart) — render place/org entities
- [`apps/mobile/lib/rex/memory/data/memory_labels.dart`](../../apps/mobile/lib/rex/memory/data/memory_labels.dart) — delegate labels to l10n
- [`apps/mobile/lib/l10n/app_en.arb`](../../apps/mobile/lib/l10n/app_en.arb) / [`app_es.arb`](../../apps/mobile/lib/l10n/app_es.arb) — memory group and type keys
- Model files using duplicated parsers — import shared parsing

## Step-by-Step Work Plan

### 1. Fetch all entities

- `GET /entities` without type filter (or fetch person + place + organization).
- Map `entity_type` to Knows groups (People, Places, Other).

### 2. Entity tiles

- Add tiles for non-person entities or generic `EntityMemoryTile` with type chip.
- Edit/archive via existing PATCH/DELETE routes.

### 3. Remove MemoryLayer

- Delete `loadMemories()`, `MemoryLayer` enum usage, `selectedLayer` state.
- Single loader: `loadSavedOverview()`.

### 4. Localize labels

- Move `MemoryGroup.label`, `MemoryType.label`, record type labels to ARB.
- Update Spanish smoke if needed.

### 5. Shared JSON parsing

- Extract `_string`, `_dateTime`, etc. to `memory_json_parsing.dart`.

### 6. Pagination

- Detect when any list hits limit 50; show “Load more” (increases limit to 100) or user-visible truncation note.
- Entity cards show up to two recent entity events as preview labels when available.

## Acceptance Criteria

- [x] Place (and other) entities appear in Knows when present in backend.
- [x] `MemoryLayer` / `loadMemories()` removed from mobile memory module.
- [x] Memory group headers use l10n (English + Spanish).
- [x] Shared JSON parsing module used by all memory models.
- [x] Truncation at 50 items is visible or paginated.
- [x] Load more increases overview limit to 100 when truncated.
- [x] Entity cards show up to two recent entity-event preview chips.
- [x] Rule/plan/commitment type labels use l10n (English + Spanish).
- [x] Plan cards show up to two milestone preview chips when present.
- [x] Knows overview uses backend cursor pagination with load-more append.
- [x] All memory widget tests pass.

## Verification

```bash
cd apps/mobile
flutter test test/memory_page_test.dart test/memory_entity_types_test.dart test/memory_label_test.dart test/l10n_spanish_smoke_test.dart
flutter gen-l10n
```

## Manual Smoke

1. Backend has a place entity; confirm it shows in Knows Places group.
2. Switch app to Spanish; Knows group headers are translated.
3. Account with 50+ memories shows load-more and can fetch additional pages.

## Deferred

- ~~Plan milestone create/edit UI in Knows~~ — preview chips plus plan-card add/edit milestone flows (M3 follow-up)
