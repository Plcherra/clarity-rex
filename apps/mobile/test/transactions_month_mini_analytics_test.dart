import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/dashboard/domain/monthly_cash_flow_series.dart';
import 'package:clarity/features/transactions/presentation/widgets/transactions_month_mini_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('mini analytics shows dashboard snapshot totals', (tester) async {
    const snapshot = DashboardSnapshot(
      totalBalance: 1200,
      spentThisMonth: 420,
      incomeThisMonth: 3000,
      availableThisMonth: 2580,
      topCategories: [
        CategorySpend(name: 'Groceries', amount: 180),
        CategorySpend(name: 'Dining', amount: 95),
      ],
      biggestLeaksThisMonth: [],
      burnRunwayDays: 12,
      monthlyGroups: [],
    );

    await tester.pumpWidget(
      wrapWithL10n(
        const TransactionsMonthMiniAnalytics(snapshot: snapshot),
      ),
    );

    expect(find.text('This month at a glance'), findsOneWidget);
    expect(find.text('\$420.00'), findsOneWidget);
    expect(find.text('\$3,000.00'), findsOneWidget);
    expect(find.text('\$2,580.00'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
  });

  testWidgets('mini analytics hides when snapshot has no activity', (
    tester,
  ) async {
    const snapshot = DashboardSnapshot(
      totalBalance: 0,
      spentThisMonth: 0,
      incomeThisMonth: 0,
      availableThisMonth: 0,
      topCategories: [],
      biggestLeaksThisMonth: [],
      burnRunwayDays: null,
      monthlyGroups: [],
    );

    await tester.pumpWidget(
      wrapWithL10n(
        const TransactionsMonthMiniAnalytics(snapshot: snapshot),
      ),
    );

    expect(find.text('This month at a glance'), findsNothing);
  });

  testWidgets('mini analytics sparkline uses the cash flow series', (
    tester,
  ) async {
    const snapshot = DashboardSnapshot(
      totalBalance: 500,
      spentThisMonth: 300,
      incomeThisMonth: 1000,
      availableThisMonth: 700,
      topCategories: [CategorySpend(name: 'Shopping', amount: 300)],
      biggestLeaksThisMonth: [],
      burnRunwayDays: 5,
      monthlyGroups: [],
      monthlyCashFlow: [
        MonthlyCashFlowPoint(yearMonth: '2026-01', income: 900, spend: 100),
        MonthlyCashFlowPoint(yearMonth: '2026-02', income: 900, spend: 200),
        MonthlyCashFlowPoint(yearMonth: '2026-03', income: 1000, spend: 300),
      ],
    );

    await tester.pumpWidget(
      wrapWithL10n(
        TransactionsMonthMiniAnalytics(snapshot: snapshot),
      ),
    );

    expect(find.text('Six-month spend trend'), findsOneWidget);
  });
}
