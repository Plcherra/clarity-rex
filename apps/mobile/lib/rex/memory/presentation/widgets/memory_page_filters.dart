import 'package:clarity/rex/memory/application/memory_controller.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_results.dart';

SavedMemoryResults filterSavedMemory({
  required MemoryState state,
  required String query,
  required MemoryQuickFilter quickFilter,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final showPeopleOnly = quickFilter == MemoryQuickFilter.people;
  final showPreferencesOnly = quickFilter == MemoryQuickFilter.preferences;
  final coveredSourceMemoryIds = {
    for (final person in state.people) ...person.sourceMemoryIds,
    for (final entity in state.placeEntities) ...entity.sourceMemoryIds,
    for (final entity in state.otherEntities) ...entity.sourceMemoryIds,
  };
  final coveredWorkplaceLabels = {
    for (final person in state.people) ..._workplaceLabelsForPerson(person),
  };
  final dedupedOtherEntities = _dedupeSimilarOrganizations(state.otherEntities);

  List<T> filterList<T>(Iterable<T> items, bool Function(T item) matches) {
    return items.where(matches).toList(growable: false);
  }

  final memories = filterList(state.memories, (memory) {
    if (coveredSourceMemoryIds.contains(memory.id)) {
      return false;
    }
    final canonicalEntityId = memory.metadata['canonical_entity_id']?.toString();
    if (canonicalEntityId != null && canonicalEntityId.isNotEmpty) {
      return false;
    }
    if (showPeopleOnly && memory.memoryGroup != MemoryGroup.people) {
      return false;
    }
    if (showPreferencesOnly && memory.memoryType != MemoryType.preference) {
      return false;
    }
    return _matchesQuery(normalizedQuery, [
      memory.content,
      memory.memoryType.label,
      memory.categoryLabel,
      'Importance ${memory.importance}',
    ]);
  });

  return SavedMemoryResults(
    facts: showPreferencesOnly || showPeopleOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.facts)
              .toList(growable: false),
    preferences: showPeopleOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.preferences)
              .toList(growable: false),
    peopleMemories: showPreferencesOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.people)
              .toList(growable: false),
    people: showPreferencesOnly
        ? const []
        : filterList(
            state.people,
            (person) => _matchesQuery(
              normalizedQuery,
              person.searchableFields.map((field) => field.memoryRecordLabel),
            ),
          ),
    places: showPeopleOnly || showPreferencesOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.places)
              .toList(growable: false),
    placeEntities: showPeopleOnly || showPreferencesOnly
        ? const []
        : filterList(
            state.placeEntities,
            (entity) => _matchesQuery(
              normalizedQuery,
              entity.searchableFields.map((field) => field.memoryRecordLabel),
            ),
          ),
    // Goals/plans belong on the Goals tab only.
    goalMemories: const [],
    rules: showPeopleOnly || showPreferencesOnly
        ? const []
        : filterList(
            state.rules,
            (rule) => _matchesQuery(normalizedQuery, [
              rule.title,
              rule.ruleText,
              rule.ruleType.memoryRecordLabel,
              rule.triggerKeywords.join(' '),
              'Priority ${rule.priority}',
              rule.status.memoryRecordLabel,
            ]),
          ),
    plans: const [],
    events: showPeopleOnly || showPreferencesOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.events)
              .toList(growable: false),
    otherMemories: showPeopleOnly || showPreferencesOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.other)
              .toList(growable: false),
    otherEntities: showPeopleOnly || showPreferencesOnly
        ? const []
        : filterList(
            dedupedOtherEntities,
            (entity) {
              if (coveredWorkplaceLabels.contains(_normalizeOrgLabel(entity.displayName))) {
                return false;
              }
              return _matchesQuery(
                normalizedQuery,
                entity.searchableFields.map((field) => field.memoryRecordLabel),
              );
            },
          ),
  );
}

Iterable<String> _workplaceLabelsForPerson(PersonMemoryItem person) sync* {
  for (final value in [person.workplace, person.job]) {
    final normalized = _normalizeOrgLabel(value);
    if (normalized.isNotEmpty) {
      yield normalized;
    }
  }
}

String _normalizeOrgLabel(String? value) {
  final normalized = (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'\b(llc|inc|corp|corporation|company|co)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  return normalized;
}

List<EntityMemoryItem> _dedupeSimilarOrganizations(List<EntityMemoryItem> entities) {
  final bestByLabel = <String, EntityMemoryItem>{};
  for (final entity in entities) {
    final key = _normalizeOrgLabel(entity.displayName);
    if (key.isEmpty) {
      continue;
    }
    final existing = bestByLabel[key];
    if (existing == null || entity.importance > existing.importance) {
      bestByLabel[key] = entity;
    }
  }
  final keptIds = bestByLabel.values.map((entity) => entity.id).toSet();
  return entities.where((entity) {
    final key = _normalizeOrgLabel(entity.displayName);
    if (key.isEmpty) {
      return true;
    }
    return keptIds.contains(entity.id);
  }).toList(growable: false);
}

bool _matchesQuery(String query, Iterable<String?> fields) {
  if (query.isEmpty) {
    return true;
  }
  return fields.any((field) => field?.toLowerCase().contains(query) == true);
}
