import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/category_month_detail.dart';
import 'package:clarity/features/dashboard/presentation/category_detail_insights.dart';
import 'package:clarity/features/dashboard/presentation/category_detail_merchants.dart';
import 'package:clarity/features/transactions/domain/merchant_rollup.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';
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
      await tester.pumpWidget(_merchants(_detail()));

      expect(find.text('Where it went'), findsOneWidget);
      expect(find.text('Wingstop'), findsOneWidget);
      expect(find.text('Bom Dough Coffee'), findsOneWidget);
      expect(find.text('3 transactions'), findsOneWidget);
      expect(find.text('\$18.25'), findsOneWidget);
    });

    testWidgets('transactions stay folded until a place is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(_merchants(_detail()));

      expect(find.text('BOM DOUGH 07/14'), findsNothing);

      await tester.tap(find.text('Bom Dough Coffee'));
      await tester.pumpAndSettle();

      expect(find.text('BOM DOUGH 07/14'), findsOneWidget);
      expect(find.text('BOM DOUGH 07/15'), findsOneWidget);
      // Opening one place leaves the others alone.
      expect(find.text('WINGSTOP 07/12'), findsNothing);

      await tester.tap(find.text('Bom Dough Coffee'));
      await tester.pumpAndSettle();

      expect(find.text('BOM DOUGH 07/14'), findsNothing);
    });

    testWidgets('a single merchant is still openable', (tester) async {
      await tester.pumpWidget(
        _merchants(
          CategoryMonthDetail(
            category: 'Coffee / Quick Food',
            spent: 18.25,
            lastMonthSpent: 0,
            transactionCount: 1,
            shareOfMonthSpend: 0.1,
            merchants: [
              MerchantSpendRollup(
                merchant: 'Bom Dough Coffee',
                spent: 6.25,
                transactionCount: 1,
                transactions: [_row('BOM DOUGH 07/14', 6.25, 14)],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Where it went'), findsOneWidget);

      await tester.tap(find.text('Bom Dough Coffee'));
      await tester.pumpAndSettle();

      expect(find.text('BOM DOUGH 07/14'), findsOneWidget);
    });
  });
}

Widget _merchants(CategoryMonthDetail detail) {
  return wrapWithL10n(
    Scaffold(
      body: ListView(
        children: [
          CategoryDetailMerchants(
            detail: detail,
            buildTransactionRow: (row) => Text(row.transaction.description),
          ),
        ],
      ),
    ),
  );
}

ResolvedTransaction _row(String description, double amount, int day) {
  return ResolvedTransaction(
    transaction: Transaction(
      date: DateTime(2026, 7, day),
      description: description,
      amount: -amount,
      accountId: 'checking',
      fingerprint: description,
    ),
    canonicalCategory: 'Coffee / Quick Food',
    displayCategory: 'Coffee / Quick Food',
    financialRole: FinancialRole.expense,
    isStatementDataRow: false,
    countsAsSpend: true,
    countsAsIncome: false,
    needsCategorization: false,
  );
}

CategoryMonthDetail _detail({
  double spent = 182.45,
  double lastMonthSpent = 91.22,
}) {
  return CategoryMonthDetail(
    category: 'Coffee / Quick Food',
    spent: spent,
    lastMonthSpent: lastMonthSpent,
    transactionCount: 4,
    shareOfMonthSpend: 0.25,
    merchants: [
      MerchantSpendRollup(
        merchant: 'Wingstop',
        spent: 24.80,
        transactionCount: 1,
        transactions: [_row('WINGSTOP 07/12', 24.80, 12)],
      ),
      MerchantSpendRollup(
        merchant: 'Bom Dough Coffee',
        spent: 18.25,
        transactionCount: 3,
        transactions: [
          _row('BOM DOUGH 07/15', 6.00, 15),
          _row('BOM DOUGH 07/14', 6.25, 14),
          _row('BOM DOUGH 07/13', 6.00, 13),
        ],
      ),
    ],
  );
}
