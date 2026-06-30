import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('shows pending clarity actions above voice transcript during call', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ChatTranscript(
              messages: const [
                ChatMessage(
                  id: 'assistant-1',
                  role: ChatMessageRole.assistant,
                  content: 'Should I save that?',
                  clarityActions: [
                    ClarityActionCard(
                      id: 'plan-save-1',
                      action: 'save_plan',
                      payload: const {},
                      confirmationText:
                          'Save strength routine as a plan in Clarity?',
                      riskLevel: 'medium',
                      status: 'pending',
                    ),
                  ],
                ),
              ],
              errorMessage: null,
              scrollController: ScrollController(),
              onPromptSelected: (_) {},
              onConfirmClarityAction: (_) => confirmed = true,
              onDismissClarityAction: (_) {},
              voiceState: const VoiceCallState(phase: VoiceCallPhase.listening),
          ),
        ),
      ),
    );

    expect(find.text(l10n.commonConfirm), findsOneWidget);
    expect(find.text(l10n.commonDismiss), findsOneWidget);

    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pump();

    expect(confirmed, isTrue);
  });
}
