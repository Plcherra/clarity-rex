import 'package:flutter/material.dart';

import 'package:clarity/rex/chat/presentation/widgets/chat_search_highlight.dart';

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

/// Full assistant reply body (no collapse / Show more).
class ChatMessageExpandableBody extends StatelessWidget {
  const ChatMessageExpandableBody({
    super.key,
    required this.text,
    required this.textStyle,
    required this.foreground,
    required this.codeBackground,
    required this.theme,
    required this.isStreaming,
    this.streamingCursor,
    this.highlightTerms = const [],
    this.highlightStyle,
  });

  final String text;
  final TextStyle textStyle;
  final Color foreground;
  final Color codeBackground;
  final ThemeData theme;
  final bool isStreaming;
  final Widget? streamingCursor;
  final List<String> highlightTerms;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    var spans = chatMessageInlineMarkdownSpans(
      text,
      theme,
      foreground,
      codeBackground,
    );
    final markStyle = highlightStyle;
    if (markStyle != null && highlightTerms.isNotEmpty) {
      spans = applyChatSearchHighlights(
        spans: spans,
        terms: highlightTerms,
        highlightStyle: markStyle,
      );
    }

    return SelectableText.rich(
      TextSpan(
        style: textStyle,
        children: [
          ...spans,
          if (isStreaming && streamingCursor != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: streamingCursor!,
            ),
        ],
      ),
    );
  }
}
