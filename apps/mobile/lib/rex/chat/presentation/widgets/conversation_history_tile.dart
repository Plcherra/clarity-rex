import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/layout/clarity_native_layout.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'conversation_history_labels.dart';
import 'conversation_history_menu.dart';

/// Dense / card conversation row for Chats history.
///
/// Density is driven by [ClarityNativeLayout.active] (phone) or [compact]
/// (wide desktop sidebar) — not card tiles on phone.
class ConversationHistoryTile extends StatefulWidget {
  const ConversationHistoryTile({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    this.onRename,
    this.compact = false,
  });

  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRename;

  /// Desktop sidebar title-only density (wide `/app/` chat split).
  final bool compact;

  @override
  State<ConversationHistoryTile> createState() =>
      _ConversationHistoryTileState();
}

class _ConversationHistoryTileState extends State<ConversationHistoryTile> {
  bool _hovered = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    final sidebarCompact = widget.compact;
    // Dense rows: phone native compact OR desktop sidebar — not card tiles.
    final dense = native || sidebarCompact;
    // Phone: title + one preview line. Sidebar stays title-only.
    final showPreview = native && !sidebarCompact;
    final showGlyph = !dense;
    final showActions = !dense || _hovered || _menuOpen;

    final maxChars = ClarityNativeLayout.listTitleMaxChars(context);
    final title = conversationTitle(
      l10n,
      widget.conversation,
      maxLength: maxChars,
    );
    final preview = conversationPreview(l10n, widget.conversation);
    final previewLines = ClarityNativeLayout.listPreviewMaxLines(context);
    final listPad = ClarityNativeLayout.listRowPadding(context);
    final listGap = ClarityNativeLayout.listRowGap(context);

    final outerHorizontal = native
        ? listPad.left
        : (sidebarCompact ? RexUiTokens.space8 : RexUiTokens.space16);
    final outerBottom = native ? listGap : (sidebarCompact ? 2.0 : 8.0);
    final innerVertical = native
        ? listPad.top
        : (sidebarCompact ? 6.0 : RexUiTokens.space12);
    final innerHorizontal = native
        ? 0.0
        : (sidebarCompact ? RexUiTokens.space8 : RexUiTokens.space4);
    final radius = dense ? RexUiTokens.radiusSmall : RexUiTokens.radiusMedium;
    final stamp = timestampLabel(l10n, widget.conversation.timestamp);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        outerHorizontal,
        0,
        outerHorizontal,
        outerBottom,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: widget.isSelected
              ? colors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: widget.onTap,
            onLongPress: widget.onDelete,
            mouseCursor: SystemMouseCursors.click,
            hoverColor: colors.accent.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: innerHorizontal,
                vertical: innerVertical,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showGlyph) ...[
                    _ConversationGlyph(isSelected: widget.isSelected),
                    const SizedBox(width: RexUiTokens.space12),
                  ],
                  Expanded(
                    child: showPreview
                        ? _NativeDenseContent(
                            title: title,
                            preview: preview,
                            previewLines: previewLines,
                            timestamp: stamp,
                            isSelected: widget.isSelected,
                          )
                        : dense
                        ? _SidebarCompactContent(
                            title: title,
                            timestamp: stamp,
                            isSelected: widget.isSelected,
                          )
                        : _CardContent(
                            title: title,
                            preview: preview,
                            timestamp: stamp,
                            isSelected: widget.isSelected,
                          ),
                  ),
                  if (showActions) ...[
                    const SizedBox(width: RexUiTokens.space4),
                    ConversationHistoryMenu(
                      onDelete: widget.onDelete,
                      onRename: widget.onRename,
                      compact: dense,
                      onMenuOpenChanged: (open) {
                        setState(() => _menuOpen = open);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NativeDenseContent extends StatelessWidget {
  const _NativeDenseContent({
    required this.title,
    required this.preview,
    required this.previewLines,
    required this.timestamp,
    required this.isSelected,
  });

  final String title;
  final String preview;
  final int previewLines;
  final String timestamp;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ClarityNativeLayout.listTitle(
                  context,
                  selected: isSelected,
                )?.copyWith(height: 1.2),
              ),
            ),
            if (timestamp.isNotEmpty) ...[
              const SizedBox(width: RexUiTokens.space8),
              Text(
                timestamp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          preview,
          maxLines: previewLines,
          overflow: TextOverflow.ellipsis,
          style: ClarityNativeLayout.listPreview(
            context,
          )?.copyWith(height: 1.25),
        ),
      ],
    );
  }
}

class _SidebarCompactContent extends StatelessWidget {
  const _SidebarCompactContent({
    required this.title,
    required this.timestamp,
    required this.isSelected,
  });

  final String title;
  final String timestamp;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: RexUiTokens.space8),
        Text(
          timestamp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.isSelected,
  });

  final String title;
  final String preview;
  final String timestamp;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: RexUiTokens.space8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                timestamp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RexUiTokens.space8),
        Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ConversationGlyph extends StatelessWidget {
  const _ConversationGlyph({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return Icon(
      Icons.chat_bubble_outline_rounded,
      color: isSelected ? colors.accent : colors.textMuted,
      size: 20,
    );
  }
}
