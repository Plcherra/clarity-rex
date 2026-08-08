import 'package:clarity/features/finance/data/financial_audit_service.dart';
import 'package:clarity/features/finance/presentation/financial_audit_display.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final es = lookupAppLocalizations(const Locale('es'));

  FinancialAuditEvent event({
    required String eventType,
    Map<String, dynamic> previousValue = const {},
    Map<String, dynamic> newValue = const {},
    Map<String, dynamic> metadata = const {},
    String source = 'app',
    DateTime? createdAt,
  }) {
    return FinancialAuditEvent(
      id: 'evt-1',
      userId: 'user-1',
      eventType: eventType,
      entityType: 'category',
      source: source,
      previousValue: previousValue,
      newValue: newValue,
      metadata: metadata,
      createdAt: createdAt ?? DateTime.utc(2026, 8, 7, 15, 30),
    );
  }

  test('titles cover category, merchant, and budget event types', () {
    expect(
      financialAuditEventTitle(
        event(eventType: 'transaction_category_updated'),
        l10n,
      ),
      l10n.categorySheetAuditTransactionCategoryChanged,
    );
    expect(
      financialAuditEventTitle(
        event(eventType: 'merchant_rule_category_updated'),
        l10n,
      ),
      l10n.categorySheetAuditMerchantRuleChanged,
    );
    expect(
      financialAuditEventTitle(event(eventType: 'budget_created'), l10n),
      l10n.financialAuditBudgetCreated,
    );
    expect(
      financialAuditEventTitle(event(eventType: 'budget_updated'), l10n),
      l10n.financialAuditBudgetUpdated,
    );
    expect(
      financialAuditEventTitle(event(eventType: 'budget_deleted'), l10n),
      l10n.financialAuditBudgetDeleted,
    );
  });

  test('subtitle includes value delta, count, source, and timestamp', () {
    final subtitle = financialAuditEventSubtitle(
      event(
        eventType: 'transaction_category_updated',
        previousValue: const {'category_name': 'Food'},
        newValue: const {'category_name': 'Groceries'},
        metadata: const {'transaction_count': 3},
        source: 'app',
      ),
      l10n,
    );
    expect(subtitle, contains('Food -> Groceries'));
    expect(subtitle, contains(l10n.commonTransactionCount(3)));
    expect(subtitle, contains('app'));
    expect(subtitle, contains('2026-08-07'));
  });

  test('Spanish titles resolve for budget events', () {
    expect(
      financialAuditEventTitle(event(eventType: 'budget_created'), es),
      es.financialAuditBudgetCreated,
    );
  });

  test('unknown event types fall back to readable text', () {
    expect(
      financialAuditEventTitle(event(eventType: 'custom_future_event'), l10n),
      'custom future event',
    );
  });
}
