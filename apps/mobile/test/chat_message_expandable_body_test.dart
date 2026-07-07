import 'package:clarity/rex/chat/presentation/widgets/chat_message_expandable_body.dart';
import 'package:clarity/theme/clarity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chatMessageShouldCollapse ignores streaming replies', () {
    const textStyle = TextStyle(fontSize: 16, height: 1.45);
    const text = 'Line one\nLine two\nLine three\nLine four\n'
        'Line five\nLine six\nLine seven\nLine eight\n'
        'Line nine\nLine ten';

    final spans = chatMessageInlineMarkdownSpans(
      text,
      ClarityTheme.light(),
      Colors.black,
      Colors.grey,
    );

    expect(
      chatMessageShouldCollapse(
        text: text,
        style: textStyle,
        spans: spans,
        maxWidth: 280,
        textDirection: TextDirection.ltr,
        isStreaming: true,
      ),
      isFalse,
    );
  });

  test('chatMessageShouldCollapse detects long assistant replies', () {
    const textStyle = TextStyle(fontSize: 16, height: 1.45);
    const text = 'Line one\nLine two\nLine three\nLine four\n'
        'Line five\nLine six\nLine seven\nLine eight\n'
        'Line nine\nLine ten';

    final spans = chatMessageInlineMarkdownSpans(
      text,
      ClarityTheme.light(),
      Colors.black,
      Colors.grey,
    );

    expect(
      chatMessageShouldCollapse(
        text: text,
        style: textStyle,
        spans: spans,
        maxWidth: 280,
        textDirection: TextDirection.ltr,
        isStreaming: false,
      ),
      isTrue,
    );
  });
}
