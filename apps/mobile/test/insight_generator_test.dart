import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_metrics.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/insights/domain/insight_generator.dart';
import 'package:clarity/features/insights/domain/insight_item.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildInsightFingerprint is stable for same inputs', () {
    final first = buildInsightFingerprint(
      source: InsightSource.dashboardSnapshot,
      type: InsightType.netCashFlow,
      periodKey: '2026-07',
      detailKey: 'negative',
    );
    final second = buildInsightFingerprint(
      source: InsightSource.dashboardSnapshot,
      type: InsightType.netCashFlow,
      periodKey: '2026-07',
      detailKey: 'negative',
    );
    expect(first, second);
  });

  test('generateDashboardInsightItems returns empty for inactive month', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final items = generateDashboardInsightItems(
      l10n: l10n,
      snapshot: DashboardSnapshot(
        totalBalance: 0,
        spentThisMonth: 0,
        incomeThisMonth: 0,
        availableThisMonth: 0,
        topCategories: const [],
        biggestLeaksThisMonth: const [],
        burnRunwayDays: null,
        monthlyGroups: const [],
        referenceMonth: DateTime(2026, 7),
      ),
      budgetPerformance: const BudgetPerformanceSnapshot(
        periodType: BudgetPeriodType.monthly,
        periodKey: '2026-07',
        periodLabel: 'July 2026',
        totalBudgeted: 0,
        totalSpent: 0,
        budgetedCategoryCount: 0,
        onTrackCategoryCount: 0,
        totalOverspent: 0,
        topOverspendingCategories: [],
      ),
    );
    expect(items, isEmpty);
  });

  test('generateDashboardInsightItems includes leak and budget items without net duplicate', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final items = generateDashboardInsightItems(
      l10n: l10n,
      snapshot: DashboardSnapshot(
        totalBalance: 1000,
        spentThisMonth: 500,
        incomeThisMonth: 300,
        availableThisMonth: -200,
        topCategories: const [],
        biggestLeaksThisMonth: const [
          CategoryLeakStat(
            name: 'Dining',
            amountThisMonth: 120,
            amountLastMonth: 60,
            percentChangeFromLastMonth: 1.0,
          ),
        ],
        burnRunwayDays: 10,
        monthlyGroups: const [],
        referenceMonth: DateTime(2026, 7),
      ),
      budgetPerformance: const BudgetPerformanceSnapshot(
        periodType: BudgetPeriodType.monthly,
        periodKey: '2026-07',
        periodLabel: 'July 2026',
        totalBudgeted: 400,
        totalSpent: 500,
        budgetedCategoryCount: 1,
        onTrackCategoryCount: 0,
        totalOverspent: 100,
        topOverspendingCategories: [
          BudgetCategoryPerformance(
            displayLabel: 'Dining',
            budgeted: 100,
            spent: 150,
          ),
        ],
      ),
    );

    expect(items, hasLength(2));
    expect(items.map((item) => item.type), [
      InsightType.momLeak,
      InsightType.budgetOverspend,
    ]);
  });
}
