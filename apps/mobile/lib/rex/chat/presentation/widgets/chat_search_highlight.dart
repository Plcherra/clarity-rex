import 'package:flutter/material.dart';

/// Split a search box query into highlightable terms.
List<String> chatSearchTermsFromQuery(String query) {
  return query
      .split(RegExp(r'\s+'))
      .map((term) => term.trim())
      .where((term) => term.length >= 2)
      .toList(growable: false);
}

/// Builds rich text that marks [terms] inside [text] (case-insensitive).
List<InlineSpan> chatSearchHighlightSpans({
  required String text,
  required List<String> terms,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
}) {
  final cleaned = terms
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
  if (text.isEmpty || cleaned.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final pattern = RegExp(
    cleaned.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
  }
  return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
}

/// Highlights search terms inside existing markdown/plain [spans].
List<InlineSpan> applyChatSearchHighlights({
  required List<InlineSpan> spans,
  required List<String> terms,
  required TextStyle highlightStyle,
}) {
  final cleaned = terms
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
  if (cleaned.isEmpty) {
    return spans;
  }
  final pattern = RegExp(
    cleaned.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );

  final out = <InlineSpan>[];
  for (final span in spans) {
    if (span is! TextSpan || span.text == null || span.text!.isEmpty) {
      out.add(span);
      continue;
    }
    final text = span.text!;
    final base = span.style;
    var cursor = 0;
    var matched = false;
    for (final match in pattern.allMatches(text)) {
      matched = true;
      if (match.start > cursor) {
        out.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: base,
          ),
        );
      }
      out.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: (base ?? const TextStyle()).merge(highlightStyle),
        ),
      );
      cursor = match.end;
    }
    if (!matched) {
      out.add(span);
      continue;
    }
    if (cursor < text.length) {
      out.add(TextSpan(text: text.substring(cursor), style: base));
    }
  }
  return out;
}

TextStyle chatSearchHighlightStyle(ClaritySearchHighlightColors colors) {
  return TextStyle(
    color: colors.foreground,
    backgroundColor: colors.background,
    fontWeight: FontWeight.w700,
  );
}

class ClaritySearchHighlightColors {
  const ClaritySearchHighlightColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
