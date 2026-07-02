import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:clarity/rex/chat/domain/chat_attachment.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_attachment_image.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_bubble_effects.dart'
    show ChatStreamingCursor, ChatTypingDots;
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';

/// A single chat line: assistant (left) or user (right).
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isLoading = false,
    this.isStreaming = false,
    this.clarityActions = const [],
    this.attachmentLocalPath,
    this.attachmentPreviewBytes,
    this.attachmentName,
    this.onConfirmClarityAction,
    this.onDismissClarityAction,
    this.suppressClarityActions = false,
    this.dashboardLinkAnchor,
    this.onDashboardLinkTap,
  });

  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isStreaming;
  final List<ClarityActionCard> clarityActions;
  final String? attachmentLocalPath;
  final List<int>? attachmentPreviewBytes;
  final String? attachmentName;
  final ValueChanged<ClarityActionCard>? onConfirmClarityAction;
  final ValueChanged<ClarityActionCard>? onDismissClarityAction;
  final bool suppressClarityActions;
  final DashboardInsightAnchor? dashboardLinkAnchor;
  final VoidCallback? onDashboardLinkTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 700 ? 600.0 : width * 0.86;

    final background = isUser
        ? colors.accent
        : colors.surfaceElevated.withValues(alpha: isDark ? 0.82 : 0.92);
    final foreground = isUser
        ? (isDark ? Colors.black : Colors.white)
        : colors.textPrimary;
    final codeBackground = isUser
        ? foreground.withValues(alpha: isDark ? 0.16 : 0.20)
        : colors.background.withValues(alpha: isDark ? 0.42 : 0.54);
    final imageAttachment = _buildImageAttachment(maxWidth);
    final fileAttachment = imageAttachment == null
        ? _buildFileAttachmentChip(context, maxWidth)
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 42 : 0,
        right: isUser ? 0 : 42,
        bottom: 1,
      ),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(RexUiTokens.radiusLarge),
                    topRight: const Radius.circular(RexUiTokens.radiusLarge),
                    bottomLeft: Radius.circular(
                      isUser
                          ? RexUiTokens.radiusLarge
                          : RexUiTokens.radiusSmall,
                    ),
                    bottomRight: Radius.circular(
                      isUser
                          ? RexUiTokens.radiusSmall
                          : RexUiTokens.radiusLarge,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isUser ? 16 : 15,
                    vertical: isUser ? 12 : 11,
                  ),
                  child: isLoading && text.isEmpty
                      ? ChatTypingDots(color: foreground)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageAttachment != null) ...[
                              imageAttachment,
                              if (text.trim().isNotEmpty)
                                const SizedBox(height: RexUiTokens.space8),
                            ] else if (fileAttachment != null) ...[
                              fileAttachment,
                              if (text.trim().isNotEmpty)
                                const SizedBox(height: RexUiTokens.space8),
                            ],
                            if (text.trim().isNotEmpty)
                              SelectableText.rich(
                                TextSpan(
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: foreground,
                                    height: 1.45,
                                    letterSpacing: 0,
                                  ),
                                  children: [
                                    ..._inlineMarkdownSpans(
                                      text,
                                      theme,
                                      foreground,
                                      codeBackground,
                                    ),
                                    if (isStreaming)
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: ChatStreamingCursor(
                                          color: foreground,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (!isUser &&
                                clarityActions.isNotEmpty &&
                                !suppressClarityActions) ...[
                              if (text.trim().isNotEmpty || imageAttachment != null)
                                const SizedBox(height: RexUiTokens.space12),
                              ClarityActionCardsStrip(
                                actions: clarityActions,
                                onConfirm: onConfirmClarityAction,
                                onDismiss: onDismissClarityAction,
                              ),
                            ],
                            if (!isUser &&
                                dashboardLinkAnchor != null &&
                                onDashboardLinkTap != null) ...[
                              if (text.trim().isNotEmpty ||
                                  imageAttachment != null ||
                                  clarityActions.isNotEmpty)
                                const SizedBox(height: RexUiTokens.space8),
                              ActionChip(
                                label: Text(context.l10n.rexViewOnDashboard),
                                avatar: Icon(
                                  Icons.dashboard_outlined,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: onDashboardLinkTap,
                                backgroundColor: Colors.transparent,
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.35),
                                ),
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildImageAttachment(double maxWidth) {
    final path = attachmentLocalPath?.trim();
    final bytes = attachmentPreviewBytes;
    final hasPath = path != null && path.isNotEmpty;
    final hasBytes = bytes != null && bytes.isNotEmpty;
    if (!hasPath && !hasBytes) {
      return null;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: 280,
        ),
        child: ChatAttachmentImage(
          previewBytes: hasBytes ? Uint8List.fromList(bytes!) : null,
          localPath: hasPath ? path : null,
          fit: BoxFit.cover,
          maxHeight: 280,
        ),
      ),
    );
  }

  Widget? _buildFileAttachmentChip(BuildContext context, double maxWidth) {
    final name = attachmentName?.trim();
    if (name == null || name.isEmpty || isChatImageAttachmentName(name)) {
      return null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isUser ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(RexUiTokens.radiusMedium),
        border: Border.all(
          color: Colors.white.withValues(alpha: isUser ? 0.18 : 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              name.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
              size: 18,
            ),
            const SizedBox(width: RexUiTokens.space8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _inlineMarkdownSpans(
    String value,
    ThemeData theme,
    Color foreground,
    Color codeBackground,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    var cursor = 0;

    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }

      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontFamily: 'monospace',
              backgroundColor: codeBackground,
            ),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }

    return spans.isEmpty ? [TextSpan(text: value)] : spans;
  }
}

