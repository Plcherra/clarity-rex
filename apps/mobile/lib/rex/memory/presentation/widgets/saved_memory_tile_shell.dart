import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/presentation/memory_display_helpers.dart';
import 'package:clarity/rex/memory/presentation/widgets/memory_meta_chip.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

class StructuredMemoryTile extends StatelessWidget {
  const StructuredMemoryTile({
    required this.icon,
    required this.active,
    required this.title,
    required this.typeLabel,
    required this.importance,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
    this.subtitle,
    this.updatedAt,
    this.createdAt,
    this.supplementalLabels = const [],
  });

  final IconData icon;
  final bool active;
  final String title;
  final String? subtitle;
  final String typeLabel;
  final int importance;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final List<String> supplementalLabels;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return SavedMemoryTileShell(
      icon: icon,
      active: active,
      title: title,
      subtitle: subtitle,
      typeLabel: typeLabel,
      importance: importance,
      updatedAt: updatedAt,
      createdAt: createdAt,
      supplementalLabels: supplementalLabels,
      onEdit: onEdit,
      onDeactivate: onDeactivate,
    );
  }
}

class SavedMemoryTileShell extends StatelessWidget {
  const SavedMemoryTileShell({
    required this.icon,
    required this.active,
    required this.title,
    required this.typeLabel,
    required this.importance,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
    this.subtitle,
    this.updatedAt,
    this.createdAt,
    this.supplementalLabels = const [],
  });

  final IconData icon;
  final bool active;
  final String title;
  final String? subtitle;
  final String typeLabel;
  final int importance;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final List<String> supplementalLabels;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final updatedLabel = memoryUpdatedLabel(updatedAt, createdAt);
    final metaParts = <String>[
      typeLabel,
      memoryImportanceShortLabel(importance),
      if (updatedLabel.isNotEmpty) updatedLabel,
      if (!active) 'Inactive',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space4,
        RexUiTokens.space16,
        RexUiTokens.space4,
      ),
      child: Material(
        color: colors.surfaceSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RexUiTokens.space12,
              vertical: RexUiTokens.space8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _ImportanceDot(
                    importance: importance,
                    active: active,
                  ),
                ),
                const SizedBox(width: RexUiTokens.space8),
                Icon(
                  icon,
                  color: active ? colors.accent : colors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: RexUiTokens.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: active
                              ? colors.textPrimary
                              : colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: RexUiTokens.space4),
                        Text(
                          subtitle!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: active
                                ? colors.textSecondary
                                : colors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: RexUiTokens.space4),
                      Text(
                        metaParts.join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (supplementalLabels.isNotEmpty) ...[
                        const SizedBox(height: RexUiTokens.space8),
                        Wrap(
                          spacing: RexUiTokens.space8,
                          runSpacing: RexUiTokens.space8,
                          children: [
                            for (final label in supplementalLabels)
                              MemoryMetaChip(label: label),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: RexUiTokens.space4),
                _MemoryActionsMenu(onEdit: onEdit, onDeactivate: onDeactivate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> baseMemoryChips({
  required String typeLabel,
  required bool active,
  required DateTime? savedAt,
}) {
  return [
    MemoryMetaChip(label: typeLabel),
    if (savedAt != null)
      MemoryMetaChip(label: memoryUpdatedLabel(savedAt, null)),
    if (!active) const MemoryMetaChip(label: 'Inactive'),
  ];
}

String shortMemoryDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}

DateTime? savedMemoryDate(DateTime? updatedAt, DateTime? createdAt) {
  return updatedAt ?? createdAt;
}

class _ImportanceDot extends StatelessWidget {
  const _ImportanceDot({required this.importance, required this.active});

  final int importance;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: active
            ? memoryImportanceColor(colors, importance)
            : colors.textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MemoryActionsMenu extends StatelessWidget {
  const _MemoryActionsMenu({required this.onEdit, required this.onDeactivate});

  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return PopupMenuButton<_MemoryAction>(
      tooltip: 'Memory actions',
      color: colors.surfaceElevated,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
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
          child: _MemoryMenuItem(
            icon: Icons.edit_outlined,
            label: 'Quick edit',
          ),
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
    final colors = context.clarityColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.textSecondary, size: 18),
        const SizedBox(width: RexUiTokens.space12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

enum _MemoryAction { edit, archive }
