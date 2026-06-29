import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/widgets/saved_memory_tile_shell.dart';

class MemoryTile extends StatelessWidget {
  const MemoryTile({
    required this.memory,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final MemoryItem memory;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return SavedMemoryTileShell(
      icon: _iconForGroup(memory.memoryGroup),
      active: memory.active,
      title: memory.content,
      typeLabel: memory.memoryType.label,
      importance: memory.importance,
      updatedAt: memory.updatedAt,
      createdAt: memory.createdAt,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }

  IconData _iconForGroup(MemoryGroup group) {
    switch (group) {
      case MemoryGroup.facts:
        return Icons.badge_outlined;
      case MemoryGroup.preferences:
        return Icons.tune_rounded;
      case MemoryGroup.people:
        return Icons.person_outline_rounded;
      case MemoryGroup.places:
        return Icons.place_outlined;
      case MemoryGroup.goals:
        return Icons.flag_outlined;
      case MemoryGroup.events:
        return Icons.event_note_outlined;
      case MemoryGroup.rules:
        return Icons.rule_rounded;
      case MemoryGroup.other:
        return Icons.note_alt_outlined;
    }
  }
}

class PersonMemoryTile extends StatelessWidget {
  const PersonMemoryTile({
    required this.person,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final PersonMemoryItem person;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StructuredMemoryTile(
      icon: Icons.person_outline_rounded,
      active: person.active,
      title: person.displayName,
      subtitle: personMemorySubtitle(person),
      typeLabel: l10n.commonPerson,
      importance: person.importance,
      updatedAt: person.updatedAt,
      createdAt: person.createdAt,
      supplementalLabels: personSupplementalLabels(l10n, person),
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class RuleMemoryTile extends StatelessWidget {
  const RuleMemoryTile({
    required this.rule,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final RuleMemoryItem rule;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final supplementalLabels = <String>[
      if (rule.triggerKeywords.isNotEmpty)
        rule.triggerKeywords.join(', '),
    ];

    return StructuredMemoryTile(
      icon: Icons.rule_rounded,
      active: rule.active,
      title: rule.title,
      subtitle: ruleMemorySubtitle(rule),
      typeLabel: rule.ruleType.memoryRecordLabel,
      importance: rule.priority,
      updatedAt: rule.updatedAt,
      createdAt: rule.createdAt,
      supplementalLabels: supplementalLabels,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class PlanMemoryTile extends StatelessWidget {
  const PlanMemoryTile({
    required this.plan,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final PlanMemoryItem plan;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final supplementalLabels = <String>[
      if (plan.targetDate != null)
        l10n.commonTargetDateValue(shortMemoryDate(plan.targetDate!)),
    ];

    return StructuredMemoryTile(
      icon: Icons.flag_outlined,
      active: plan.active,
      title: plan.title,
      subtitle: planMemorySubtitle(plan),
      typeLabel: plan.planType.memoryRecordLabel,
      importance: plan.priority,
      updatedAt: plan.updatedAt,
      createdAt: plan.createdAt,
      supplementalLabels: supplementalLabels,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class CommitmentMemoryTile extends StatelessWidget {
  const CommitmentMemoryTile({
    required this.commitment,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final CommitmentMemoryItem commitment;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final supplementalLabels = <String>[
      if (commitment.dueAt != null)
        l10n.commonDueDateValue(shortMemoryDate(commitment.dueAt!)),
    ];

    return StructuredMemoryTile(
      icon: Icons.check_circle_outline_rounded,
      active: commitment.active,
      title: commitment.title,
      subtitle: commitmentMemorySubtitle(commitment),
      typeLabel: commitment.commitmentType.memoryRecordLabel,
      importance: commitment.priority,
      updatedAt: commitment.updatedAt,
      createdAt: commitment.createdAt,
      supplementalLabels: supplementalLabels,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}
