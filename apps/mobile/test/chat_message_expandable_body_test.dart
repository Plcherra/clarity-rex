import 'package:clarity/rex/chat/presentation/widgets/chat_message_expandable_body.dart';
import 'package:clarity/theme/clarity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chatMessageInlineMarkdownSpans keeps bold and code spans', () {
    final spans = chatMessageInlineMarkdownSpans(
      'Hello **world** and `code`.',
      ClarityTheme.light(),
      Colors.black,
      Colors.grey,
    );

    expect(spans, isNotEmpty);
    expect(
      spans.any((span) => span is TextSpan && span.text == 'world'),
      isTrue,
    );
    expect(
      spans.any((span) => span is TextSpan && span.text == 'code'),
      isTrue,
    );
  });
}
