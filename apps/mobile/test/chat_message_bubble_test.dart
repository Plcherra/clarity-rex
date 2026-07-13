import 'package:clarity/rex/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/theme/clarity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

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

  testWidgets('user bubble uses soft accent tint without a border', (
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

    expect(decoration.color, ClarityColors.dark.accentSoft);
    expect(decoration.border, isNull);
  });

  testWidgets('long assistant replies show full text without Show more', (
    tester,
  ) async {
    final longText = List.generate(
      12,
      (index) => 'Assistant insight line ${index + 1} with enough words to wrap.',
    ).join('\n');

    await tester.pumpWidget(
      wrapWithL10nScaffold(
        SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: ChatMessageBubble(text: longText),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show more'), findsNothing);
    expect(find.text('Show less'), findsNothing);
    expect(find.textContaining('Assistant insight line 12'), findsOneWidget);
  });

  testWidgets('streaming assistant replies show full text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final longText = List.generate(
      12,
      (index) => 'Streaming insight line ${index + 1} with enough words to wrap.',
    ).join('\n');

    await tester.pumpWidget(
      wrapWithL10nScaffold(
        SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: ChatMessageBubble(
              text: longText,
              isStreaming: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Show more'), findsNothing);
    expect(find.textContaining('Streaming insight line 12'), findsOneWidget);
  });
}

BoxDecoration _bubbleDecoration(WidgetTester tester) {
  final decoratedBoxes = tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  );
  final decoration = decoratedBoxes
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.borderRadius != null)
      .first;
  return decoration;
}
