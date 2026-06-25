import 'package:clarity/rex/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('assistant bubble uses light theme surface without a border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ClarityTheme.light(),
        home: const Scaffold(
          body: ChatMessageBubble(text: 'Rex reply with `code`.'),
        ),
      ),
    );

    final decoration = _bubbleDecoration(tester);

    expect(
      decoration.color,
      ClarityColors.light.surfaceElevated.withValues(alpha: 0.92),
    );
    expect(decoration.border, isNull);
  });

  testWidgets('user bubble uses dark theme accent without a border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ClarityTheme.dark(),
        home: const Scaffold(
          body: ChatMessageBubble(text: 'User message', isUser: true),
        ),
      ),
    );

    final decoration = _bubbleDecoration(tester);

    expect(decoration.color, ClarityColors.dark.accent);
    expect(decoration.border, isNull);
  });
}

BoxDecoration _bubbleDecoration(WidgetTester tester) {
  final decoratedBoxes = tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  );
  final decoration = decoratedBoxes
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((decoration) => decoration.borderRadius != null);
  return decoration;
}
