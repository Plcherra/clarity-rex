import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import 'package:clarity/theme/clarity_colors.dart';

/// Shared overflow menu for conversation history rows.
class ConversationHistoryMenu extends StatelessWidget {
  const ConversationHistoryMenu({
    super.key,
    required this.onDelete,
    this.onRename,
    this.compact = false,
    this.onMenuOpenChanged,
  });

  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final bool compact;
  final ValueChanged<bool>? onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    if (onRename == null) {
      return IconButton(
        tooltip: l10n.commonDelete,
        mouseCursor: SystemMouseCursors.click,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: compact ? 32 : 36,
          minHeight: compact ? 32 : 36,
        ),
        onPressed: onDelete,
        icon: Icon(
          Icons.delete_outline_rounded,
          size: compact ? 16 : 18,
          color: colors.textMuted,
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: l10n.conversationHistoryActionsTooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: compact ? 32 : 36,
        minHeight: compact ? 32 : 36,
      ),
      icon: Icon(
        Icons.more_vert_rounded,
        size: compact ? 16 : 18,
        color: colors.textMuted,
      ),
      onOpened: () => onMenuOpenChanged?.call(true),
      onCanceled: () => onMenuOpenChanged?.call(false),
      onSelected: (value) {
        onMenuOpenChanged?.call(false);
        if (value == 'rename') {
          onRename!();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'rename',
          child: Text(l10n.commonRename),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}
