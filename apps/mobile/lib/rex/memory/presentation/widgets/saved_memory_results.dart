import 'package:clarity/rex/memory/data/memory_models.dart';

class SavedMemoryResults {
  const SavedMemoryResults({
    required this.identity,
    required this.preferences,
    required this.people,
    required this.rules,
    required this.plans,
    required this.commitments,
    required this.recent,
    required this.other,
  });

  final List<MemoryItem> identity;
  final List<MemoryItem> preferences;
  final List<PersonMemoryItem> people;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final List<CommitmentMemoryItem> commitments;
  final List<MemoryItem> recent;
  final List<MemoryItem> other;

  bool get isEmpty {
    return identity.isEmpty &&
        preferences.isEmpty &&
        people.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty &&
        commitments.isEmpty &&
        recent.isEmpty &&
        other.isEmpty;
  }
}
