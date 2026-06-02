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
          final results = await Future.wait<Object>([
            api.getMemories(
              memoryType: memoryType,
              active: nextActiveOnly ? true : null,
            ),
            api.getMemoryCandidates(),
          ]);
          state = state.copyWith(
            memories: results[0] as List<MemoryItem>,
            pendingCandidates: results[1] as List<PendingMemoryCandidateItem>,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.people:
          final results = await Future.wait<Object>([
            api.getPeople(active: nextActiveOnly ? true : null),
            api.getMemoryCandidates(),
          ]);
          state = state.copyWith(
            people: results[0] as List<PersonMemoryItem>,
            pendingCandidates: results[1] as List<PendingMemoryCandidateItem>,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.rules:
          final results = await Future.wait<Object>([
            api.getRules(active: nextActiveOnly ? true : null),
            api.getMemoryCandidates(),
          ]);
          state = state.copyWith(
            rules: results[0] as List<RuleMemoryItem>,
            pendingCandidates: results[1] as List<PendingMemoryCandidateItem>,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.plans:
          final results = await Future.wait<Object>([
            api.getPlans(active: nextActiveOnly ? true : null),
            api.getMemoryCandidates(),
          ]);
          state = state.copyWith(
            plans: results[0] as List<PlanMemoryItem>,
            pendingCandidates: results[1] as List<PendingMemoryCandidateItem>,
            isLoading: false,
            clearError: true,
          );
        case MemoryLayer.commitments:
          final results = await Future.wait<Object>([
            api.getCommitments(active: nextActiveOnly ? true : null),
            api.getMemoryCandidates(),
          ]);
          state = state.copyWith(
            commitments: results[0] as List<CommitmentMemoryItem>,
            pendingCandidates: results[1] as List<PendingMemoryCandidateItem>,
            isLoading: false,
            clearError: true,
          );
      }
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.load),
      );
    }
  }

  Future<void> loadSavedOverview({
    bool? activeOnly,
    bool preserveSelectedMode = false,
  }) async {
    final nextActiveOnly = activeOnly ?? state.activeOnly;
    state = state.copyWith(
      selectedMode: preserveSelectedMode
          ? state.selectedMode
          : MemoryReviewMode.saved,
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
        api.getMemoryCandidates(),
      ]);

      state = state.copyWith(
        memories: results[0] as List<MemoryItem>,
        people: results[1] as List<PersonMemoryItem>,
        rules: results[2] as List<RuleMemoryItem>,
        plans: results[3] as List<PlanMemoryItem>,
        commitments: results[4] as List<CommitmentMemoryItem>,
        pendingCandidates: results[5] as List<PendingMemoryCandidateItem>,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.load),
      );
    }
  }

  Future<void> setMode(MemoryReviewMode mode) async {
    state = state.copyWith(selectedMode: mode, clearError: true);
    if (mode == MemoryReviewMode.pending) {
      await loadPendingCandidates();
    } else {
      await loadSavedOverview();
    }
  }

  Future<void> loadPendingCandidates() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final pendingCandidates = await ref
          .read(memoryApiProvider)
          .getMemoryCandidates();
      state = state.copyWith(
        pendingCandidates: pendingCandidates,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.load),
      );
    }
  }
}
