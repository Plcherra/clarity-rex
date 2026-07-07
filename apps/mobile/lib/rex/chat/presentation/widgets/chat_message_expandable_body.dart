import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:flutter/material.dart';

const int kChatMessageCollapsedMaxLines = 8;

List<InlineSpan> chatMessageInlineMarkdownSpans(
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

int chatMessageLineCount({
  required String text,
  required TextStyle style,
  required List<InlineSpan> spans,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  if (text.trim().isEmpty) {
    return 0;
  }

  final painter = TextPainter(
    text: TextSpan(style: style, children: spans),
    textDirection: textDirection,
    maxLines: null,
  )..layout(maxWidth: maxWidth);

  return painter.computeLineMetrics().length;
}

bool chatMessageShouldCollapse({
  required String text,
  required TextStyle style,
  required List<InlineSpan> spans,
  required double maxWidth,
  required TextDirection textDirection,
  required bool isStreaming,
  int maxCollapsedLines = kChatMessageCollapsedMaxLines,
}) {
  if (isStreaming || text.trim().isEmpty) {
    return false;
  }

  return chatMessageLineCount(
        text: text,
        style: style,
        spans: spans,
        maxWidth: maxWidth,
        textDirection: textDirection,
      ) >
      maxCollapsedLines;
}

/// Collapses long assistant replies with Show more / Show less.
class ChatMessageExpandableBody extends StatefulWidget {
  const ChatMessageExpandableBody({
    super.key,
    required this.text,
    required this.textStyle,
    required this.foreground,
    required this.codeBackground,
    required this.theme,
    required this.isStreaming,
    this.streamingCursor,
  });

  static const int maxCollapsedLines = kChatMessageCollapsedMaxLines;

  final String text;
  final TextStyle textStyle;
  final Color foreground;
  final Color codeBackground;
  final ThemeData theme;
  final bool isStreaming;
  final Widget? streamingCursor;

  @override
  State<ChatMessageExpandableBody> createState() =>
      _ChatMessageExpandableBodyState();
}

class _ChatMessageExpandableBodyState extends State<ChatMessageExpandableBody> {
  var _expanded = false;

  @override
  void didUpdateWidget(covariant ChatMessageExpandableBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && !widget.isStreaming) {
      _expanded = false;
    }
    if (widget.isStreaming) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spans = chatMessageInlineMarkdownSpans(
      widget.text,
      widget.theme,
      widget.foreground,
      widget.codeBackground,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final collapsible = chatMessageShouldCollapse(
          text: widget.text,
          style: widget.textStyle,
          spans: spans,
          maxWidth: maxWidth,
          textDirection: Directionality.of(context),
          isStreaming: widget.isStreaming,
        );
        final showCollapsed = collapsible && !_expanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText.rich(
              TextSpan(
                style: widget.textStyle,
                children: [
                  ...spans,
                  if (widget.isStreaming && widget.streamingCursor != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: widget.streamingCursor!,
                    ),
                ],
              ),
              maxLines: showCollapsed
                  ? ChatMessageExpandableBody.maxCollapsedLines
                  : null,
            ),
            if (collapsible) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? context.l10n.chatShowLess
                        : context.l10n.chatShowMore,
                    style: widget.theme.textTheme.labelLarge?.copyWith(
                      color: widget.theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
