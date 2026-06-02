import 'package:flutter/material.dart';

import 'package:clarity/features/assistant/memory/data/memory_models.dart';
import 'package:clarity/features/assistant/memory/presentation/widgets/memory_meta_chip.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: memory.active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: memory.active
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        child: Icon(_iconForType(memory.memoryType), size: 20),
      ),
      title: Text(memory.content),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MemoryMetaChip(label: memory.memoryType.label),
            const MemoryMetaChip(label: 'Rex knows this'),
            MemoryMetaChip(label: 'Importance ${memory.importance}'),
            if (_savedDate(memory.updatedAt, memory.createdAt) != null)
              MemoryMetaChip(
                label:
                    'Updated ${_shortDate(_savedDate(memory.updatedAt, memory.createdAt)!)}',
              ),
            if (!memory.active) const MemoryMetaChip(label: 'Inactive'),
          ],
        ),
      ),
      trailing: _MemoryActionsMenu(onEdit: onEdit, onDeactivate: onDeactivate),
      onTap: onEdit,
      textColor: memory.active ? null : scheme.onSurfaceVariant,
      titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
        color: memory.active ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
    );
  }

  IconData _iconForType(MemoryType type) {
    switch (type) {
      case MemoryType.fact:
        return Icons.badge_outlined;
      case MemoryType.preference:
        return Icons.tune_rounded;
      case MemoryType.event:
        return Icons.event_note_outlined;
      case MemoryType.other:
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
        const MemoryMetaChip(label: 'Rex knows this'),
        if (person.aliases.isNotEmpty)
          MemoryMetaChip(label: 'Also ${person.aliases.join(', ')}'),
        MemoryMetaChip(label: 'Importance ${person.importance}'),
        MemoryMetaChip(label: person.status.memoryRecordLabel),
        if (_savedDate(person.updatedAt, person.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(person.updatedAt, person.createdAt)!)}',
          ),
        if (!person.active) const MemoryMetaChip(label: 'Inactive'),
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
    return StructuredMemoryTile(
      icon: Icons.rule_rounded,
      active: rule.active,
      title: rule.title,
      subtitle: rule.ruleText,
      chips: [
        MemoryMetaChip(label: rule.ruleType.memoryRecordLabel),
        const MemoryMetaChip(label: 'Rex knows this'),
        MemoryMetaChip(label: rule.status.memoryRecordLabel),
        MemoryMetaChip(label: 'Priority ${rule.priority}'),
        if (_savedDate(rule.updatedAt, rule.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(rule.updatedAt, rule.createdAt)!)}',
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
        const MemoryMetaChip(label: 'Rex knows this'),
        MemoryMetaChip(label: plan.status.memoryRecordLabel),
        MemoryMetaChip(label: 'Priority ${plan.priority}'),
        if (plan.targetDate != null)
          MemoryMetaChip(label: 'Target ${_shortDate(plan.targetDate!)}'),
        if (_savedDate(plan.updatedAt, plan.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(plan.updatedAt, plan.createdAt)!)}',
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
        const MemoryMetaChip(label: 'Rex knows this'),
        MemoryMetaChip(label: commitment.status.memoryRecordLabel),
        MemoryMetaChip(label: 'Priority ${commitment.priority}'),
        if (commitment.dueAt != null)
          MemoryMetaChip(label: 'Due ${_shortDate(commitment.dueAt!)}'),
        if (_savedDate(commitment.updatedAt, commitment.createdAt) != null)
          MemoryMetaChip(
            label:
                'Updated ${_shortDate(_savedDate(commitment.updatedAt, commitment.createdAt)!)}',
          ),
        if (!commitment.active) const MemoryMetaChip(label: 'Inactive'),
      ],
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class StructuredMemoryTile extends StatelessWidget {
  const StructuredMemoryTile({
    required this.icon,
    required this.active,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final IconData icon;
  final bool active;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        foregroundColor: active
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: active ? scheme.onSurfaceVariant : scheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          ],
        ),
      ),
      textColor: active ? null : scheme.onSurfaceVariant,
      titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
        color: active ? scheme.onSurface : scheme.onSurfaceVariant,
      ),
      trailing: _MemoryActionsMenu(onEdit: onEdit, onDeactivate: onDeactivate),
      onTap: onEdit,
    );
  }
}

class _MemoryActionsMenu extends StatelessWidget {
  const _MemoryActionsMenu({required this.onEdit, required this.onDeactivate});

  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MemoryAction>(
      tooltip: 'Memory actions',
      onSelected: (action) {
        switch (action) {
          case _MemoryAction.edit:
            onEdit();
          case _MemoryAction.archive:
            onDeactivate?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _MemoryAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        if (onDeactivate != null)
          const PopupMenuItem(
            value: _MemoryAction.archive,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Archive'),
            ),
          ),
      ],
    );
  }
}

enum _MemoryAction { edit, archive }

String _shortDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}

DateTime? _savedDate(DateTime? updatedAt, DateTime? createdAt) {
  return updatedAt ?? createdAt;
}
