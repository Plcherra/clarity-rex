import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/layout/clarity_native_layout.dart';
import '../../../../l10n/app_localizations.dart';
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
    this.supplementalWidgets = const [],
    this.onAddMilestone,
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
  final List<Widget> supplementalWidgets;
  final VoidCallback? onAddMilestone;
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
      supplementalWidgets: supplementalWidgets,
      onAddMilestone: onAddMilestone,
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
    this.supplementalWidgets = const [],
    this.onAddMilestone,
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
  final List<Widget> supplementalWidgets;
  final VoidCallback? onAddMilestone;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    // List row stays lean: title + optional one-line detail + type.
    // Importance and dates live in the edit sheet.
    final detailLine = _listDetailLine(
      subtitle: subtitle,
      supplementalLabels: supplementalLabels,
    );
    final metaParts = <String>[
      typeLabel,
      if (!active) l10n.commonInactive,
    ];
    final updatedLabel = memoryUpdatedLabel(l10n, updatedAt, createdAt);
    final semanticsParts = <String>[
      title,
      ?detailLine,
      ...metaParts,
      memoryImportanceShortLabel(l10n, importance),
      if (updatedLabel.isNotEmpty) updatedLabel,
    ];
    // Plan/Goals tiles may still pass milestone chips; Knows never sets this.
    final showPlanExtras = onAddMilestone != null &&
        (supplementalLabels.isNotEmpty || supplementalWidgets.isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.listRowPadding(context).left
            : RexUiTokens.space16,
        ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.listRowGap(context)
            : RexUiTokens.space2,
        ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.listRowPadding(context).right
            : RexUiTokens.space16,
        ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.listRowGap(context)
            : RexUiTokens.space2,
      ),
      child: Semantics(
        button: true,
        label: semanticsParts.join(', '),
        child: Material(
          color: colors.surfaceSoft.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(RexUiTokens.memoryTileRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(RexUiTokens.memoryTileRadius),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RexUiTokens.memoryTilePaddingH,
                vertical: RexUiTokens.memoryTilePaddingV,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      icon,
                      color: active ? colors.accent : colors.textMuted,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: RexUiTokens.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: active
                                ? colors.textPrimary
                                : colors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (detailLine != null) ...[
                          const SizedBox(height: RexUiTokens.space2),
                          Text(
                            detailLine,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: active
                                  ? colors.textSecondary
                                  : colors.textMuted,
                              height: 1.25,
                            ),
                          ),
                        ],
                        const SizedBox(height: RexUiTokens.space2),
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (showPlanExtras) ...[
                          const SizedBox(height: RexUiTokens.space4),
                          Wrap(
                            spacing: RexUiTokens.space8,
                            runSpacing: RexUiTokens.space4,
                            children: [
                              for (final label in supplementalLabels)
                                MemoryMetaChip(label: label),
                              ...supplementalWidgets,
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: RexUiTokens.space4),
                  _MemoryActionsMenu(
                    onEdit: onEdit,
                    onDeactivate: onDeactivate,
                    onAddMilestone: onAddMilestone,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _listDetailLine({
  required String? subtitle,
  required List<String> supplementalLabels,
}) {
  final trimmed = subtitle?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return trimmed;
  }
  for (final label in supplementalLabels) {
    final value = label.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

List<Widget> baseMemoryChips({
  required AppLocalizations l10n,
  required String typeLabel,
  required bool active,
  required DateTime? savedAt,
}) {
  return [
    MemoryMetaChip(label: typeLabel),
    if (savedAt != null)
      MemoryMetaChip(label: memoryUpdatedLabel(l10n, savedAt, null)),
    if (!active) MemoryMetaChip(label: l10n.commonInactive),
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

class _MemoryActionsMenu extends StatelessWidget {
  const _MemoryActionsMenu({
    required this.onEdit,
    required this.onDeactivate,
    this.onAddMilestone,
  });

  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onAddMilestone;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    return PopupMenuButton<_MemoryAction>(
      tooltip: l10n.memoryTileActionsTooltip,
      color: colors.surfaceElevated,
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
      ),
      onSelected: (action) {
        switch (action) {
          case _MemoryAction.edit:
            onEdit();
          case _MemoryAction.addMilestone:
            onAddMilestone?.call();
          case _MemoryAction.delete:
            onDeactivate?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MemoryAction.edit,
          child: _MemoryMenuItem(
            icon: Icons.edit_outlined,
            label: l10n.memoryTileQuickEdit,
          ),
        ),
        if (onAddMilestone != null)
          PopupMenuItem(
            value: _MemoryAction.addMilestone,
            child: _MemoryMenuItem(
              icon: Icons.add_task_outlined,
              label: l10n.memoryTileAddMilestone,
            ),
          ),
        if (onDeactivate != null)
          PopupMenuItem(
            value: _MemoryAction.delete,
            child: _MemoryMenuItem(
              icon: Icons.delete_outline_rounded,
              label: l10n.commonDelete,
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

enum _MemoryAction { edit, addMilestone, delete }
