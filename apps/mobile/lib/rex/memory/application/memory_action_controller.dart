part of 'memory_controller.dart';

mixin MemoryActionController on Notifier<MemoryState>, MemoryReadController {
  Future<bool> updateMemory(
    String memoryId, {
    MemoryType? memoryType,
    String? content,
    int? importance,
    bool? active,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final memory = await ref
          .read(memoryApiProvider)
          .updateMemory(
            memoryId,
            memoryType: memoryType,
            content: content,
            importance: importance,
            active: active,
          );
      final updatedMemories = state.memories
          .map((item) => item.id == memoryId ? memory : item)
          .where(_matchesCurrentFilters)
          .toList(growable: false);
      state = state.copyWith(
        memories: updatedMemories,
        isSaving: false,
        clearError: true,
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.edit),
      );
      return false;
    }
  }

  Future<bool> deactivateMemory(String memoryId) async {
    return archiveMemory(memoryId);
  }

  Future<bool> archiveMemory(String memoryId) async {
    final previousMemories = state.memories;
    state = state.copyWith(
      memories: state.activeOnly
          ? previousMemories
                .where((memory) => memory.id != memoryId)
                .toList(growable: false)
          : previousMemories
                .map(
                  (memory) => memory.id == memoryId
                      ? memory.copyWith(active: false)
                      : memory,
                )
                .toList(growable: false),
      isSaving: true,
      clearError: true,
    );

    try {
      await ref.read(memoryApiProvider).archiveMemory(memoryId);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        memories: previousMemories,
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.archive),
      );
      return false;
    }
  }

  Future<bool> updatePerson(
    String personId, {
    String? displayName,
    String? relationship,
    String? summary,
    List<String>? aliases,
    int? importance,
    String? status,
    bool? active,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref
          .read(memoryApiProvider)
          .updatePerson(
            personId,
            displayName: displayName,
            relationship: relationship,
            summary: summary,
            aliases: aliases,
            importance: importance,
            status: status,
            active: active,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.edit),
      );
      return false;
    }
  }

  Future<bool> updateRule(
    String ruleId, {
    String? title,
    String? ruleText,
    List<String>? triggerKeywords,
    int? priority,
    String? status,
    bool? active,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref
          .read(memoryApiProvider)
          .updateRule(
            ruleId,
            title: title,
            ruleText: ruleText,
            triggerKeywords: triggerKeywords,
            priority: priority,
            status: status,
            active: active,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.edit),
      );
      return false;
    }
  }

  Future<bool> updatePlan(
    String planId, {
    String? title,
    String? description,
    String? desiredOutcome,
    int? priority,
    String? status,
    bool? active,
    DateTime? targetDate,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref
          .read(memoryApiProvider)
          .updatePlan(
            planId,
            title: title,
            description: description,
            desiredOutcome: desiredOutcome,
            priority: priority,
            status: status,
            active: active,
            targetDate: targetDate,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.edit),
      );
      return false;
    }
  }

  Future<bool> updateCommitment(
    String commitmentId, {
    String? title,
    String? commitmentText,
    int? priority,
    String? status,
    bool? active,
    DateTime? dueAt,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref
          .read(memoryApiProvider)
          .updateCommitment(
            commitmentId,
            title: title,
            commitmentText: commitmentText,
            priority: priority,
            status: status,
            active: active,
            dueAt: dueAt,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.edit),
      );
      return false;
    }
  }

  Future<bool> deactivateStructuredMemory(MemoryLayer layer, String id) async {
    return archiveStructuredMemory(layer, id);
  }

  Future<bool> archiveStructuredMemory(MemoryLayer layer, String id) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final api = ref.read(memoryApiProvider);
      switch (layer) {
        case MemoryLayer.people:
          await api.archivePerson(id);
        case MemoryLayer.rules:
          await api.archiveRule(id);
        case MemoryLayer.plans:
          await api.archivePlan(id);
        case MemoryLayer.commitments:
          await api.archiveCommitment(id);
        case MemoryLayer.longTerm:
          await api.archiveMemory(id);
      }
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.archive),
      );
      return false;
    }
  }

  bool _matchesCurrentFilters(MemoryItem memory) {
    if (state.activeOnly && !memory.active) {
      return false;
    }
    if (state.selectedType != null && memory.memoryType != state.selectedType) {
      return false;
    }

    return true;
  }
}
