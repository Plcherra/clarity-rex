part of 'memory_api.dart';

mixin _StructuredMemoryApi on _MemoryApiTransport {
  Future<List<PersonMemoryItem>> getPeople({
    bool? active,
    int limit = 50,
  }) async {
    final data = await _getList('/entities', {
      'entity_type': 'person',
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
    });
    return data.map(PersonMemoryItem.fromJson).toList(growable: false);
  }

  Future<PersonMemoryItem> createPerson({
    required String displayName,
    String? relationship,
    String? summary,
    int importance = 3,
  }) async {
    final normalizedName = displayName.trim().toLowerCase();
    final data = await _postJson('/entities', {
      'entity_type': 'person',
      'display_name': displayName.trim(),
      'normalized_name': normalizedName,
      if (relationship != null && relationship.trim().isNotEmpty)
        'relationship': relationship.trim(),
      if (summary != null && summary.trim().isNotEmpty) 'summary': summary.trim(),
      'importance': importance,
    });
    return PersonMemoryItem.fromJson(data);
  }

  Future<PersonMemoryItem> updatePerson(
    String personId, {
    String? displayName,
    String? relationship,
    String? summary,
    List<String>? aliases,
    int? importance,
    String? status,
    bool? active,
  }) async {
    final data = await _patchJson(
      '/entities/$personId',
      _withoutNulls({
        'display_name': displayName,
        'normalized_name': displayName?.toLowerCase(),
        'relationship': relationship,
        'summary': summary,
        'aliases': aliases,
        'importance': importance,
        'status': status,
        'active': active,
      }),
    );
    return PersonMemoryItem.fromJson(data);
  }

  Future<void> deactivatePerson(String personId) async {
    await _delete('/entities/$personId');
  }

  Future<void> archivePerson(String personId) async {
    await deactivatePerson(personId);
  }

  Future<List<RuleMemoryItem>> getRules({bool? active, int limit = 50}) async {
    final data = await _getList('/rules', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
    });
    return data.map(RuleMemoryItem.fromJson).toList(growable: false);
  }

  Future<RuleMemoryItem> createRule({
    required String title,
    required String ruleText,
    String ruleType = 'personal',
    int priority = 3,
  }) async {
    final data = await _postJson('/rules', {
      'rule_type': ruleType,
      'title': title.trim(),
      'rule_text': ruleText.trim(),
      'priority': priority,
    });
    return RuleMemoryItem.fromJson(data);
  }

  Future<RuleMemoryItem> updateRule(
    String ruleId, {
    String? title,
    String? ruleText,
    List<String>? triggerKeywords,
    int? priority,
    String? status,
    bool? active,
  }) async {
    final data = await _patchJson(
      '/rules/$ruleId',
      _withoutNulls({
        'title': title,
        'rule_text': ruleText,
        'trigger_keywords': triggerKeywords,
        'priority': priority,
        'status': status,
        'active': active,
      }),
    );
    return RuleMemoryItem.fromJson(data);
  }

  Future<void> deactivateRule(String ruleId) async {
    await _delete('/rules/$ruleId');
  }

  Future<void> archiveRule(String ruleId) async {
    await deactivateRule(ruleId);
  }

  Future<List<PlanMemoryItem>> getPlans({bool? active, int limit = 50}) async {
    final data = await _getList('/plans', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
    });
    return data.map(PlanMemoryItem.fromJson).toList(growable: false);
  }

  Future<PlanMemoryItem> createPlan({
    required String title,
    String? description,
    String? desiredOutcome,
    String planType = 'personal',
    int priority = 3,
  }) async {
    final data = await _postJson('/plans', _withoutNulls({
      'plan_type': planType,
      'title': title.trim(),
      'description': description?.trim(),
      'desired_outcome': desiredOutcome?.trim(),
      'priority': priority,
    }));
    return PlanMemoryItem.fromJson(data);
  }

  Future<PlanMemoryItem> updatePlan(
    String planId, {
    String? title,
    String? description,
    String? desiredOutcome,
    int? priority,
    String? status,
    bool? active,
    DateTime? targetDate,
  }) async {
    final data = await _patchJson(
      '/plans/$planId',
      _withoutNulls({
        'title': title,
        'description': description,
        'desired_outcome': desiredOutcome,
        'priority': priority,
        'status': status,
        'active': active,
        'target_date': targetDate == null ? null : _dateOnly(targetDate),
      }),
    );
    return PlanMemoryItem.fromJson(data);
  }

  Future<void> deactivatePlan(String planId) async {
    await _delete('/plans/$planId');
  }

  Future<void> archivePlan(String planId) async {
    await deactivatePlan(planId);
  }

  Future<List<CommitmentMemoryItem>> getCommitments({
    bool? active,
    int limit = 50,
  }) async {
    final data = await _getList('/commitments', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
    });
    return data.map(CommitmentMemoryItem.fromJson).toList(growable: false);
  }

  Future<CommitmentMemoryItem> createCommitment({
    required String title,
    required String commitmentText,
    String commitmentType = 'task',
    int priority = 3,
  }) async {
    final data = await _postJson('/commitments', {
      'commitment_type': commitmentType,
      'title': title.trim(),
      'commitment_text': commitmentText.trim(),
      'priority': priority,
    });
    return CommitmentMemoryItem.fromJson(data);
  }

  Future<CommitmentMemoryItem> updateCommitment(
    String commitmentId, {
    String? title,
    String? commitmentText,
    int? priority,
    String? status,
    bool? active,
    DateTime? dueAt,
  }) async {
    final data = await _patchJson(
      '/commitments/$commitmentId',
      _withoutNulls({
        'title': title,
        'commitment_text': commitmentText,
        'priority': priority,
        'status': status,
        'active': active,
        'due_at': dueAt?.toIso8601String(),
      }),
    );
    return CommitmentMemoryItem.fromJson(data);
  }

  Future<void> deactivateCommitment(String commitmentId) async {
    await _delete('/commitments/$commitmentId');
  }

  Future<void> archiveCommitment(String commitmentId) async {
    await deactivateCommitment(commitmentId);
  }
}
