import 'package:clarity/features/dashboard/application/dashboard_deep_link_navigation.dart';
import 'package:clarity/features/dashboard/domain/dashboard_insight_anchor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDashboardInsightAnchor', () {
    test('maps budget questions to budget performance', () {
      expect(
        resolveDashboardInsightAnchor('Which budget categories are over?'),
        DashboardInsightAnchor.budgetPerformance,
      );
    });

    test('maps spending pressure questions to spending analysis', () {
      expect(
        resolveDashboardInsightAnchor('What are my biggest spending leaks?'),
        DashboardInsightAnchor.spendingPressure,
      );
    });

    test('maps generic finance questions to monthly cash flow', () {
      expect(
        resolveDashboardInsightAnchor('How much did I spend this month?'),
        DashboardInsightAnchor.monthlyCashFlow,
      );
    });

    test('connected accounts anchor opens accounts tab', () {
      expect(
        dashboardDeepLinkOpensAccounts(
          DashboardInsightAnchor.connectedAccounts,
        ),
        isTrue,
      );
      expect(
        dashboardDeepLinkOpensAccounts(
          DashboardInsightAnchor.monthlyCashFlow,
        ),
        isFalse,
      );
    });
  });

  group('dashboardInsightAnchor route values', () {
    test('round trips stable route keys', () {
      for (final anchor in DashboardInsightAnchor.values) {
        final routeValue = dashboardInsightAnchorRouteValue(anchor);
        expect(
          dashboardInsightAnchorFromRouteValue(routeValue),
          anchor,
        );
      }
    });
  });
}
