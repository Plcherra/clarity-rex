part of 'memory_controller.dart';

mixin MemoryReadController on Notifier<MemoryState> {
  Future<void> loadSavedOverview({bool? activeOnly}) async {
    // Knows always lists active items; archive/delete is the only off-ramp.
    const nextActiveOnly = true;
    state = state.copyWith(
      activeOnly: nextActiveOnly,
      isLoading: true,
      clearError: true,
    );

    try {
      final overview = await _fetchSavedOverview(
        activeOnly: nextActiveOnly,
        pages: const MemoryOverviewPages(),
        append: false,
      );
      state = state.copyWith(
        memories: overview.memories,
        people: overview.people,
        placeEntities: overview.placeEntities,
        otherEntities: overview.otherEntities,
        rules: overview.rules,
        plans: overview.plans,
        entityEventPreviews: overview.entityEventPreviews,
        planMilestonePreviews: overview.planMilestonePreviews,
        overviewPages: overview.pages,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.load),
      );
    }
  }

  Future<void> loadMoreSavedOverview() async {
    if (!state.overviewCanLoadMore || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final overview = await _fetchSavedOverview(
        activeOnly: state.activeOnly,
        pages: state.overviewPages,
        append: true,
      );
      state = state.copyWith(
        memories: overview.memories,
        people: overview.people,
        placeEntities: overview.placeEntities,
        otherEntities: overview.otherEntities,
        rules: overview.rules,
        plans: overview.plans,
        entityEventPreviews: {
          ...state.entityEventPreviews,
          ...overview.entityEventPreviews,
        },
        planMilestonePreviews: {
          ...state.planMilestonePreviews,
          ...overview.planMilestonePreviews,
        },
        overviewPages: overview.pages,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.load),
      );
    }
  }

  Future<_SavedOverviewSnapshot> _fetchSavedOverview({
    required bool activeOnly,
    required MemoryOverviewPages pages,
    required bool append,
  }) async {
    final api = ref.read(memoryApiProvider);
    final active = activeOnly ? true : null;

    if (!append) {
      return _fetchSavedOverviewFromBackend(
        api: api,
        activeOnly: activeOnly,
      );
    }

    final results = await Future.wait<Object>([
      _fetchMemoriesPage(api, active: active, pages: pages, append: append),
      _fetchEntitiesPage(api, active: active, pages: pages, append: append),
      _fetchRulesPage(api, active: active, pages: pages, append: append),
      _fetchPlansPage(api, active: active, pages: pages, append: append),
    ]);

    final memoriesPage = results[0] as MemoryPagedResult<MemoryItem>;
    final entitiesPage = results[1] as MemoryPagedResult<EntityMemoryItem>;
    final rulesPage = results[2] as MemoryPagedResult<RuleMemoryItem>;
    final plansPage = results[3] as MemoryPagedResult<PlanMemoryItem>;

    final memories = append
        ? appendUniqueById(
            existing: state.memories,
            incoming: memoriesPage.items,
            idFor: (item) => item.id,
          )
        : memoriesPage.items;

    final incomingPeople = <PersonMemoryItem>[];
    final incomingPlaces = <EntityMemoryItem>[];
    final incomingOther = <EntityMemoryItem>[];
    for (final entity in entitiesPage.items) {
      switch (entity.entityType) {
        case 'person':
          incomingPeople.add(PersonMemoryItem.fromEntity(entity));
        case 'place':
          incomingPlaces.add(entity);
        default:
          incomingOther.add(entity);
      }
    }

    final people = append
        ? appendUniqueById(
            existing: state.people,
            incoming: incomingPeople,
            idFor: (item) => item.id,
          )
        : incomingPeople;
    final placeEntities = append
        ? appendUniqueById(
            existing: state.placeEntities,
            incoming: incomingPlaces,
            idFor: (item) => item.id,
          )
        : incomingPlaces;
    final otherEntities = append
        ? appendUniqueById(
            existing: state.otherEntities,
            incoming: incomingOther,
            idFor: (item) => item.id,
          )
        : incomingOther;
    final rules = append
        ? appendUniqueById(
            existing: state.rules,
            incoming: rulesPage.items,
            idFor: (item) => item.id,
          )
        : rulesPage.items;
    final plans = append
        ? appendUniqueById(
            existing: state.plans,
            incoming: plansPage.items,
            idFor: (item) => item.id,
          )
        : plansPage.items;

    final entityEventPreviews = await _loadEntityEventPreviews(
      api: api,
      targets: [
        for (final person in people)
          _PreviewTarget(id: person.id, importance: person.importance),
        for (final entity in placeEntities)
          _PreviewTarget(id: entity.id, importance: entity.importance),
        for (final entity in otherEntities)
          _PreviewTarget(id: entity.id, importance: entity.importance),
      ],
      active: active,
    );
    final planMilestonePreviews = await _loadPlanMilestonePreviews(
      api: api,
      targets: [
        for (final plan in plans)
          _PreviewTarget(id: plan.id, importance: plan.priority),
      ],
      active: active,
    );

    final nextPages = MemoryOverviewPages(
      memoriesCursor: memoriesPage.nextCursor ?? pages.memoriesCursor,
      memoriesHasMore: append
          ? (pages.memoriesHasMore ? memoriesPage.hasMore : false)
          : memoriesPage.hasMore,
      entitiesCursor: entitiesPage.nextCursor ?? pages.entitiesCursor,
      entitiesHasMore: append
          ? (pages.entitiesHasMore ? entitiesPage.hasMore : false)
          : entitiesPage.hasMore,
      rulesCursor: rulesPage.nextCursor ?? pages.rulesCursor,
      rulesHasMore: append
          ? (pages.rulesHasMore ? rulesPage.hasMore : false)
          : rulesPage.hasMore,
      plansCursor: plansPage.nextCursor ?? pages.plansCursor,
      plansHasMore: append
          ? (pages.plansHasMore ? plansPage.hasMore : false)
          : plansPage.hasMore,
    );

    return _SavedOverviewSnapshot(
      memories: memories,
      people: people,
      placeEntities: placeEntities,
      otherEntities: otherEntities,
      rules: rules,
      plans: plans,
      entityEventPreviews: entityEventPreviews,
      planMilestonePreviews: planMilestonePreviews,
      pages: nextPages,
    );
  }

  Future<_SavedOverviewSnapshot> _fetchSavedOverviewFromBackend({
    required MemoryApi api,
    required bool activeOnly,
  }) async {
    final active = activeOnly ? true : null;
    final overview = await api.getSavedKnowledgeOverview(
      activeOnly: activeOnly,
      limit: kMemoryListLimit,
    );
    final people = _parseJsonList(overview['people'])
        .map(
          (json) => PersonMemoryItem.fromEntity(EntityMemoryItem.fromJson(json)),
        )
        .toList(growable: false);
    final placeEntities = _parseJsonList(overview['places'])
        .map(EntityMemoryItem.fromJson)
        .toList(growable: false);
    final otherEntities = _parseJsonList(overview['other_entities'])
        .map(EntityMemoryItem.fromJson)
        .toList(growable: false);
    final memories = _parseJsonList(overview['facts'])
        .map(MemoryItem.fromJson)
        .toList(growable: false);
    final rules = _parseJsonList(overview['rules'])
        .map(RuleMemoryItem.fromJson)
        .toList(growable: false);
    final plans = _parseJsonList(overview['plans'])
        .map(PlanMemoryItem.fromJson)
        .toList(growable: false);

    final entityEventPreviews = await _loadEntityEventPreviews(
      api: api,
      targets: [
        for (final person in people)
          _PreviewTarget(id: person.id, importance: person.importance),
        for (final entity in placeEntities)
          _PreviewTarget(id: entity.id, importance: entity.importance),
        for (final entity in otherEntities)
          _PreviewTarget(id: entity.id, importance: entity.importance),
      ],
      active: active,
    );
    final planMilestonePreviews = await _loadPlanMilestonePreviews(
      api: api,
      targets: [
        for (final plan in plans)
          _PreviewTarget(id: plan.id, importance: plan.priority),
      ],
      active: active,
    );

    final entityCount =
        people.length + placeEntities.length + otherEntities.length;
    final memoriesHasMore = memories.length >= kMemoryListLimit;
    final entitiesHasMore = entityCount >= kMemoryListLimit;
    final rulesHasMore = rules.length >= kMemoryListLimit;
    final plansHasMore = plans.length >= kMemoryListLimit;

    return _SavedOverviewSnapshot(
      memories: memories,
      people: people,
      placeEntities: placeEntities,
      otherEntities: otherEntities,
      rules: rules,
      plans: plans,
      entityEventPreviews: entityEventPreviews,
      planMilestonePreviews: planMilestonePreviews,
      pages: MemoryOverviewPages(
        memoriesCursor: memoriesHasMore
            ? encodeMemoryListOffsetCursor(kMemoryListLimit)
            : null,
        memoriesHasMore: memoriesHasMore,
        entitiesCursor: entitiesHasMore
            ? encodeMemoryListOffsetCursor(kMemoryListLimit)
            : null,
        entitiesHasMore: entitiesHasMore,
        rulesCursor: rulesHasMore
            ? encodeMemoryListOffsetCursor(kMemoryListLimit)
            : null,
        rulesHasMore: rulesHasMore,
        plansCursor: plansHasMore
            ? encodeMemoryListOffsetCursor(kMemoryListLimit)
            : null,
        plansHasMore: plansHasMore,
      ),
    );
  }

  List<Map<String, dynamic>> _parseJsonList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, List<EntityEventItem>>> _loadEntityEventPreviews({
    required MemoryApi api,
    required List<_PreviewTarget> targets,
    required bool? active,
  }) async {
    if (targets.isEmpty) {
      return const {};
    }

    final sorted = [...targets]
      ..sort((a, b) => b.importance.compareTo(a.importance));
    final capped = sorted.take(kEntityEventFetchCap).toList(growable: false);
    final previews = <String, List<EntityEventItem>>{};

    await Future.wait<void>(
      capped.map((target) async {
        try {
          final events = await api.getEntityEvents(
            target.id,
            active: active,
            limit: kEntityEventPreviewLimit,
          );
          if (events.isNotEmpty) {
            previews[target.id] = events;
          }
        } on Object {
          // Event previews are optional context; a failed fetch should not block Knows.
        }
      }),
    );

    return previews;
  }

  Future<Map<String, List<PlanMilestoneMemoryItem>>> _loadPlanMilestonePreviews({
    required MemoryApi api,
    required List<_PreviewTarget> targets,
    required bool? active,
  }) async {
    if (targets.isEmpty) {
      return const {};
    }

    final sorted = [...targets]
      ..sort((a, b) => b.importance.compareTo(a.importance));
    final capped = sorted.take(kPlanMilestoneFetchCap).toList(growable: false);
    final previews = <String, List<PlanMilestoneMemoryItem>>{};

    await Future.wait<void>(
      capped.map((target) async {
        try {
          final milestones = await api.getPlanMilestones(
            target.id,
            active: active,
            limit: kPlanMilestonePreviewLimit,
          );
          if (milestones.isNotEmpty) {
            previews[target.id] = milestones;
          }
        } on Object {
          // Milestone previews are optional context; a failed fetch should not block Knows.
        }
      }),
    );

    return previews;
  }

  Future<MemoryPagedResult<MemoryItem>> _fetchMemoriesPage(
    MemoryApi api, {
    required bool? active,
    required MemoryOverviewPages pages,
    required bool append,
  }) async {
    if (append && !pages.memoriesHasMore) {
      return const MemoryPagedResult(items: []);
    }
    return api.getMemoriesPaged(
      active: active,
      limit: kMemoryListLimit,
      cursor: append ? pages.memoriesCursor : null,
    );
  }

  Future<MemoryPagedResult<EntityMemoryItem>> _fetchEntitiesPage(
    MemoryApi api, {
    required bool? active,
    required MemoryOverviewPages pages,
    required bool append,
  }) async {
    if (append && !pages.entitiesHasMore) {
      return const MemoryPagedResult(items: []);
    }
    return api.getEntitiesPaged(
      active: active,
      limit: kMemoryListLimit,
      cursor: append ? pages.entitiesCursor : null,
    );
  }

  Future<MemoryPagedResult<RuleMemoryItem>> _fetchRulesPage(
    MemoryApi api, {
    required bool? active,
    required MemoryOverviewPages pages,
    required bool append,
  }) async {
    if (append && !pages.rulesHasMore) {
      return const MemoryPagedResult(items: []);
    }
    return api.getRulesPaged(
      active: active,
      limit: kMemoryListLimit,
      cursor: append ? pages.rulesCursor : null,
    );
  }

  Future<MemoryPagedResult<PlanMemoryItem>> _fetchPlansPage(
    MemoryApi api, {
    required bool? active,
    required MemoryOverviewPages pages,
    required bool append,
  }) async {
    if (append && !pages.plansHasMore) {
      return const MemoryPagedResult(items: []);
    }
    return api.getPlansPaged(
      active: active,
      limit: kMemoryListLimit,
      cursor: append ? pages.plansCursor : null,
    );
  }
}

class _PreviewTarget {
  const _PreviewTarget({
    required this.id,
    required this.importance,
  });

  final String id;
  final int importance;
}

class _SavedOverviewSnapshot {
  const _SavedOverviewSnapshot({
    required this.memories,
    required this.people,
    required this.placeEntities,
    required this.otherEntities,
    required this.rules,
    required this.plans,
    required this.entityEventPreviews,
    required this.planMilestonePreviews,
    required this.pages,
  });

  final List<MemoryItem> memories;
  final List<PersonMemoryItem> people;
  final List<EntityMemoryItem> placeEntities;
  final List<EntityMemoryItem> otherEntities;
  final List<RuleMemoryItem> rules;
  final List<PlanMemoryItem> plans;
  final Map<String, List<EntityEventItem>> entityEventPreviews;
  final Map<String, List<PlanMilestoneMemoryItem>> planMilestonePreviews;
  final MemoryOverviewPages pages;
}
