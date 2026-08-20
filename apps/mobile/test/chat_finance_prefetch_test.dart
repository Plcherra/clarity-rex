import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_intent.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_service.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';
import 'package:clarity/rex/chat/application/chat_linked_accounts.dart';
import 'package:clarity/rex/presentation/assistant_chat_visible_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialReadModel _model({required bool hasAccount}) {
  return FinancialReadModel.fromRecords(
    accounts: [
      if (hasAccount)
        const Account(
          id: 'checking',
          name: 'Checking',
          type: AccountType.checking,
          currentBalance: 100,
        ),
    ],
    transactionRecords: const [],
    budgets: const [],
  );
}

AssistantFinancialContextService _service({
  required FinancialReadModel model,
  required List<int> loads,
}) {
  return AssistantFinancialContextService(
    loadFinancialReadModel: () async {
      loads.add(1);
      return model;
    },
    spendReference: () => DateTime(2026, 8, 20),
    notifyDataChanged: () {},
  );
}

void main() {
  test('prefetch loads once and warms the next money-turn summary', () async {
    final loads = <int>[];
    final service = _service(model: _model(hasAccount: true), loads: loads);

    await service.prefetchSessionSummary();
    await service.prefetchSessionSummary();
    await service.buildSummary(userMessage: 'How much did I spend this week?');

    expect(service.sessionPrefetchCount, 1);
    expect(loads, hasLength(1));
    expect(
      shouldAttachAssistantFinancialContext('How much did I spend this week?'),
      isTrue,
    );
    expect(shouldAttachAssistantFinancialContext('hey'), isFalse);
  });

  test('notifyDataChanged allows a later prefetch after finance writes', () async {
    final loads = <int>[];
    final service = _service(model: _model(hasAccount: true), loads: loads);

    await service.prefetchSessionSummary();
    service.notifyDataChanged();
    await service.prefetchSessionSummary();

    expect(service.sessionPrefetchCount, 2);
    expect(loads, hasLength(2));
  });

  test('visible chat with accounts prefetches once', () async {
    final loads = <int>[];
    final service = _service(model: _model(hasAccount: true), loads: loads);
    final container = ProviderContainer(
      overrides: [
        assistantFinancialContextServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatFinancePrefetchProvider.future);
    await container.read(chatFinancePrefetchProvider.future);

    expect(service.sessionPrefetchCount, 1);
    expect(loads, isNotEmpty);
  });

  test('visible chat with no accounts does not prefetch', () async {
    final loads = <int>[];
    final service = _service(model: _model(hasAccount: false), loads: loads);
    final container = ProviderContainer(
      overrides: [
        assistantFinancialContextServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatFinancePrefetchProvider.future);

    expect(service.sessionPrefetchCount, 0);
  });

  test('hasLinkedAccounts retries after a failed load', () async {
    var attempts = 0;
    final service = AssistantFinancialContextService(
      loadFinancialReadModel: () async {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('cold start');
        }
        return _model(hasAccount: true);
      },
      spendReference: () => DateTime(2026, 8, 20),
      notifyDataChanged: () {},
    );

    expect(await service.hasLinkedAccounts(), isTrue);
    expect(attempts, 2);
    expect(service.hasCachedLinkedAccounts, isTrue);
  });

  test('hidden chat does not prefetch', () async {
    final loads = <int>[];
    final service = _service(model: _model(hasAccount: true), loads: loads);
    final container = ProviderContainer(
      overrides: [
        assistantFinancialContextServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    container.read(assistantChatVisibleProvider.notifier).setVisible(false);
    await container.read(chatFinancePrefetchProvider.future);

    expect(service.sessionPrefetchCount, 0);
    expect(loads, isEmpty);
  });
}
