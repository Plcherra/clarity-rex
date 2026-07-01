import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/rex/chat/presentation/widgets/chat_input_bar.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('ChatInputBar keeps the composer focused on message actions', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Hello Rex');
    addTearDown(controller.dispose);

    var sent = false;
    var voiceStarted = false;

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              onSend: () => sent = true,
              onStartVoice: () => voiceStarted = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Deep Think'), findsNothing);
    expect(find.text('Deep Think on'), findsNothing);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.byTooltip('Start voice mode'), findsOneWidget);

    await tester.tap(find.byTooltip('Send'));
    await tester.tap(find.byTooltip('Start voice mode'));

    expect(sent, isTrue);
    expect(voiceStarted, isTrue);
  });

  testWidgets('ChatInputBar shows attachment preview without mode controls', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              attachmentName: 'statement.csv',
              attachmentSize: 4096,
            ),
          ),
        ),
      ),
    );

    expect(find.text('statement.csv'), findsOneWidget);
    expect(find.text('Deep Think'), findsNothing);
    expect(find.text('Deep Think on'), findsNothing);
  });

  testWidgets('ChatInputBar keeps voice control usable during active calls', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    var voiceTapped = false;

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              isVoiceCallActive: true,
              onStartVoice: () => voiceTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Show voice call'), findsOneWidget);
    expect(find.byTooltip('Start voice mode'), findsNothing);

    await tester.tap(find.byTooltip('Show voice call'));

    expect(voiceTapped, isTrue);
  });

  testWidgets('ChatInputBar supports longer drafted messages', (tester) async {
    final controller = TextEditingController(
      text:
          'This is a longer thought for Rex that should be comfortable to draft '
          'without bringing back old mode controls or crowding the composer.',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(controller: controller),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, 7);
    expect(find.text('Deep Think'), findsNothing);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('ChatInputBar sends on Enter and keeps Shift+Enter as newline', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Hello Rex');
    addTearDown(controller.dispose);

    var sent = false;

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ChatInputBar(
            controller: controller,
            onSend: () => sent = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sent, isTrue);
    expect(controller.text, 'Hello Rex');

    sent = false;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(sent, isFalse);
  });
}
