import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_intent.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_service.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/presentation/widgets/accounts_aware_chat_transcript.dart';
import 'package:clarity/rex/chat/presentation/widgets/chat_transcript.dart';
import 'package:clarity/rex/chat/presentation/widgets/empty_chat_prompts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

ChatTranscript _emptyTranscript({
  required ValueChanged<String> onPromptSelected,
  required bool hasLinkedAccounts,
}) {
  return ChatTranscript(
    messages: const [],
    errorMessage: null,
    scrollController: ScrollController(),
    onPromptSelected: onPromptSelected,
    onConfirmClarityAction: (_) {},
    onDismissClarityAction: (_) {},
    hasLinkedAccounts: hasLinkedAccounts,
  );
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final es = lookupAppLocalizations(const Locale('es'));

  test('memory chips do not attach finance context', () {
    for (final l10n in [en, es]) {
      for (final prompt in emptyChatPrompts(l10n, hasLinkedAccounts: false)) {
        expect(
          shouldAttachAssistantFinancialContext(prompt),
          isFalse,
          reason: prompt,
        );
      }
    }
    expect(shouldAttachAssistantFinancialContext('hey'), isFalse);
    expect(shouldAttachAssistantFinancialContext('hola'), isFalse);
    expect(
      shouldAttachAssistantFinancialContext('el desgaste del auto'),
      isFalse,
    );
  });

  test('money chips attach finance context in English and Spanish', () {
    for (final l10n in [en, es]) {
      final prompts = emptyChatPrompts(l10n, hasLinkedAccounts: true);
      expect(prompts, hasLength(3));
      for (final prompt in prompts) {
        expect(
          shouldAttachAssistantFinancialContext(prompt),
          isTrue,
          reason: prompt,
        );
      }
    }
  });

  testWidgets('empty chat shows memory chips when no accounts exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: _emptyTranscript(
            onPromptSelected: (_) {},
            hasLinkedAccounts: false,
          ),
        ),
      ),
    );

    expect(find.text(en.chatTranscriptPromptRemember), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptThinkTonight), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptCheckKnows), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptSpendWeek), findsNothing);
    expect(find.text(en.chatTranscriptPromptBankBalance), findsNothing);
    expect(find.text(en.chatTranscriptPromptAccounts), findsNothing);
  });

  testWidgets('empty chat shows money chips when accounts exist', (
    tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: _emptyTranscript(
            onPromptSelected: (prompt) => selected = prompt,
            hasLinkedAccounts: true,
          ),
        ),
      ),
    );

    expect(find.text(en.chatTranscriptPromptSpendWeek), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptBankBalance), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptAccounts), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptRemember), findsNothing);

    await tester.tap(find.text(en.chatTranscriptPromptSpendWeek));
    expect(selected, en.chatTranscriptPromptSpendWeek);
  });

  testWidgets('Spanish empty chat shows localized money chips', (tester) async {
    await tester.pumpWidget(
      wrapWithSpanishL10n(
        Scaffold(
          body: _emptyTranscript(
            onPromptSelected: (_) {},
            hasLinkedAccounts: true,
          ),
        ),
      ),
    );

    expect(find.text(es.chatTranscriptPromptSpendWeek), findsOneWidget);
    expect(find.text(es.chatTranscriptPromptBankBalance), findsOneWidget);
    expect(find.text(es.chatTranscriptPromptAccounts), findsOneWidget);
  });

  testWidgets('accounts-aware empty chat flips to money chips', (tester) async {
    final service = AssistantFinancialContextService(
      loadFinancialReadModel: () async {
        return FinancialReadModel.fromRecords(
          accounts: const [
            Account(
              id: 'checking',
              name: 'Checking',
              type: AccountType.checking,
            ),
          ],
          transactionRecords: const [],
          budgets: const [],
        );
      },
      spendReference: () => DateTime(2026, 8, 20),
      notifyDataChanged: () {},
    );

    await tester.pumpWidget(
      wrapWithL10n(
        ProviderScope(
          overrides: [
            assistantFinancialContextServiceProvider.overrideWithValue(service),
          ],
          child: Scaffold(
            body: AccountsAwareChatTranscript(
              messages: const [],
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
    await tester.pumpAndSettle();

    expect(find.text(en.chatTranscriptPromptSpendWeek), findsOneWidget);
    expect(find.text(en.chatTranscriptPromptRemember), findsNothing);
  });
}
