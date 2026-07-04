import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/memory_l10n.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_meta_chip.dart';
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
    final l10n = context.l10n;
    return SavedMemoryTileShell(
      icon: _iconForGroup(memory.memoryGroup),
      active: memory.active,
      title: memory.content,
      typeLabel: memory.memoryType.localizedLabel(l10n),
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
    this.eventPreviews = const [],
    super.key,
  });

  final PersonMemoryItem person;
  final List<EntityEventItem> eventPreviews;
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
      supplementalLabels: [
        ...personSupplementalLabels(l10n, person),
        ...entityEventPreviewLabels(l10n, eventPreviews),
      ],
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
    final l10n = context.l10n;
    final supplementalLabels = <String>[
      if (rule.triggerKeywords.isNotEmpty)
        rule.triggerKeywords.join(', '),
    ];

    return StructuredMemoryTile(
      icon: Icons.rule_rounded,
      active: rule.active,
      title: rule.title,
      subtitle: ruleMemorySubtitle(rule),
      typeLabel: localizedMemoryRecordLabel(l10n, rule.ruleType),
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
    required this.onAddMilestone,
    required this.onEditMilestone,
    this.milestonePreviews = const [],
    super.key,
  });

  final PlanMemoryItem plan;
  final List<PlanMilestoneMemoryItem> milestonePreviews;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback onAddMilestone;
  final ValueChanged<PlanMilestoneMemoryItem> onEditMilestone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final supplementalLabels = <String>[
      if (plan.targetDate != null)
        l10n.commonTargetDateValue(shortMemoryDate(plan.targetDate!)),
    ];
    final milestoneWidgets = milestonePreviews
        .map(
          (milestone) => GestureDetector(
            onTap: () => onEditMilestone(milestone),
            behavior: HitTestBehavior.opaque,
            child: MemoryMetaChip(
              label:
                  '${localizedMemoryRecordLabel(l10n, 'plan_milestone')}: ${milestone.previewLabel}',
            ),
          ),
        )
        .toList(growable: false);

    return StructuredMemoryTile(
      icon: Icons.flag_outlined,
      active: plan.active,
      title: plan.title,
      subtitle: planMemorySubtitle(plan),
      typeLabel: localizedMemoryRecordLabel(l10n, plan.planType),
      importance: plan.priority,
      updatedAt: plan.updatedAt,
      createdAt: plan.createdAt,
      supplementalLabels: supplementalLabels,
      supplementalWidgets: milestoneWidgets,
      onAddMilestone: onAddMilestone,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}
