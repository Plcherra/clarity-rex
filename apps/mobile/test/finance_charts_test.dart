import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/presentation/charts/finance_charts.dart';
import 'package:clarity/features/transactions/domain/bank_statement_monthly.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  group('finance chart helpers', () {
    test('trimFinanceChartMonths keeps the most recent six months', () {
      final months = List<String>.generate(8, (index) => '2025-${index + 1}');

      expect(trimFinanceChartMonths(months), ['2025-3', '2025-4', '2025-5', '2025-6', '2025-7', '2025-8']);
    });

    test('financeChartMaxY adds headroom and handles zero values', () {
      expect(financeChartMaxY(const [0, 0]), 1);
      expect(financeChartMaxY(const [100]), closeTo(115, 0.001));
    });
  });

  group('finance chart widgets', () {
    testWidgets('MonthlyCashFlowChart shows empty state message', (tester) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const MonthlyCashFlowChart(monthlyGroups: []),
        ),
      );

      expect(
        find.text('Connect accounts to see monthly cash flow.'),
        findsOneWidget,
      );
    });

    testWidgets('MonthlyCashFlowChart trims to six months and scales maxY', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          MonthlyCashFlowChart(monthlyGroups: _monthlyGroups(count: 8, spend: 100)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jan'), findsNothing);
      expect(find.text('Feb'), findsNothing);
      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Aug'), findsOneWidget);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.maxY, closeTo(115, 0.001));
    });

    testWidgets('BudgetVsSpentChart shows empty state when no categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          BudgetVsSpentChart(
            performance: const BudgetPerformanceSnapshot(
              periodType: BudgetPeriodType.monthly,
              periodKey: '2026-03',
              periodLabel: '2026-03',
              totalBudgeted: 0,
              totalSpent: 0,
              budgetedCategoryCount: 0,
              onTrackCategoryCount: 0,
              totalOverspent: 0,
              topOverspendingCategories: [],
            ),
          ),
        ),
      );

      expect(find.text('No budget categories to chart.'), findsOneWidget);
    });

    testWidgets('empty finance charts use theme muted text color', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const CategorySpendChart(categories: []),
        ),
      );

      final text = tester.widget<Text>(
        find.text('No category spending yet.'),
      );
      expect(text.style?.color, ClarityColors.dark.textMuted);
    });
  });
}

Widget wrapWithClarityTheme(Widget child) {
  return wrapWithL10n(
    Theme(
      data: ThemeData.dark().copyWith(
        extensions: const [ClarityColors.dark],
      ),
      child: Scaffold(body: child),
    ),
  );
}

List<MonthlyBankGroup> _monthlyGroups({
  required int count,
  double spend = 0,
  double income = 0,
}) {
  return [
    for (var index = 0; index < count; index++)
      MonthlyBankGroup(
        yearMonth:
            '2025-${(index + 1).toString().padLeft(2, '0')}',
        totalAmount: income - spend,
        transactions: [
          if (spend > 0)
            BankStatementLine(
              transaction: Transaction(
                accountId: 'checking',
                amount: -spend,
                date: DateTime(2025, index + 1, 15),
                description: 'Spend $index',
                categoryLabel: 'Food',
              ),
              suggestedCategory: 'Food',
            ),
          if (income > 0)
            BankStatementLine(
              transaction: Transaction(
                accountId: 'checking',
                amount: income,
                date: DateTime(2025, index + 1, 1),
                description: 'Income $index',
                categoryLabel: 'Income',
              ),
              suggestedCategory: 'Income',
            ),
        ],
      ),
  ];
}
