part of 'memory_page.dart';

extension _MemoryPageActions on _MemoryPageState {
  Future<void> _startCreate() async {
    final kind = await showMemoryCreateTypePicker(context);
    if (kind == null || !mounted) {
      return;
    }

    final l10n = context.l10n;
    final notifier = ref.read(memoryProvider.notifier);
    var saved = false;
    String successMessage = l10n.memoryPageMemoryCreated;

    switch (kind) {
      case MemoryCreateKind.fact:
      case MemoryCreateKind.preference:
        final result = await showFlatMemoryCreateSheet(context, kind: kind);
        if (result == null) {
          return;
        }
        saved = await notifier.createMemory(
          memoryType: result.memoryType,
          content: result.content,
          importance: result.importance,
          memoryCategory: result.memoryCategory,
        );
      case MemoryCreateKind.person:
        final result = await showPersonCreateSheet(context);
        if (result == null) {
          return;
        }
        saved = await notifier.createPerson(
          displayName: result.displayName,
          relationship: result.relationship,
          summary: result.summary,
          importance: result.importance,
        );
        successMessage = l10n.memoryPagePersonCreated;
      case MemoryCreateKind.rule:
        final result = await showStructuredCreateSheet(
          context,
          title: l10n.memoryCreateRuleTitle,
          primaryLabel: l10n.commonTitle,
          detailLabel: l10n.memoryEditRuleTextLabel,
        );
        if (result == null) {
          return;
        }
        saved = await notifier.createRule(
          title: result.title,
          ruleText: result.detail,
          priority: result.importance,
        );
        successMessage = l10n.memoryPageRuleCreated;
    }

    if (!mounted) {
      return;
    }
    _showSnackBar(saved ? successMessage : _currentError());
  }

  Future<void> _editMemory(MemoryItem memory) async {
    final result = await showMemoryEditSheet(context, memory: memory);
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updateMemory(
          memory.id,
          memoryType: result.memoryType,
          content: result.content,
          importance: result.importance,
          active: result.active,
        );
    if (!mounted) {
      return;
    }

    _showSnackBar(
      saved ? context.l10n.memoryPageMemoryUpdated : _currentError(),
    );
  }

  Future<void> _archiveMemory(MemoryItem memory) async {
    final confirmed = await confirmArchiveMemory(context);
    if (!confirmed) {
      return;
    }

    final archived = await ref
        .read(memoryProvider.notifier)
        .archiveMemory(memory.id);
    if (!mounted) {
      return;
    }

    _showSnackBar(
      archived ? context.l10n.memoryPageMemoryArchived : _currentError(),
    );
  }

