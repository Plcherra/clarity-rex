import 'dart:convert';

import 'package:clarity/features/finance/application/assistant_financial_context_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capAssistantFinancialContextSize leaves small packs unchanged', () {
    final context = <String, dynamic>{
      'schema': 'clarity_unified_financial_context_v1',
      'cash_flow': {'total_balance': 10},
    };
    final capped = capAssistantFinancialContextSize(context);
    expect(identical(capped, context) || capped['cash_flow'] != null, isTrue);
    expect(capped['integration'], isNull);
  });

  test('capAssistantFinancialContextSize shrinks oversized packs under API cap', () {
    final hugeTransactions = [
      for (var i = 0; i < 200; i++)
        {
          'id': 'tx-$i',
          'description': 'Merchant name with padding ${'x' * 80} $i',
          'amount': 12.34 + i,
          'date': '2026-07-01',
          'category': 'Subscriptions',
          'account_name': 'Capital One Credit Card • 1410',
        },
    ];
    final context = <String, dynamic>{
      'schema': 'clarity_unified_financial_context_v1',
      'generated_at': '2026-07-29T02:00:00.000Z',
      'integration': {
        'full_financial_context_included': true,
        'drilldown_indexes_included': true,
      },
      'transaction_slices': {
        for (var i = 0; i < 40; i++)
          'slice-$i': {
            'sample_transactions': [
              for (var j = 0; j < 8; j++) 'id-$i-$j-${'y' * 40}',
            ],
          },
      },
      'transactions': hugeTransactions,
      'matched_transactions': hugeTransactions.take(40).toList(),
      'accounts': [
        {'id': 'a1', 'name': 'Checking', 'current_balance': 100},
      ],
      'cash_flow': {'total_balance': 100},
      'period': {'included_transaction_count': hugeTransactions.length},
    };

    expect(
      jsonEncode(context).length,
      greaterThan(kAssistantFinancialContextMaxChars),
    );

    final capped = capAssistantFinancialContextSize(context);
    expect(
      jsonEncode(capped).length,
      lessThanOrEqualTo(kAssistantFinancialContextMaxChars),
    );
    expect(capped['integration'], isA<Map>());
    expect((capped['integration'] as Map)['size_capped'], isTrue);
    expect(capped['accounts'], isNotEmpty);
  });

  test('capping keeps period totals and asked-about rows over recent rows', () {
    final padding = 'x' * 120;
    List<Map<String, dynamic>> rows(String prefix, int count) => [
      for (var i = 0; i < count; i++)
        {
          'id': '$prefix-$i',
          'description': 'CHECKCARD 0$i TST* BOM DOUGH $padding',
          'amount': 4.14,
          'date': '2026-07-0${i % 9}',
          'category_name': 'Coffee / Quick Food',
        },
    ];
    final context = <String, dynamic>{
      'schema': 'clarity_unified_financial_context_v1',
      'integration': {'full_financial_context_included': true},
      'transactions': rows('recent', 120),
      'matched_transactions': rows('coffee', 40),
      'category_spend_this_month': [
        {
          'category': 'Coffee / Quick Food',
          'spent': 214.8,
          'transaction_count': 41,
          'top_merchants': [
            {'merchant': 'Bom Dough', 'spent': 118.6, 'transaction_count': 29},
          ],
        },
      ],
      'cash_flow': {'total_balance': 100},
      'period': {'transaction_count': 183, 'included_transaction_count': 120},
    };

    expect(
      jsonEncode(context).length,
      greaterThan(kAssistantFinancialContextMaxChars),
    );

    final capped = capAssistantFinancialContextSize(context);
    expect(
      jsonEncode(capped).length,
      lessThanOrEqualTo(kAssistantFinancialContextMaxChars),
    );
    // Rex answers amounts from these, so they outlive background recent rows.
    expect(capped['category_spend_this_month'], isNotEmpty);
    expect((capped['matched_transactions'] as List), hasLength(40));
    expect((capped['transactions'] as List).length, lessThan(120));
  });

  test('summary-only fallback still carries the period category totals', () {
    final context = <String, dynamic>{
      'schema': 'clarity_unified_financial_context_v1',
      'integration': {'full_financial_context_included': true},
      'accounts': [
        {'id': 'a1', 'name': 'Checking', 'current_balance': 100},
      ],
      'cash_flow': {'total_balance': 100},
      'category_spend_this_month': [
        {'category': 'Coffee / Quick Food', 'spent': 214.8},
      ],
      'matched_transactions': [
        for (var i = 0; i < 400; i++)
          {'id': 'm-$i', 'description': 'padded row ${'z' * 200}'},
      ],
    };

    final capped = capAssistantFinancialContextSize(context);
    expect(
      jsonEncode(capped).length,
      lessThanOrEqualTo(kAssistantFinancialContextMaxChars),
    );
    expect(capped['category_spend_this_month'], isNotEmpty);
  });
}
