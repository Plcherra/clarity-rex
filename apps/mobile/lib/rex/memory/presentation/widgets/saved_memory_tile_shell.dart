import 'package:flutter/material.dart';

import 'package:clarity/rex/memory/presentation/widgets/memory_meta_chip.dart';
import 'package:clarity/rex/presentation/rex_surfaces.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

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
    return SavedMemoryTileShell(
      icon: icon,
      active: active,
      title: title,
      subtitle: subtitle,
      chips: [
        const MemoryMetaChip(label: 'Structured memory'),
        ...chips,
      ],
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
    required this.chips,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
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
    final colors = context.clarityColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RexUiTokens.space16,
        RexUiTokens.space4,
        RexUiTokens.space16,
        RexUiTokens.space8,
      ),
      child: RexSurface(
        color: active
            ? colors.surface.withValues(alpha: 0.72)
            : colors.surfaceSoft.withValues(alpha: 0.48),
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
                        color: active ? colors.textPrimary : colors.textMuted,
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
                              ? colors.textSecondary
                              : colors.textMuted,
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

List<Widget> baseMemoryChips({
  required String typeLabel,
  required bool active,
  required DateTime? savedAt,
}) {
  return [
    const MemoryMetaChip(label: 'Saved memory'),
    MemoryMetaChip(label: typeLabel),
    if (savedAt != null)
      MemoryMetaChip(label: 'Updated ${shortMemoryDate(savedAt)}'),
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

class _MemoryIcon extends StatelessWidget {
  const _MemoryIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? colors.accent.withValues(alpha: 0.14)
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(
          icon,
          color: active ? colors.accent : colors.textMuted,
          size: 22,
        ),
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
      iconColor: colors.textSecondary,
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
    final colors = context.clarityColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.textSecondary, size: 20),
        const SizedBox(width: RexUiTokens.space12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _MemoryAction { edit, archive }
