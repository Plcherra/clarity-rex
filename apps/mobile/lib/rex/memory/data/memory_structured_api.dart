part of 'memory_api.dart';

mixin _StructuredMemoryApi on _MemoryApiTransport {
  Future<List<EntityMemoryItem>> getEntities({
    String? entityType,
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    final page = await getEntitiesPaged(
      entityType: entityType,
      active: active,
      limit: limit,
    );
    return page.items;
  }

  Future<MemoryPagedResult<EntityMemoryItem>> getEntitiesPaged({
    String? entityType,
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final data = await _getPagedMap('/entities', {
      'limit': limit.toString(),
      if (entityType != null) 'entity_type': entityType,
      if (active != null) 'active': active.toString(),
      if (cursor != null) 'cursor': cursor,
    });
    return MemoryPagedResult.fromJson(data, EntityMemoryItem.fromJson);
  }

  Future<List<PersonMemoryItem>> getPeople({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    final entities = await getEntities(
      entityType: 'person',
      active: active,
      limit: limit,
    );
    return entities.map(PersonMemoryItem.fromEntity).toList(growable: false);
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
    Map<String, dynamic>? metadata,
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
        'metadata': metadata,
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

  Future<EntityMemoryItem> updateEntity(
    String entityId, {
    String? displayName,
    String? relationship,
    String? summary,
    List<String>? aliases,
    int? importance,
    String? status,
    bool? active,
  }) async {
    final data = await _patchJson(
      '/entities/$entityId',
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
    return EntityMemoryItem.fromJson(data);
  }

  Future<void> archiveEntity(String entityId) async {
    await _delete('/entities/$entityId');
  }

  Future<List<EntityEventItem>> getEntityEvents(
    String entityId, {
    bool? active,
    int limit = kEntityEventPreviewLimit,
  }) async {
    final data = await _getList('/entities/$entityId/events', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
    });
    return data.map(EntityEventItem.fromJson).toList(growable: false);
  }

  Future<List<RuleMemoryItem>> getRules({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    final page = await getRulesPaged(active: active, limit: limit);
    return page.items;
  }

  Future<MemoryPagedResult<RuleMemoryItem>> getRulesPaged({
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final data = await _getPagedMap('/rules', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
      if (cursor != null) 'cursor': cursor,
    });
    return MemoryPagedResult.fromJson(data, RuleMemoryItem.fromJson);
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

  Future<List<PlanMemoryItem>> getPlans({
    bool? active,
    int limit = kMemoryListLimit,
  }) async {
    final page = await getPlansPaged(active: active, limit: limit);
    return page.items;
  }

  Future<MemoryPagedResult<PlanMemoryItem>> getPlansPaged({
    bool? active,
    int limit = kMemoryListLimit,
    String? cursor,
  }) async {
    final data = await _getPagedMap('/plans', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
      if (cursor != null) 'cursor': cursor,
    });
    return MemoryPagedResult.fromJson(data, PlanMemoryItem.fromJson);
  }

  Future<List<PlanMilestoneMemoryItem>> getPlanMilestones(
    String planId, {
    bool? active,
    int limit = kPlanMilestonePreviewLimit,
  }) async {
    final data = await _getList('/plans/$planId/milestones', {
      'limit': limit.toString(),
      if (active != null) 'active': active.toString(),
    });
    return data.map(PlanMilestoneMemoryItem.fromJson).toList(growable: false);
  }

  Future<PlanMilestoneMemoryItem> createPlanMilestone(
    String planId, {
    required String title,
    String? description,
    String milestoneType = 'checkpoint',
    int priority = 3,
  }) async {
    final data = await _postJson('/plans/$planId/milestones', _withoutNulls({
      'plan_id': planId,
      'title': title.trim(),
      'description': description?.trim(),
      'milestone_type': milestoneType,
      'priority': priority,
    }));
    return PlanMilestoneMemoryItem.fromJson(data);
  }

  Future<PlanMilestoneMemoryItem> updatePlanMilestone(
    String milestoneId, {
    String? title,
    String? description,
    int? priority,
    String? status,
    bool? active,
  }) async {
    final data = await _patchJson(
      '/plans/milestones/$milestoneId',
      _withoutNulls({
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'active': active,
      }),
    );
    return PlanMilestoneMemoryItem.fromJson(data);
  }

  Future<void> archivePlanMilestone(String milestoneId) async {
    await _delete('/plans/milestones/$milestoneId');
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
}
