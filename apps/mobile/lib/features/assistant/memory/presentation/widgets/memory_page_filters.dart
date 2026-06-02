import 'package:clarity/features/assistant/memory/application/memory_controller.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_quick_filter.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/saved_memory_results.dart';

SavedMemoryResults filterSavedMemory({
  required MemoryState state,
  required String query,
  required MemoryQuickFilter quickFilter,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final showPeopleOnly = quickFilter == MemoryQuickFilter.people;
  final showPreferencesOnly = quickFilter == MemoryQuickFilter.preferences;

  List<T> filterList<T>(Iterable<T> items, bool Function(T item) matches) {
    return items.where(matches).toList(growable: false);
  }

  final memories = showPeopleOnly
      ? const <MemoryItem>[]
      : filterList(state.memories, (memory) {
          if (showPreferencesOnly &&
              memory.memoryType != MemoryType.preference) {
            return false;
          }
          return _matchesQuery(normalizedQuery, [
            memory.content,
            memory.memoryType.label,
            'Importance ${memory.importance}',
          ]);
        });

  return SavedMemoryResults(
    identity: showPreferencesOnly
        ? const []
        : memories
              .where(
                (memory) =>
                    memory.memoryType.memoryGroup == MemoryGroup.identity,
              )
              .toList(growable: false),
    preferences: showPeopleOnly
        ? const []
        : memories
              .where(
                (memory) =>
                    memory.memoryType.memoryGroup == MemoryGroup.preferences,
              )
              .toList(growable: false),
    people: showPreferencesOnly
        ? const []
        : filterList(
            state.people,
            (person) => _matchesQuery(normalizedQuery, [
              person.displayName,
              person.relationship,
              person.summary,
              person.aliases.join(' '),
              'Importance ${person.importance}',
              person.status.memoryRecordLabel,
            ]),
          ),
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
            (commitment) => _matchesQuery(normalizedQuery, [
              commitment.title,
              commitment.commitmentText,
              commitment.commitmentType.memoryRecordLabel,
              'Priority ${commitment.priority}',
              commitment.status.memoryRecordLabel,
            ]),
          ),
    recent: showPeopleOnly || showPreferencesOnly
        ? const []
        : memories
              .where(
                (memory) => memory.memoryType.memoryGroup == MemoryGroup.recent,
              )
              .toList(growable: false),
    other: showPeopleOnly || showPreferencesOnly
        ? const []
        : memories
              .where(
                (memory) => memory.memoryType.memoryGroup == MemoryGroup.other,
              )
              .toList(growable: false),
  );
}

List<PendingMemoryCandidateItem> filterPendingCandidates({
  required MemoryState state,
  required String query,
  required MemoryQuickFilter quickFilter,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return state.pendingCandidates
      .where((candidate) {
        if (quickFilter == MemoryQuickFilter.corrections &&
            !candidate.isCorrection) {
          return false;
        }
        return _matchesQuery(normalizedQuery, [
          candidate.previewLabel,
          candidate.reasonLabel,
          candidate.candidateTypeLabel,
          candidate.riskLabel,
          candidate.statusLabel,
          candidate.expectedActionLabel,
          candidate.correctionOldValue,
          candidate.correctionNewValue,
          candidate.correctionTargetHint,
        ]);
      })
      .toList(growable: false);
}

bool _matchesQuery(String query, Iterable<String?> fields) {
  if (query.isEmpty) {
    return true;
  }
  return fields.any((field) => field?.toLowerCase().contains(query) == true);
}
