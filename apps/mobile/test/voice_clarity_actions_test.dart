import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_action_cards_strip.dart';
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
                      payload: {},
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

  testWidgets('shows pending clarity actions for text chat without voice', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: ChatTranscript(
            messages: const [
              ChatMessage(
                id: 'assistant-1',
                role: ChatMessageRole.assistant,
                content: 'Save Marcella as your friend?',
                clarityActions: [
                  ClarityActionCard(
                    id: 'person-save-1',
                    action: 'save_person',
                    writeKind: 'person',
                    payload: {},
                    confirmationText: 'Save Marcella as your friend?',
                    riskLevel: 'medium',
                    status: 'pending',
                    title: 'Marcella',
                    body: "User's friend is Marcella.",
                    editableFields: ['title', 'body'],
                  ),
                ],
              ),
            ],
            errorMessage: null,
            scrollController: ScrollController(),
            onPromptSelected: (_) {},
            onConfirmClarityAction: (_) {},
            onDismissClarityAction: (_) {},
          ),
        ),
      ),
    );

    expect(find.text(l10n.commonConfirm), findsOneWidget);
    expect(find.text(l10n.commonDismiss), findsOneWidget);
    expect(find.text('Save to Clarity Knows'), findsOneWidget);
  });

  testWidgets('failed clarity action stays visible with Retry', (tester) async {
    var retried = false;
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
                    payload: {},
                    confirmationText:
                        'Save strength routine as a plan in Clarity?',
                    riskLevel: 'medium',
                    status: 'failed',
                    errorMessage: 'Could not reach Clarity.',
                    writeKind: 'plan',
                    title: 'Strength routine',
                    body: 'Train three times a week',
                    editableFields: ['title', 'body'],
                  ),
                ],
              ),
            ],
            errorMessage: null,
            scrollController: ScrollController(),
            onPromptSelected: (_) {},
            onConfirmClarityAction: (_) => retried = true,
            onDismissClarityAction: (_) {},
          ),
        ),
      ),
    );

    expect(find.text(l10n.commonRetry), findsOneWidget);
    expect(find.text('Could not reach Clarity.'), findsOneWidget);

    await tester.tap(find.text(l10n.commonRetry));
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('compact width keeps confirm cards inline without a dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
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
                      payload: {},
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
              onConfirmClarityAction: (_) {},
              onDismissClarityAction: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ClarityActionCardsStrip), findsOneWidget);
    expect(find.text(l10n.commonConfirm), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });
}
