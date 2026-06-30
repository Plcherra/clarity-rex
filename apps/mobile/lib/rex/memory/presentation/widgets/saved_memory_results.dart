import 'package:clarity/rex/memory/data/memory_models.dart';

class SavedMemoryResults {
  const SavedMemoryResults({
    required this.facts,
    required this.preferences,
    required this.peopleMemories,
    required this.people,
    required this.places,
    required this.placeEntities,
    required this.goalMemories,
    required this.rules,
    required this.plans,
    required this.commitments,
    required this.events,
    required this.otherMemories,
    required this.otherEntities,
  });

  final List<MemoryItem> facts;
  final List<MemoryItem> preferences;
  final List<MemoryItem> peopleMemories;
  final List<PersonMemoryItem> people;
  final List<MemoryItem> places;
  final List<EntityMemoryItem> placeEntities;
  final List<MemoryItem> goalMemories;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final List<CommitmentMemoryItem> commitments;
  final List<MemoryItem> events;
  final List<MemoryItem> otherMemories;
  final List<EntityMemoryItem> otherEntities;

  bool get isEmpty {
    return facts.isEmpty &&
        preferences.isEmpty &&
        peopleMemories.isEmpty &&
        people.isEmpty &&
        places.isEmpty &&
        placeEntities.isEmpty &&
        goalMemories.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty &&
        commitments.isEmpty &&
        events.isEmpty &&
        otherMemories.isEmpty &&
        otherEntities.isEmpty;
  }
}
