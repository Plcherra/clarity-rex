import 'package:clarity/app/ui_dependencies.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connected accounts are not treated as empty before first sync', () {
    final data = DashboardViewData(
      snapshot: DashboardSnapshot(
        totalBalance: 0,
        spentThisMonth: 0,
        incomeThisMonth: 0,
        availableThisMonth: 0,
        topCategories: const [],
        biggestLeaksThisMonth: const [],
        burnRunwayDays: null,
        monthlyGroups: const [],
        referenceMonth: DateTime(2026, 6),
      ),
      budgetPerformance: const BudgetPerformanceSnapshot(
        periodType: BudgetPeriodType.monthly,
        periodKey: '2026-06',
        periodLabel: 'June 2026',
        totalBudgeted: 0,
        totalSpent: 0,
        budgetedCategoryCount: 0,
        onTrackCategoryCount: 0,
        totalOverspent: 0,
        topOverspendingCategories: [],
      ),
      scopedTransactionCount: 0,
      totalTransactionCount: 0,
      accountCount: 2,
      scopedStatementImportCount: 0,
      totalStatementImportCount: 0,
      loadIssues: const [],
    );

    expect(data.isTrulyEmpty, isFalse);
  });
}
