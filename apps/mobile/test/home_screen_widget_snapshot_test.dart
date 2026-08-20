import 'package:clarity/app/ui_dependencies.dart';
import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/application/home_screen_widget_publisher.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/dashboard/domain/home_screen_widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardViewData _viewData({
  required double cash,
  required double left,
  required int accountCount,
}) {
  return DashboardViewData(
    snapshot: DashboardSnapshot(
      totalBalance: cash,
      cashTotal: cash,
      spentThisMonth: 0,
      incomeThisMonth: 0,
      availableThisMonth: left,
      topCategories: const [],
      biggestLeaksThisMonth: const [],
      burnRunwayDays: null,
      monthlyGroups: const [],
      referenceMonth: DateTime(2026, 8),
    ),
    budgetPerformance: const BudgetPerformanceSnapshot(
      periodType: BudgetPeriodType.monthly,
      periodKey: '2026-08',
      periodLabel: 'August 2026',
      totalBudgeted: 0,
      totalSpent: 0,
      budgetedCategoryCount: 0,
      onTrackCategoryCount: 0,
      totalOverspent: 0,
      topOverspendingCategories: [],
    ),
    scopedTransactionCount: 0,
    totalTransactionCount: 0,
    accountCount: accountCount,
    scopedStatementImportCount: 0,
    totalStatementImportCount: 0,
    loadIssues: const [],
  );
}

void main() {
  final l10n = lookupEnglishLocalizationsForTests();

  test('overview URI is the custom scheme host', () {
    expect(
      HomeScreenWidgetSnapshot.isOverviewUri(
        Uri.parse('io.goclarity.clarity://overview'),
      ),
      isTrue,
    );
    expect(
      HomeScreenWidgetSnapshot.isOverviewUri(
        Uri.parse('io.goclarity.clarity://login-callback'),
      ),
      isFalse,
    );
  });

  test('payload uses cash and left this month, never tokens', () {
    final snapshot = buildHomeScreenWidgetSnapshot(
      data: _viewData(cash: 246.58, left: 89.1, accountCount: 2),
      l10n: l10n,
    );
    final fields = snapshot.toAppGroupFields();

    expect(snapshot.hasAccounts, isTrue);
    expect(snapshot.leftNegative, isFalse);
    expect(fields[HomeScreenWidgetSnapshot.keyCashLabel], l10n.dashboardOverviewCashTotal);
    expect(fields[HomeScreenWidgetSnapshot.keyLeftLabel], l10n.dashboardOverviewLeftThisMonth);
    expect(fields[HomeScreenWidgetSnapshot.keyCashValue], formatMoney(246.58));
    expect(fields[HomeScreenWidgetSnapshot.keyLeftValue], formatMoney(89.1));
    expect(fields[HomeScreenWidgetSnapshot.keyHasAccounts], '1');
    expect(fields.values.join(), isNot(contains('access')));
    expect(fields.values.join(), isNot(contains('token')));
  });

  test('negative leftover is flagged and empty accounts hide amounts', () {
    final negative = buildHomeScreenWidgetSnapshot(
      data: _viewData(cash: 10, left: -40, accountCount: 1),
      l10n: l10n,
    );
    expect(negative.leftNegative, isTrue);
    expect(negative.toAppGroupFields()[HomeScreenWidgetSnapshot.keyLeftNegative], '1');

    final empty = buildHomeScreenWidgetSnapshot(
      data: _viewData(cash: 0, left: 0, accountCount: 0),
      l10n: l10n,
    );
    expect(empty.hasAccounts, isFalse);
    expect(empty.emptyMessage, l10n.homeScreenWidgetEmpty);
  });
}
