import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/layout/clarity_native_layout.dart';
import 'package:clarity/rex/chat/data/conversation_api.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

import 'conversation_history_labels.dart';

export 'conversation_history_filters.dart';
export 'conversation_history_labels.dart';
export 'conversation_history_menu.dart';
export 'conversation_history_tile.dart';

class ConversationDateHeader extends StatelessWidget {
  const ConversationDateHeader({
    super.key,
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final native = ClarityNativeLayout.active(context);
    final horizontal = native
        ? ClarityNativeLayout.listRowPadding(context).left
        : RexUiTokens.space16;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        native ? RexUiTokens.space8 : RexUiTokens.space12,
        horizontal,
        RexUiTokens.space4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: native
                  ? ClarityNativeLayout.sectionLabel(context)
                  : theme.textTheme.labelMedium?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textMuted.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationSearchResultTile extends StatelessWidget {
  const ConversationSearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  final ConversationSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    final maxChars = ClarityNativeLayout.listTitleMaxChars(context);
    final title = conversationSearchResultTitle(
      l10n,
      result,
      maxLength: maxChars,
      ellipsis: !native,
    );
    final timestamp = timestampLabel(
      l10n,
      result.message?.timestamp ?? result.conversationTimestamp,
    );
    final listPad = ClarityNativeLayout.listRowPadding(context);
    final listGap = ClarityNativeLayout.listRowGap(context);
    final horizontal = native ? listPad.left : RexUiTokens.space16;
    final vertical = native ? listPad.top : RexUiTokens.space12;
    final previewLines = ClarityNativeLayout.listPreviewMaxLines(context);
    final showPreview = previewLines > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        native ? listGap : RexUiTokens.space8,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(
          native ? RexUiTokens.radiusSmall : RexUiTokens.radiusMedium,
        ),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: native ? 0 : RexUiTokens.space4,
            vertical: vertical,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!native) ...[
                Icon(
                  Icons.manage_search_rounded,
                  color: colors.accent,
                  size: 20,
                ),
                const SizedBox(width: RexUiTokens.space12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: native
                                ? TextOverflow.fade
                                : TextOverflow.ellipsis,
                            style: native
                                ? ClarityNativeLayout.listTitle(context)
                                : theme.textTheme.titleSmall?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                          ),
                        ),
                        const SizedBox(width: RexUiTokens.space8),
                        Text(
                          timestamp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textMuted.withValues(
                              alpha: native ? 0.78 : 1,
                            ),
                            fontWeight: native
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: native ? 11 : null,
                          ),
                        ),
                      ],
                    ),
                    if (showPreview) ...[
                      SizedBox(height: native ? 2 : RexUiTokens.space8),
                      Text(
                        result.preview.trim().isEmpty
                            ? l10n.conversationHistoryMatchedConversation
                            : result.preview,
                        maxLines: previewLines,
                        overflow: TextOverflow.ellipsis,
                        style: native
                            ? ClarityNativeLayout.listPreview(
                                context,
                              )?.copyWith(height: 1.25)
                            : theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                                height: 1.35,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
