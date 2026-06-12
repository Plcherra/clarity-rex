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
