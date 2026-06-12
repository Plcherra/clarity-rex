import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/data/memory_models.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_meta_chip.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';

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
    return _SavedMemoryTileShell(
      icon: _iconForType(memory.memoryType),
      active: memory.active,
      title: memory.content,
      chips: _baseChips(
        typeLabel: memory.memoryType.label,
        active: memory.active,
        savedAt: _savedDate(memory.updatedAt, memory.createdAt),
      ),
      onEdit: onEdit,
      onDeactivate: onDeactivate,
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
        if (person.aliases.isNotEmpty)
          MemoryMetaChip(label: 'Also ${person.aliases.join(', ')}'),
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
    return _SavedMemoryTileShell(
      icon: icon,
      active: active,
      title: title,
      subtitle: subtitle,
      chips: chips,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class _SavedMemoryTileShell extends StatelessWidget {
  const _SavedMemoryTileShell({
    required this.icon,
    required this.active,
    required this.title,
    required this.chips,
    required this.onEdit,
    required this.onDeactivate,
    this.subtitle,
  });

  final IconData icon;
  final bool active;
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space4,
        RexUiTokens.space16,
        RexUiTokens.space8,
      ),
      child: RexSurface(
        color: active ? RexUiTokens.surface : RexUiTokens.surfaceSoft,
        borderColor: active
            ? RexUiTokens.border
            : RexUiTokens.border.withValues(alpha: 0.55),
        radius: RexUiTokens.radiusMedium,
        padding: const EdgeInsets.all(RexUiTokens.space16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEdit,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MemoryIcon(icon: icon, active: active),
              const SizedBox(width: RexUiTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: active
                            ? RexUiTokens.text
                            : RexUiTokens.textSubtle,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: RexUiTokens.space8),
                      Text(
                        subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: active
                              ? RexUiTokens.textMuted
                              : RexUiTokens.textSubtle,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: RexUiTokens.space12),
                      Wrap(
                        spacing: RexUiTokens.space8,
                        runSpacing: RexUiTokens.space8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: RexUiTokens.space8),
              _MemoryActionsMenu(onEdit: onEdit, onDeactivate: onDeactivate),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryIcon extends StatelessWidget {
  const _MemoryIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? RexUiTokens.accent.withValues(alpha: 0.18)
            : RexUiTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(
          icon,
          color: active ? RexUiTokens.accent : RexUiTokens.textSubtle,
          size: 22,
        ),
      ),
    );
  }
}

List<Widget> _baseChips({
  required String typeLabel,
  required bool active,
  required DateTime? savedAt,
}) {
  return [
    MemoryMetaChip(label: typeLabel),
    if (savedAt != null)
      MemoryMetaChip(label: 'Updated ${_shortDate(savedAt)}'),
    if (!active) const MemoryMetaChip(label: 'Inactive'),
  ];
}

class _MemoryActionsMenu extends StatelessWidget {
  const _MemoryActionsMenu({required this.onEdit, required this.onDeactivate});

  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MemoryAction>(
      tooltip: 'Memory actions',
      color: RexUiTokens.surfaceRaised,
      iconColor: RexUiTokens.textMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        side: const BorderSide(color: RexUiTokens.border),
      ),
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
          child: _MemoryMenuItem(icon: Icons.edit_outlined, label: 'Edit'),
        ),
        if (onDeactivate != null)
          const PopupMenuItem(
            value: _MemoryAction.archive,
            child: _MemoryMenuItem(
              icon: Icons.visibility_off_outlined,
              label: 'Archive',
            ),
          ),
      ],
    );
  }
}

class _MemoryMenuItem extends StatelessWidget {
  const _MemoryMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: RexUiTokens.textMuted, size: 20),
        const SizedBox(width: RexUiTokens.space12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: RexUiTokens.text,
            fontWeight: FontWeight.w700,
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
