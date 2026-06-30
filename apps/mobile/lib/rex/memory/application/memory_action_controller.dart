part of 'memory_controller.dart';

mixin MemoryActionController on Notifier<MemoryState>, MemoryReadController {
  Future<bool> createMemory({
    required MemoryType memoryType,
    required String content,
    int importance = 3,
    String? memoryCategory,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(memoryApiProvider).createMemory(
            memoryType: memoryType,
            content: content,
            importance: importance,
            memoryCategory: memoryCategory,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.create),
      );
      return false;
    }
  }

  Future<bool> createPerson({
    required String displayName,
    String? relationship,
    String? summary,
    int importance = 3,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(memoryApiProvider).createPerson(
            displayName: displayName,
            relationship: relationship,
            summary: summary,
            importance: importance,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.create),
      );
      return false;
    }
  }

  Future<bool> createRule({
    required String title,
    required String ruleText,
    int priority = 3,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(memoryApiProvider).createRule(
            title: title,
            ruleText: ruleText,
            priority: priority,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.create),
      );
      return false;
    }
  }

  Future<bool> createPlan({
    required String title,
    String? description,
    String? desiredOutcome,
    int priority = 3,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(memoryApiProvider).createPlan(
            title: title,
            description: description,
            desiredOutcome: desiredOutcome,
            priority: priority,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.create),
      );
      return false;
    }
  }

  Future<bool> createCommitment({
    required String title,
    required String commitmentText,
    int priority = 3,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(memoryApiProvider).createCommitment(
            title: title,
            commitmentText: commitmentText,
            priority: priority,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(ref, error, _MemoryOperation.create),
      );
      return false;
    }
  }

  Future<bool> updateMemory(
    String memoryId, {
    MemoryType? memoryType,
    String? content,
    int? importance,
    bool? active,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await ref
          .read(memoryApiProvider)
          .updateMemory(
            memoryId,
            memoryType: memoryType,
            content: content,
            importance: importance,
            active: active,
          );
      await loadSavedOverview(activeOnly: state.activeOnly);
      state = state.copyWith(
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

  Future<bool> updateEntity(
    String entityId, {
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
      await ref.read(memoryApiProvider).updateEntity(
            entityId,
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

  Future<bool> deactivateStructuredMemory(
    StructuredMemoryKind kind,
    String id,
  ) async {
    return archiveStructuredMemory(kind, id);
  }

  Future<bool> archiveStructuredMemory(
    StructuredMemoryKind kind,
    String id,
  ) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final api = ref.read(memoryApiProvider);
      switch (kind) {
        case StructuredMemoryKind.person:
          await api.archivePerson(id);
        case StructuredMemoryKind.entity:
          await api.archiveEntity(id);
        case StructuredMemoryKind.rule:
          await api.archiveRule(id);
        case StructuredMemoryKind.plan:
          await api.archivePlan(id);
        case StructuredMemoryKind.commitment:
          await api.archiveCommitment(id);
        case StructuredMemoryKind.flatMemory:
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
}
