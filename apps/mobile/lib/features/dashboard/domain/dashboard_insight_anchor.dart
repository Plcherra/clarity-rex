/// Stable scroll targets for dashboard insight sections and Rex deep links.
enum DashboardInsightAnchor {
  monthlyCashFlow,
  spendingPressure,
  budgetPerformance,
}

const dashboardInsightAnchorRouteValues = {
  DashboardInsightAnchor.monthlyCashFlow: 'monthly_cash_flow',
  DashboardInsightAnchor.spendingPressure: 'spending_pressure',
  DashboardInsightAnchor.budgetPerformance: 'budget_performance',
};

DashboardInsightAnchor? dashboardInsightAnchorFromRouteValue(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  for (final entry in dashboardInsightAnchorRouteValues.entries) {
    if (entry.value == normalized) {
      return entry.key;
    }
  }
  return null;
}

String dashboardInsightAnchorRouteValue(DashboardInsightAnchor anchor) {
  return dashboardInsightAnchorRouteValues[anchor]!;
}
