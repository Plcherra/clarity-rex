import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/category_month_detail.dart';
import 'package:clarity/features/dashboard/presentation/category_detail_insights.dart';
import 'package:clarity/features/transactions/domain/merchant_rollup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  group('category detail insights', () {
    testWidgets('the summary reads as money, not raw doubles', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: CategoryDetailSummaryCard(
              detail: _detail(spent: 182.4499999, lastMonthSpent: 91.22),
              budget: null,
            ),
          ),
        ),
      );

      expect(find.text('\$182.45'), findsOneWidget);
      expect(find.text('4 transactions'), findsOneWidget);
      expect(find.text('Up \$91.23 (100%) vs last month'), findsOneWidget);
      expect(
        find.text('25% of everything you spent this month'),
        findsOneWidget,
      );
      expect(find.text('\$45.61 per transaction on average'), findsOneWidget);
    });

    testWidgets('a category with no history last month says it is new', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: CategoryDetailSummaryCard(
              detail: _detail(spent: 60, lastMonthSpent: 0),
              budget: null,
            ),
          ),
        ),
      );

      expect(
        find.text('New this month — nothing here last month'),
        findsOneWidget,
      );
    });

    testWidgets('an overspent budget is called out', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: CategoryDetailSummaryCard(
              detail: _detail(spent: 182.45, lastMonthSpent: 91.22),
              budget: const BudgetCategoryPerformance(
                displayLabel: 'Coffee / Quick Food',
                budgeted: 100,
                spent: 182.45,
              ),
            ),
          ),
        ),
      );

      expect(find.text('\$82.45 over the \$100.00 budget'), findsOneWidget);
    });

    testWidgets('the merchant split shows who took the money', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: CategoryDetailMerchants(
              detail: _detail(spent: 182.45, lastMonthSpent: 0),
            ),
          ),
        ),
      );

      expect(find.text('Where it went'), findsOneWidget);
      expect(find.text('Wingstop'), findsOneWidget);
      expect(find.text('Bom Dough Coffee'), findsOneWidget);
      expect(find.text('3 transactions'), findsOneWidget);
      expect(find.text('\$18.25'), findsOneWidget);
    });

    testWidgets('one merchant needs no breakdown', (tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: CategoryDetailMerchants(
              detail: CategoryMonthDetail(
                category: 'Coffee / Quick Food',
                spent: 18.25,
                lastMonthSpent: 0,
                transactionCount: 3,
                shareOfMonthSpend: 0.1,
                merchants: const [
                  MerchantSpendRollup(
                    merchant: 'Bom Dough Coffee',
                    spent: 18.25,
                    transactionCount: 3,
                  ),
                ],
                transactions: const [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Where it went'), findsNothing);
    });
  });
}

CategoryMonthDetail _detail({
  required double spent,
  required double lastMonthSpent,
}) {
  return CategoryMonthDetail(
    category: 'Coffee / Quick Food',
    spent: spent,
    lastMonthSpent: lastMonthSpent,
    transactionCount: 4,
    shareOfMonthSpend: 0.25,
    merchants: const [
      MerchantSpendRollup(
        merchant: 'Wingstop',
        spent: 24.80,
        transactionCount: 1,
      ),
      MerchantSpendRollup(
        merchant: 'Bom Dough Coffee',
        spent: 18.25,
        transactionCount: 3,
      ),
    ],
    transactions: const [],
  );
}
