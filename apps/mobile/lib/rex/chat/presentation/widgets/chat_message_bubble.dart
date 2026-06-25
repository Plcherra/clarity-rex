import 'package:flutter/material.dart';

import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_bubble_effects.dart'
    show ChatStreamingCursor, ChatTypingDots;
import 'package:clarity/rex/presentation/rex_ui_tokens.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_path_loader.dart';

/// A single chat line: assistant (left) or user (right).
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isLoading = false,
    this.isStreaming = false,
    this.clarityActions = const [],
    this.onConfirmClarityAction,
    this.onDismissClarityAction,
  });

  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isStreaming;
  final List<ClarityActionCard> clarityActions;
  final ValueChanged<ClarityActionCard>? onConfirmClarityAction;
  final ValueChanged<ClarityActionCard>? onDismissClarityAction;

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
                            if (!isUser && clarityActions.isNotEmpty) ...[
                              const SizedBox(height: RexUiTokens.space12),
                              _ClarityActionCards(
                                actions: clarityActions,
                                onConfirm: onConfirmClarityAction,
                                onDismiss: onDismissClarityAction,
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

class _ClarityActionCards extends StatelessWidget {
  const _ClarityActionCards({
    required this.actions,
    this.onConfirm,
    this.onDismiss,
  });

  final List<ClarityActionCard> actions;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Clarity action',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ClarityActionCard(
              action: action,
              onConfirm: onConfirm,
              onDismiss: onDismiss,
            ),
          ),
      ],
    );
  }
}

class _ClarityActionCard extends StatelessWidget {
  const _ClarityActionCard({
    required this.action,
    this.onConfirm,
    this.onDismiss,
  });

  final ClarityActionCard action;
  final ValueChanged<ClarityActionCard>? onConfirm;
  final ValueChanged<ClarityActionCard>? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.clarityColors;
    final isHighRisk = action.riskLevel == 'high';
    final borderColor = action.isFailed || isHighRisk
        ? scheme.error.withValues(alpha: 0.46)
        : scheme.primary.withValues(alpha: 0.38);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MemoryChip(label: action.actionLabel),
                _MemoryChip(
                  label: action.riskLabel,
                  color: isHighRisk ? scheme.error : scheme.primary,
                ),
                _MemoryChip(
                  label: action.statusLabel,
                  color: action.isFailed ? scheme.error : scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action.confirmationText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (action.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                action.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  height: 1.3,
                ),
              ),
            ],
            if (action.isApplied) ...[
              const SizedBox(height: 6),
              Text(
                'Applied to ${action.result.length} record${action.result.length == 1 ? '' : 's'}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            if (action.canConfirm ||
                action.canDismiss ||
                action.isApplying) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((action.canConfirm || action.isApplying) &&
                      onConfirm != null)
                    FilledButton.icon(
                      onPressed: action.isApplying
                          ? null
                          : () => onConfirm!(action),
                      icon: action.isApplying
                          ? const ClarityInlineLoader(size: 16, strokeWidth: 2)
                          : const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Confirm'),
                    ),
                  if (action.canDismiss && onDismiss != null)
                    OutlinedButton.icon(
                      onPressed: action.isApplying
                          ? null
                          : () => onDismiss!(action),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Dismiss'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chipColor = color ?? scheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: chipColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
