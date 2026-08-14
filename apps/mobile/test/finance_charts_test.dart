import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/monthly_cash_flow_series.dart';
import 'package:clarity/features/dashboard/presentation/charts/finance_charts.dart';
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

    test('cash flow ranges are 3M, 6M, 9M, and 1Y', () {
      expect(cashFlowChartRanges, [3, 6, 9, 12]);
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
          const MonthlyCashFlowChart(months: []),
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
          MonthlyCashFlowChart(months: _cashFlowMonths(count: 8, spend: 100)),
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

    testWidgets('a touched bar names the month, the side, and the amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          MonthlyCashFlowChart(
            months: _cashFlowMonths(count: 2, spend: 2675.34, income: 1942.53),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltip = chart.data.barTouchData.touchTooltipData;
      final group = chart.data.barGroups.last;

      final income = tooltip.getTooltipItem(group, 1, group.barRods[0], 0);
      final spending = tooltip.getTooltipItem(group, 1, group.barRods[1], 1);

      expect(income?.text, 'February 2025\nIncome \$1,942.53');
      expect(spending?.text, 'February 2025\nSpending \$2,675.34');
    });

    testWidgets('a touched trend point reads as money, not a raw double', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          SpendTrendChart(
            months: _cashFlowMonths(count: 1, spend: 7308.889999999999),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltip = chart.data.lineTouchData.touchTooltipData;
      final items = tooltip.getTooltipItems([
        LineBarSpot(chart.data.lineBarsData.first, 0, const FlSpot(0, 7308.89)),
      ]);

      expect(items.single?.text, 'January 2025\nSpending \$7,308.89');
    });

    testWidgets('SpendTrendChart shows each month label once', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          SpendTrendChart(
            months: _cashFlowMonths(count: 8, spend: 50),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Aug'), findsOneWidget);
    });

    testWidgets('the range switch narrows and widens the months on show', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          MonthlyCashFlowChart(months: _cashFlowMonths(count: 12, spend: 100)),
        ),
      );
      await tester.pumpAndSettle();

      BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
      expect(chart().data.barGroups, hasLength(6));

      await tester.tap(find.text('3M'));
      await tester.pumpAndSettle();
      expect(chart().data.barGroups, hasLength(3));
      expect(find.text('Oct'), findsOneWidget);
      expect(find.text('Jul'), findsNothing);

      await tester.tap(find.text('9M'));
      await tester.pumpAndSettle();
      expect(chart().data.barGroups, hasLength(9));
      expect(find.text('Apr'), findsOneWidget);
      expect(find.text('Mar'), findsNothing);

      await tester.tap(find.text('1Y'));
      await tester.pumpAndSettle();
      expect(chart().data.barGroups, hasLength(12));
      expect(find.text('Jan'), findsOneWidget);
    });

    testWidgets('each chart keeps its own range', (tester) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          ListView(
            children: [
              MonthlyCashFlowChart(
                months: _cashFlowMonths(count: 12, spend: 100),
              ),
              SpendTrendChart(months: _cashFlowMonths(count: 12, spend: 100)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('3M').first);
      await tester.pumpAndSettle();

      final bars = tester.widget<BarChart>(find.byType(BarChart));
      final line = tester.widget<LineChart>(find.byType(LineChart));
      expect(bars.data.barGroups, hasLength(3));
      expect(line.data.lineBarsData.single.spots, hasLength(6));
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

    testWidgets('tapping a category bar opens that category', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        wrapWithClarityTheme(
          CategorySpendChart(
            categories: const [
              CategorySpend(name: 'Grocery / Supermarket', amount: 320),
              CategorySpend(name: 'Shopping', amount: 180),
            ],
            onCategoryTap: tapped.add,
          ),
        ),
      );

      await tester.tap(find.text('Shopping'));

      expect(tapped, ['Shopping']);
    });

    testWidgets('tapping a spending pressure bar opens that category', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        wrapWithClarityTheme(
          BiggestLeaksChart(
            leaks: const [
              CategoryLeakStat(
                name: 'Coffee / Quick Food',
                amountThisMonth: 182,
                amountLastMonth: 90,
                percentChangeFromLastMonth: 1.02,
              ),
            ],
            onCategoryTap: tapped.add,
          ),
        ),
      );

      await tester.tap(find.text('Coffee / Quick Food'));

      expect(tapped, ['Coffee / Quick Food']);
    });

    testWidgets('tapping a budget vs spent row opens that category', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        wrapWithClarityTheme(
          BudgetVsSpentChart(
            performance: _budgetPerformance([
              const BudgetCategoryPerformance(
                displayLabel: 'Grocery / Supermarket',
                budgeted: 400,
                spent: 320,
              ),
              const BudgetCategoryPerformance(
                displayLabel: 'Shopping',
                budgeted: 200,
                spent: 180,
              ),
            ]),
            onCategoryTap: tapped.add,
          ),
        ),
      );

      await tester.tap(find.text('Shopping'));

      expect(tapped, ['Shopping']);
    });

    testWidgets('budget vs spent rows stay flat when there is nowhere to drill', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          BudgetVsSpentChart(
            performance: _budgetPerformance([
              const BudgetCategoryPerformance(
                displayLabel: 'Shopping',
                budgeted: 200,
                spent: 180,
              ),
            ]),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('bars stay flat when there is nowhere to drill into', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const CategorySpendChart(
            categories: [CategorySpend(name: 'Shopping', amount: 180)],
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('category bars and pie stay on screen together', (tester) async {
      await tester.pumpWidget(
        wrapWithClarityTheme(
          const Column(
            children: [
              CategorySpendChart(
                categories: [
                  CategorySpend(name: 'Fitness', amount: 159),
                  CategorySpend(name: 'Transportation', amount: 63.42),
                ],
              ),
              CategorySpendPieChart(
                categories: [
                  CategorySpend(name: 'Fitness', amount: 159),
                  CategorySpend(name: 'Transportation', amount: 63.42),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Fitness'), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.byTooltip('Switch category chart'), findsNothing);
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

List<MonthlyCashFlowPoint> _cashFlowMonths({
  required int count,
  double spend = 0,
  double income = 0,
}) {
  return [
    for (var index = 0; index < count; index++)
      MonthlyCashFlowPoint(
        yearMonth: '2025-${(index + 1).toString().padLeft(2, '0')}',
        income: income,
        spend: spend,
      ),
  ];
}

BudgetPerformanceSnapshot _budgetPerformance(
  List<BudgetCategoryPerformance> categories,
) {
  return BudgetPerformanceSnapshot(
    periodType: BudgetPeriodType.monthly,
    periodKey: '2026-03',
    periodLabel: '2026-03',
    totalBudgeted: 1,
    totalSpent: 1,
    budgetedCategoryCount: categories.length,
    onTrackCategoryCount: categories.length,
    totalOverspent: 0,
    topOverspendingCategories: const [],
    categories: categories,
  );
}
