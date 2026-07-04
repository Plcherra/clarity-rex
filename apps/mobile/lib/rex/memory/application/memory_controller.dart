import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_locale.dart';
import 'package:clarity/rex/memory/data/memory_api.dart';
import 'package:clarity/rex/memory/data/memory_constants.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/data/memory_paged_result.dart';

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
    this.placeEntities = const [],
    this.otherEntities = const [],
    this.rules = const [],
    this.plans = const [],
    this.entityEventPreviews = const {},
    this.planMilestonePreviews = const {},
    this.overviewPages = const MemoryOverviewPages(),
    this.activeOnly = true,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<MemoryItem> memories;
  final List<PersonMemoryItem> people;
  final List<EntityMemoryItem> placeEntities;
  final List<EntityMemoryItem> otherEntities;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final Map<String, List<EntityEventItem>> entityEventPreviews;
  final Map<String, List<PlanMilestoneMemoryItem>> planMilestonePreviews;
  final MemoryOverviewPages overviewPages;
  final bool activeOnly;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  bool get overviewCanLoadMore => overviewPages.hasMore;

  List<EntityEventItem> eventPreviewsFor(String entityId) {
    return entityEventPreviews[entityId] ?? const [];
  }

  List<PlanMilestoneMemoryItem> milestonePreviewsFor(String planId) {
    return planMilestonePreviews[planId] ?? const [];
  }

  MemoryState copyWith({
    List<MemoryItem>? memories,
    List<PersonMemoryItem>? people,
    List<EntityMemoryItem>? placeEntities,
    List<EntityMemoryItem>? otherEntities,
    List<RuleMemoryItem>? rules,
    List<PlanMemoryItem>? plans,
    Map<String, List<EntityEventItem>>? entityEventPreviews,
    Map<String, List<PlanMilestoneMemoryItem>>? planMilestonePreviews,
    MemoryOverviewPages? overviewPages,
    bool? activeOnly,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MemoryState(
      memories: memories ?? this.memories,
      people: people ?? this.people,
      placeEntities: placeEntities ?? this.placeEntities,
      otherEntities: otherEntities ?? this.otherEntities,
      rules: rules ?? this.rules,
      plans: plans ?? this.plans,
      entityEventPreviews: entityEventPreviews ?? this.entityEventPreviews,
      planMilestonePreviews:
          planMilestonePreviews ?? this.planMilestonePreviews,
      overviewPages: overviewPages ?? this.overviewPages,
      activeOnly: activeOnly ?? this.activeOnly,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isSavedOverviewEmpty {
    return memories.isEmpty &&
        people.isEmpty &&
        placeEntities.isEmpty &&
        otherEntities.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty;
  }
}

class MemoryController extends Notifier<MemoryState>
    with MemoryReadController, MemoryActionController {
  @override
  MemoryState build() => const MemoryState();
}
