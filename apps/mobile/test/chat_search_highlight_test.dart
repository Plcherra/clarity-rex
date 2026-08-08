import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/chat/presentation/widgets/chat_search_highlight.dart';

void main() {
  test('chatSearchTermsFromQuery drops tiny tokens', () {
    expect(
      chatSearchTermsFromQuery('  Melissa at work  '),
      ['Melissa', 'at', 'work'],
    );
    expect(chatSearchTermsFromQuery('a I'), isEmpty);
  });

  test('chatSearchHighlightSpans marks matching terms', () {
    final spans = chatSearchHighlightSpans(
      text: 'Like, this girl, she\'s called Melissa.',
      terms: const ['Melissa'],
      baseStyle: const TextStyle(color: Colors.white),
      highlightStyle: const TextStyle(
        color: Colors.black,
        backgroundColor: Colors.yellow,
      ),
    );
    final texts = spans
        .whereType<TextSpan>()
        .map((span) => span.text)
        .whereType<String>()
        .toList();
    expect(texts.join(), "Like, this girl, she's called Melissa.");
    expect(
      spans.whereType<TextSpan>().any(
        (span) =>
            span.text == 'Melissa' &&
            span.style?.backgroundColor == Colors.yellow,
      ),
      isTrue,
    );
  });
}
