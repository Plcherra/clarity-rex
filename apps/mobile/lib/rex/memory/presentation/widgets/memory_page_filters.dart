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
    goalMemories: showPeopleOnly || showPreferencesOnly
        ? const []
        : memories
              .where((memory) => memory.memoryGroup == MemoryGroup.goals)
              .toList(growable: false),
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
    plans: showPeopleOnly || showPreferencesOnly
        ? const []
        : filterList(
            state.plans,
            (plan) => _matchesQuery(normalizedQuery, [
              plan.title,
              plan.description,
              plan.desiredOutcome,
              plan.planType.memoryRecordLabel,
              'Priority ${plan.priority}',
              plan.status.memoryRecordLabel,
            ]),
          ),
    commitments: showPeopleOnly || showPreferencesOnly
        ? const []
        : filterList(
            state.commitments,
            (commitment) => _matchesQuery(
              normalizedQuery,
              [
                commitment.title,
                commitment.commitmentText,
                commitment.commitmentType.memoryRecordLabel,
                'Priority ${commitment.priority}',
                commitment.status.memoryRecordLabel,
              ],
            ),
          ),
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
            state.otherEntities,
            (entity) => _matchesQuery(
              normalizedQuery,
              entity.searchableFields.map((field) => field.memoryRecordLabel),
            ),
          ),
  );
}

bool _matchesQuery(String query, Iterable<String?> fields) {
  if (query.isEmpty) {
    return true;
  }
  return fields.any((field) => field?.toLowerCase().contains(query) == true);
}
