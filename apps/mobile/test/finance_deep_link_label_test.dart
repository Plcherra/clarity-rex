import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:clarity/rex/chat/application/finance_deep_link_label.dart';

void main() {
  const coffeeContext = {
    'top_spending_categories': [
      {'category': 'Miscellaneous', 'spent': '\$159'},
      {'category': 'Coffee / Quick Food', 'spent': '\$47.47'},
      {'category': 'Transportation', 'spent': '\$31.15'},
    ],
  };

  test('matches coffee token to Coffee / Quick Food', () {
    final label = financeDeepLinkCategoryLabel(
      anchor: DashboardInsightAnchor.monthlyCashFlow,
      userMessage: 'How much did i spent with coffee around this month already',
      financialContext: coffeeContext,
    );
    expect(label, 'Coffee / Quick Food');
  });

  test('prefers category mentioned in the user message', () {
    final label = financeDeepLinkCategoryLabel(
      anchor: DashboardInsightAnchor.monthlyCashFlow,
      userMessage: 'How much did I spend on Food & Drink?',
      financialContext: {
        'top_spending_categories': [
          {'category': 'Miscellaneous', 'spent': '\$120'},
          {'category': 'Food & Drink', 'spent': '\$80'},
        ],
      },
    );
    expect(label, 'Food & Drink');
  });

  test('uses assistant reply when user wording is vague', () {
    final label = financeDeepLinkCategoryLabel(
      anchor: DashboardInsightAnchor.spendingPressure,
      userMessage: 'where is my money going',
      assistantReply:
          'This month the Coffee / Quick Food category shows \$47.47 spent.',
      financialContext: coffeeContext,
    );
    expect(label, 'Coffee / Quick Food');
  });

  test('falls back to top spending category for vague spend questions', () {
    final label = financeDeepLinkCategoryLabel(
      anchor: DashboardInsightAnchor.spendingPressure,
      userMessage: 'Where is my spending going?',
      financialContext: coffeeContext,
    );
    expect(label, 'Miscellaneous');
  });

  test('connected accounts has no category label', () {
    final label = financeDeepLinkCategoryLabel(
      anchor: DashboardInsightAnchor.connectedAccounts,
      userMessage: 'Refresh my banks',
      financialContext: coffeeContext,
    );
    expect(label, isNull);
  });
}
