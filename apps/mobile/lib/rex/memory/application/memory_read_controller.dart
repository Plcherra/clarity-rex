part of 'memory_controller.dart';

mixin MemoryReadController on Notifier<MemoryState> {
  Future<void> loadMemories({
    MemoryLayer? layer,
    MemoryType? memoryType,
    bool? activeOnly,
  }) async {
    final nextLayer = layer ?? state.selectedLayer;
    final nextActiveOnly = activeOnly ?? state.activeOnly;
    state = state.copyWith(
      selectedLayer: nextLayer,
      selectedType: memoryType,
      clearSelectedType:
          nextLayer != MemoryLayer.longTerm || memoryType == null,
      activeOnly: nextActiveOnly,
      isLoading: true,
      clearError: true,
    );

    try {
      final api = ref.read(memoryApiProvider);
      switch (nextLayer) {
        case MemoryLayer.longTerm:
          final memories = await api.getMemories(
            memoryType: memoryType,
            active: nextActiveOnly ? true : null,
          );
          state = state.copyWith(
            memories: memories,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.people:
          final people = await api.getPeople(
            active: nextActiveOnly ? true : null,
          );
          state = state.copyWith(
            people: people,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.rules:
          final rules = await api.getRules(
            active: nextActiveOnly ? true : null,
          );
          state = state.copyWith(
            rules: rules,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.plans:
          final plans = await api.getPlans(
            active: nextActiveOnly ? true : null,
          );
          state = state.copyWith(
            plans: plans,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.commitments:
          final commitments = await api.getCommitments(
            active: nextActiveOnly ? true : null,
          );
          state = state.copyWith(
            commitments: commitments,
            isLoading: false,
            clearError: true,
          );
      }
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.load),
      );
    }
  }

  Future<void> loadSavedOverview({bool? activeOnly}) async {
    final nextActiveOnly = activeOnly ?? state.activeOnly;
    state = state.copyWith(
      selectedLayer: MemoryLayer.longTerm,
      clearSelectedType: true,
      activeOnly: nextActiveOnly,
      isLoading: true,
      clearError: true,
    );

    try {
      final api = ref.read(memoryApiProvider);
      final active = nextActiveOnly ? true : null;
      final results = await Future.wait<Object>([
        api.getMemories(active: active),
        api.getPeople(active: active),
        api.getRules(active: active),
        api.getPlans(active: active),
        api.getCommitments(active: active),
      ]);

      state = state.copyWith(
        memories: results[0] as List<MemoryItem>,
        people: results[1] as List<PersonMemoryItem>,
        rules: results[2] as List<RuleMemoryItem>,
        plans: results[3] as List<PlanMemoryItem>,
        commitments: results[4] as List<CommitmentMemoryItem>,
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
}