  Future<void> _editPerson(PersonMemoryItem person) async {
    final l10n = context.l10n;
    final result = await showPersonEditSheet(context, person: person);
    if (result == null) {
      return;
    }

    if (result.delete) {
      final archived = await ref
          .read(memoryProvider.notifier)
          .archiveStructuredMemory(StructuredMemoryKind.person, person.id);
      if (mounted) {
        _showSnackBar(
          archived
              ? context.l10n.commonArchivedNamed(person.displayName)
              : _currentError(),
        );
      }
      return;
    }

    final existingAttributes = Map<String, dynamic>.from(person.attributes);
    if (result.birthday == null || result.birthday!.isEmpty) {
      existingAttributes.remove('birthday');
    } else {
      existingAttributes['birthday'] = result.birthday;
    }
    final metadata = Map<String, dynamic>.from(person.metadata);
    metadata['attributes'] = existingAttributes;

    final saved = await ref
        .read(memoryProvider.notifier)
        .updatePerson(
          person.id,
          displayName: result.displayName,
          relationship: result.relationship,
          summary: result.summary,
          importance: person.importance,
          status: person.status,
          active: person.active,
          metadata: metadata,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPagePersonUpdated : _currentError());
    }
  }

  Future<void> _editEntity(EntityMemoryItem entity) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditEntityTitle,
      typeLabel: entityTypeLabel(l10n, entity.entityType),
      primaryLabel: l10n.commonName,
      primaryValue: entity.displayName,
      detailLabel: l10n.commonSummary,
      detailValue: entity.summary,
      importanceLabel: l10n.commonImportance,
      importance: entity.importance,
      status: entity.status,
      active: entity.active,
      updatedAt: entity.updatedAt,
      createdAt: entity.createdAt,
      showImportance: false,
      showActive: false,
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updateEntity(
          entity.id,
          displayName: result.primary,
          summary: result.detail,
          importance: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageEntityUpdated : _currentError());
    }
  }

  Future<void> _editRule(RuleMemoryItem rule) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditRuleTitle,
      typeLabel: localizedMemoryRecordLabel(l10n, rule.ruleType),
      primaryLabel: l10n.commonTitle,
      primaryValue: rule.title,
      detailLabel: l10n.memoryEditRuleTextLabel,
      detailValue: rule.ruleText,
      extraLabel: l10n.memoryEditTriggerKeywordsLabel,
      extraValue: rule.triggerKeywords.join(', '),
      importanceLabel: l10n.commonPriority,
      importance: rule.priority,
      status: rule.status,
      active: rule.active,
      updatedAt: rule.updatedAt,
      createdAt: rule.createdAt,
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updateRule(
          rule.id,
          title: result.primary,
          ruleText: result.detail,
          triggerKeywords: result.extraList,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageRuleUpdated : _currentError());
    }
  }

  Future<void> _editPlan(PlanMemoryItem plan) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditPlanTitle,
      typeLabel: localizedMemoryRecordLabel(l10n, plan.planType),
      primaryLabel: l10n.commonTitle,
      primaryValue: plan.title,
      detailLabel: l10n.commonDescription,
      detailValue: plan.description,
      extraLabel: l10n.memoryEditDesiredOutcomeLabel,
      extraValue: plan.desiredOutcome,
      importanceLabel: l10n.commonPriority,
      importance: plan.priority,
      status: plan.status,
      active: plan.active,
      updatedAt: plan.updatedAt,
      createdAt: plan.createdAt,
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updatePlan(
          plan.id,
          title: result.primary,
          description: result.detail,
          desiredOutcome: result.extra,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPagePlanUpdated : _currentError());
    }
  }

  Future<void> _addPlanMilestone(PlanMemoryItem plan) async {
    final l10n = context.l10n;
    final result = await showStructuredCreateSheet(
      context,
      title: l10n.memoryCreateMilestoneTitle,
      primaryLabel: l10n.commonTitle,
      detailLabel: l10n.commonDescription,
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .createPlanMilestone(
          plan.id,
          title: result.title,
          description: result.detail,
          priority: result.importance,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageMilestoneCreated : _currentError());
    }
  }

  Future<void> _editPlanMilestone(
    PlanMemoryItem plan,
    PlanMilestoneMemoryItem milestone,
  ) async {
    final l10n = context.l10n;
    final result = await showStructuredEditSheet(
      context,
      title: l10n.memoryEditEditMilestoneTitle,
      typeLabel: localizedMemoryRecordLabel(l10n, milestone.milestoneType),
      primaryLabel: l10n.commonTitle,
      primaryValue: milestone.title,
      detailLabel: l10n.commonDescription,
      detailValue: milestone.description,
      importanceLabel: l10n.commonPriority,
      importance: milestone.priority,
      status: milestone.status,
      active: milestone.active,
      updatedAt: milestone.updatedAt,
      createdAt: milestone.createdAt,
    );
    if (result == null) {
      return;
    }

    final saved = await ref
        .read(memoryProvider.notifier)
        .updatePlanMilestone(
          milestone.id,
          title: result.primary,
          description: result.detail,
          priority: result.importance,
          status: result.status,
          active: result.active,
        );
    if (mounted) {
      _showSnackBar(saved ? l10n.memoryPageMilestoneUpdated : _currentError());
    }
  }

  Future<void> _archiveStructuredMemory(
    StructuredMemoryKind kind,
    String id,
    String label,
  ) async {
    final confirmed = await confirmArchiveStructuredMemory(
      context,
      label: label,
    );
    if (!confirmed) {
      return;
    }

    final archived = await ref
        .read(memoryProvider.notifier)
        .archiveStructuredMemory(kind, id);
    if (mounted) {
      _showSnackBar(
        archived ? context.l10n.commonArchivedNamed(label) : _currentError(),
      );
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _currentError() {
    return ref.read(memoryProvider).errorMessage ??
        context.l10n.memoryPageActionFailed;
  }
}
