import 'package:clarity/rex/memory/data/memory_models.dart';

class SavedMemoryResults {
  const SavedMemoryResults({
    required this.facts,
    required this.preferences,
    required this.peopleMemories,
    required this.people,
    required this.places,
    required this.goalMemories,
    required this.rules,
    required this.plans,
    required this.commitments,
    required this.events,
    required this.other,
  });

  final List<MemoryItem> facts;
  final List<MemoryItem> preferences;
  final List<MemoryItem> peopleMemories;
  final List<PersonMemoryItem> people;
  final List<MemoryItem> places;
  final List<MemoryItem> goalMemories;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final List<CommitmentMemoryItem> commitments;
  final List<MemoryItem> events;
  final List<MemoryItem> other;

  bool get isEmpty {
    return facts.isEmpty &&
        preferences.isEmpty &&
        peopleMemories.isEmpty &&
        people.isEmpty &&
        places.isEmpty &&
        goalMemories.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty &&
        commitments.isEmpty &&
        events.isEmpty &&
        other.isEmpty;
  }
}
