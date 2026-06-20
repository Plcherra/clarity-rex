import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/data/memory_models.dart';
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
    return SavedMemoryTileShell(
      icon: _iconForGroup(memory.memoryGroup),
      active: memory.active,
      title: memory.content,
      chips: baseMemoryChips(
        typeLabel: memory.categoryLabel,
        active: memory.active,
        savedAt: savedMemoryDate(memory.updatedAt, memory.createdAt),
      ),
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
    return StructuredMemoryTile(
      icon: Icons.person_outline_rounded,
      active: person.active,
      title: person.displayName,
      subtitle: person.summary ?? person.relationship ?? 'Person memory',
      chips: [
        if (person.relationship != null)
          MemoryMetaChip(label: person.relationship!.memoryRecordLabel),
        ..._attributeChips(person),
        if (savedMemoryDate(person.updatedAt, person.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${shortMemoryDate(savedMemoryDate(person.updatedAt, person.createdAt)!)}',
          ),
        if (!person.active) const MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }

  List<Widget> _attributeChips(PersonMemoryItem person) {
    return [
      if (person.fullName != null)
        MemoryMetaChip(label: 'Name: ${person.fullName}'),
      if (person.location != null)
        MemoryMetaChip(label: 'Location: ${person.location}'),
      if (person.birthday != null)
        MemoryMetaChip(label: 'Birthday: ${person.birthday}'),
      if (person.job != null) MemoryMetaChip(label: 'Job: ${person.job}'),
      if (person.workplace != null)
        MemoryMetaChip(label: 'Workplace: ${person.workplace}'),
      if (person.notes != null) MemoryMetaChip(label: 'Notes: ${person.notes}'),
      for (final date in person.importantDates)
        MemoryMetaChip(label: 'Important date: $date'),
    ];
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
    return StructuredMemoryTile(
      icon: Icons.rule_rounded,
      active: rule.active,
      title: rule.title,
      subtitle: rule.ruleText,
      chips: [
        MemoryMetaChip(label: rule.ruleType.memoryRecordLabel),
        if (savedMemoryDate(rule.updatedAt, rule.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${shortMemoryDate(savedMemoryDate(rule.updatedAt, rule.createdAt)!)}',
          ),
        if (rule.triggerKeywords.isNotEmpty)
          MemoryMetaChip(label: rule.triggerKeywords.join(', ')),
        if (!rule.active) const MemoryMetaChip(label: 'Inactive'),
      ],
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
    return StructuredMemoryTile(
      icon: Icons.flag_outlined,
      active: plan.active,
      title: plan.title,
      subtitle: plan.desiredOutcome ?? plan.description ?? 'Plan memory',
      chips: [
        MemoryMetaChip(label: plan.planType.memoryRecordLabel),
        if (plan.targetDate != null)
          MemoryMetaChip(label: 'Target ${shortMemoryDate(plan.targetDate!)}'),
        if (savedMemoryDate(plan.updatedAt, plan.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${shortMemoryDate(savedMemoryDate(plan.updatedAt, plan.createdAt)!)}',
          ),
        if (!plan.active) const MemoryMetaChip(label: 'Inactive'),
      ],
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
    return StructuredMemoryTile(
      icon: Icons.check_circle_outline_rounded,
      active: commitment.active,
      title: commitment.title,
      subtitle: commitment.commitmentText,
      chips: [
        MemoryMetaChip(label: commitment.commitmentType.memoryRecordLabel),
        if (commitment.dueAt != null)
          MemoryMetaChip(label: 'Due ${shortMemoryDate(commitment.dueAt!)}'),
        if (savedMemoryDate(commitment.updatedAt, commitment.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${shortMemoryDate(savedMemoryDate(commitment.updatedAt, commitment.createdAt)!)}',
          ),
        if (!commitment.active) const MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}
