import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/assistant/memory/data/memory_api.dart';
import 'package:clarity/features/assistant/memory/data/memory_models.dart';

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
    this.pendingCandidates = const [],
    this.selectedMode = MemoryReviewMode.saved,
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
  final List<PendingMemoryCandidateItem> pendingCandidates;
  final MemoryReviewMode selectedMode;
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
    List<PendingMemoryCandidateItem>? pendingCandidates,
    MemoryReviewMode? selectedMode,
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
      pendingCandidates: pendingCandidates ?? this.pendingCandidates,
      selectedMode: selectedMode ?? this.selectedMode,
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

  bool get isPendingReviewEmpty => pendingCandidates.isEmpty;

  bool get isSavedOverviewEmpty {
    return memories.isEmpty &&
        people.isEmpty &&
        rules.isEmpty &&
        plans.isEmpty &&
        commitments.isEmpty;
  }
}

class MemoryController extends Notifier<MemoryState> {
  @override
  MemoryState build() => const MemoryState();

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
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.edit),
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
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.archive),
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
      await loadMemories(layer: MemoryLayer.people);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.edit),
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
      await loadMemories(layer: MemoryLayer.rules);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.edit),
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
      await loadMemories(layer: MemoryLayer.plans);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.edit),
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
      await loadMemories(layer: MemoryLayer.commitments);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.edit),
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
      await loadMemories(layer: layer);
      state = state.copyWith(isSaving: false, clearError: true);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.archive),
      );
      return false;
    }
  }

  Future<bool> approvePendingCandidate(String candidateId) async {
    return _decidePendingCandidate(
      candidateId,
      (api) => api.approveMemoryCandidate(candidateId),
      _MemoryOperation.approve,
    );
  }

  Future<bool> rejectPendingCandidate(String candidateId) async {
    return _decidePendingCandidate(
      candidateId,
      (api) => api.rejectMemoryCandidate(candidateId),
      _MemoryOperation.reject,
    );
  }

  Future<bool> updatePendingCandidate(
    PendingMemoryCandidateItem candidate, {
    required String proposal,
    required String? reason,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final updated = await ref
          .read(memoryApiProvider)
          .updateMemoryCandidate(
            candidate.id,
            payload: editedMemoryCandidatePayload(candidate, proposal),
            reason: reason,
          );
      state = state.copyWith(
        pendingCandidates: state.pendingCandidates
            .map((item) => item.id == candidate.id ? updated : item)
            .toList(growable: false),
        isSaving: false,
        clearError: true,
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, _MemoryOperation.edit),
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

  Future<bool> _decidePendingCandidate(
    String candidateId,
    Future<PendingMemoryCandidateItem> Function(MemoryApi api) decide,
    _MemoryOperation operation,
  ) async {
    final previousCandidates = state.pendingCandidates;
    state = state.copyWith(
      pendingCandidates: previousCandidates
          .where((candidate) => candidate.id != candidateId)
          .toList(growable: false),
      isSaving: true,
      clearError: true,
    );

    try {
      final result = await decide(ref.read(memoryApiProvider));
      state = state.copyWith(
        pendingCandidates: result.isPending
            ? [...state.pendingCandidates, result]
            : state.pendingCandidates,
        isSaving: false,
        clearError: true,
      );
      if (result.status == 'applied') {
        await loadSavedOverview(preserveSelectedMode: true);
      }
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        pendingCandidates: previousCandidates,
        isSaving: false,
        errorMessage: _memoryErrorMessage(error, operation),
      );
      return false;
    }
  }
}

enum _MemoryOperation { load, approve, reject, edit, archive }

String _memoryErrorMessage(Object error, _MemoryOperation operation) {
  final statusCode = error is MemoryApiException ? error.statusCode : null;
  if (statusCode == 401 || statusCode == 403) {
    return 'Please sign in again to manage Rex Memory.';
  }
  if (statusCode == 404) {
    return 'That memory is no longer available.';
  }
  if (statusCode != null && statusCode >= 400 && statusCode < 500) {
    switch (operation) {
      case _MemoryOperation.edit:
        return 'That memory change could not be saved. Check the fields and try again.';
      case _MemoryOperation.approve:
        return 'That memory request could not be saved. Refresh Memory and try again.';
      case _MemoryOperation.reject:
        return 'That memory request could not be dismissed. Refresh Memory and try again.';
      case _MemoryOperation.archive:
        return 'That memory could not be archived. Refresh Memory and try again.';
      case _MemoryOperation.load:
        return 'Could not load Rex Memory. Refresh and try again.';
    }
  }

  switch (operation) {
    case _MemoryOperation.load:
      return 'Could not load Rex Memory. Check your connection and try again.';
    case _MemoryOperation.approve:
      return 'Could not save this memory. Please try again.';
    case _MemoryOperation.reject:
      return 'Could not dismiss this memory request. Please try again.';
    case _MemoryOperation.edit:
      return 'Could not update this memory. Please try again.';
    case _MemoryOperation.archive:
      return 'Could not archive this memory. Please try again.';
  }
}
