import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/widgets/clarity_diamond_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('shows thinking indicator with single diamond under user message', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ChatTranscript(
            messages: const [
              ChatMessage(
                id: 'user-1',
                role: ChatMessageRole.user,
                content: 'Hello Rex',
              ),
            ],
            errorMessage: null,
            scrollController: ScrollController(),
            onPromptSelected: (_) {},
            onConfirmClarityAction: (_) {},
            onDismissClarityAction: (_) {},
            voiceState: VoiceCallState(
              phase: VoiceCallPhase.thinking,
              thinkingStartedAt: DateTime.now().subtract(const Duration(seconds: 2)),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ClarityDiamondLoader), findsOneWidget);
    expect(find.textContaining('Thinking'), findsOneWidget);
  });

  testWidgets('shows thought-for under user message after assistant reply', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ChatTranscript(
            messages: const [
              ChatMessage(
                id: 'user-1',
                role: ChatMessageRole.user,
                content: 'Hello Rex',
              ),
              ChatMessage(
                id: 'assistant-1',
                role: ChatMessageRole.assistant,
                content: 'Hi there.',
              ),
            ],
            errorMessage: null,
            scrollController: ScrollController(),
            onPromptSelected: (_) {},
            onConfirmClarityAction: (_) {},
            onDismissClarityAction: (_) {},
            voiceState: const VoiceCallState(
              phase: VoiceCallPhase.listening,
              lastThoughtDuration: Duration(seconds: 3),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ClarityDiamondLoader), findsNothing);
    expect(find.text(l10n.voicePanelThoughtFor('3s')), findsOneWidget);
  });
}
