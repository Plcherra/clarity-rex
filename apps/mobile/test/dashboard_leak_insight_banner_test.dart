import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/models/models.dart';
import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/application/dashboard_deep_link_navigation.dart';
import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/dashboard/presentation/dashboard_leak_insight_banner.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardSnapshot _snapshot({required List<CategoryLeakStat> leaks}) {
  return DashboardSnapshot(
    totalBalance: 1000,
    spentThisMonth: 500,
    incomeThisMonth: 300,
    availableThisMonth: -200,
    topCategories: const [],
    biggestLeaksThisMonth: leaks,
    burnRunwayDays: 10,
    monthlyGroups: const [],
    referenceMonth: DateTime(2026, 7),
  );
}

const _budgetPerformance = BudgetPerformanceSnapshot(
  periodType: BudgetPeriodType.monthly,
  periodKey: '2026-07',
  periodLabel: 'July 2026',
  totalBudgeted: 0,
  totalSpent: 0,
  budgetedCategoryCount: 0,
  onTrackCategoryCount: 0,
  totalOverspent: 0,
  topOverspendingCategories: [],
);

const _risingLeak = CategoryLeakStat(
  name: 'Dining',
  amountThisMonth: 120,
  amountLastMonth: 60,
  percentChangeFromLastMonth: 1.0,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<CategoryLeakStat> leaks,
  required bool hasAccounts,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DashboardLeakInsightBanner(
            snapshot: _snapshot(leaks: leaks),
            budgetPerformance: _budgetPerformance,
            hasAccounts: hasAccounts,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('shows the leak sentence when a rising leak exists and accounts exist', (
    tester,
  ) async {
    await _pump(tester, leaks: const [_risingLeak], hasAccounts: true);

    final expectedBody = l10n.dashboardInsightsMomLeakUp(
      'Dining',
      formatPercent(1.0),
      formatMoney(120),
    );
    expect(find.text(l10n.dashboardInsightsStripTitle), findsOneWidget);
    expect(find.text(expectedBody), findsOneWidget);
  });

  testWidgets('renders nothing on a quiet month with no leak', (tester) async {
    await _pump(tester, leaks: const [], hasAccounts: true);

    expect(find.text(l10n.dashboardInsightsStripTitle), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders nothing before any account is linked', (tester) async {
    await _pump(tester, leaks: const [_risingLeak], hasAccounts: false);

    expect(find.text(l10n.dashboardInsightsStripTitle), findsNothing);
  });

  testWidgets('tap requests the spending-pressure dashboard anchor', (
    tester,
  ) async {
    await _pump(tester, leaks: const [_risingLeak], hasAccounts: true);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardLeakInsightBanner)),
    );
    expect(container.read(dashboardDeepLinkRequestProvider), isNull);

    await tester.tap(find.text(l10n.dashboardInsightsStripTitle));
    await tester.pumpAndSettle();

    final request = container.read(dashboardDeepLinkRequestProvider);
    expect(request, isNotNull);
    expect(request!.anchor, DashboardInsightAnchor.spendingPressure);
  });
}
