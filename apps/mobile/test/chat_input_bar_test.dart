import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/features/assistant/chat/presentation/widgets/chat_input_bar.dart';

void main() {
  testWidgets('ChatInputBar exposes compact Deep Think toggle', (tester) async {
    final controller = TextEditingController(text: 'Analyze this');
    addTearDown(controller.dispose);
    final selections = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              isDeepThinkEnabled: false,
              onDeepThinkChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Deep Think'), findsOneWidget);
    expect(find.text('Rex Brain Debug'), findsNothing);

    await tester.tap(find.text('Deep Think'));
    await tester.pump();

    expect(selections, [true]);
  });

  testWidgets('ChatInputBar labels selected Deep Think state', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              isDeepThinkEnabled: true,
              onDeepThinkChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Deep Think on'), findsOneWidget);
    expect(find.text('Rex Brain Debug'), findsNothing);
  });
}
