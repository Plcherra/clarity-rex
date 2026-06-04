import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/assistant/memory/data/memory_api.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';

part 'memory_action_controller.dart';
part 'memory_controller_errors.dart';
part 'memory_read_controller.dart';

final memoryProvider = NotifierProvider<MemoryController, MemoryState>(
  MemoryController.new,
);

class MemoryState {
  const MemoryState({
    this.memories = const [],
    this.people = const [],
    this.rules = const [],
    this.plans = const [],
    this.commitments = const [],
    this.selectedLayer = MemoryLayer.longTerm,
    this.selectedType,
    this.activeOnly = true,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<MemoryItem> memories;
  final List<PersonMemoryItem> people;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final List<CommitmentMemoryItem> commitments;
  final MemoryLayer selectedLayer;
  final MemoryType? selectedType;
  final bool activeOnly;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  MemoryState copyWith({
    List<MemoryItem>? memories,
    List<PersonMemoryItem>? people,
    List<RuleMemoryItem>? rules,
    List<PlanMemoryItem>? plans,
    List<CommitmentMemoryItem>? commitments,
    MemoryLayer? selectedLayer,
    MemoryType? selectedType,
    bool clearSelectedType = false,
    bool? activeOnly,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MemoryState(
      memories: memories ?? this.memories,
      people: people ?? this.people,
      rules: rules ?? this.rules,
      plans: plans ?? this.plans,
      commitments: commitments ?? this.commitments,
      selectedLayer: selectedLayer ?? this.selectedLayer,
      selectedType: clearSelectedType
          ? null
          : selectedType ?? this.selectedType,
      activeOnly: activeOnly ?? this.activeOnly,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isSelectedLayerEmpty {
    switch (selectedLayer) {
      case MemoryLayer.longTerm:
        return memories.isEmpty;
      case MemoryLayer.people:
        return people.isEmpty;
      case MemoryLayer.rules:
        return rules.isEmpty;
      case MemoryLayer.plans:
        return plans.isEmpty;
      case MemoryLayer.commitments:
        return commitments.isEmpty;
    }
  }

  bool get isSavedOverviewEmpty {
    return memories.isEmpty &&
        people.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty &&
        commitments.isEmpty;
  }
}

class MemoryController extends Notifier<MemoryState>
    with MemoryReadController, MemoryActionController {
  @override
  MemoryState build() => const MemoryState();
}
