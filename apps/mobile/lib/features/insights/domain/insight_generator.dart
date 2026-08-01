import '../../../core/formatting/formatting.dart';
import '../../../core/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../budgets/domain/budget_models.dart';
import '../../dashboard/domain/dashboard_insight_anchor.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import 'insight_item.dart';

List<InsightItem> generateDashboardInsightItems({
  required AppLocalizations l10n,
  required DashboardSnapshot snapshot,
  required BudgetPerformanceSnapshot budgetPerformance,
}) {
  final periodKey = budgetPerformance.periodKey;
  final items = <InsightItem>[];

  // Net cash flow is already shown in the overview card above the strip.
  final leakItem = _momLeakInsight(l10n, snapshot.biggestLeaksThisMonth, periodKey);
  if (leakItem != null) items.add(leakItem);

  final budgetItem = _budgetOverspendInsight(l10n, budgetPerformance);
  if (budgetItem != null) items.add(budgetItem);

  return items.length <= 3 ? items : items.sublist(0, 3);
}

InsightItem? _momLeakInsight(
  AppLocalizations l10n,
  List<CategoryLeakStat> leaks,
  String periodKey,
) {
  final leak = _topMomLeak(leaks);
  if (leak == null || leak.amountThisMonth <= 0) return null;

  final pct = leak.percentChangeFromLastMonth;
  final String body;
  if (pct == null) {
    body = l10n.dashboardInsightsMomLeakNew(
      leak.name,
      formatMoney(leak.amountThisMonth),
    );
  } else {
    if (pct <= 0) return null;
    body = l10n.dashboardInsightsMomLeakUp(
      leak.name,
      formatPercent(pct),
      formatMoney(leak.amountThisMonth),
    );
  }

  return InsightItem(
    fingerprint: buildInsightFingerprint(
      source: InsightSource.dashboardSnapshot,
      type: InsightType.momLeak,
      periodKey: periodKey,
      detailKey: leak.name.toLowerCase(),
    ),
    source: InsightSource.dashboardSnapshot,
    type: InsightType.momLeak,
    title: l10n.dashboardInsightsStripTitle,
    body: body,
    periodKey: periodKey,
    anchor: DashboardInsightAnchor.spendingPressure,
  );
}

CategoryLeakStat? _topMomLeak(List<CategoryLeakStat> leaks) {
  if (leaks.isEmpty) return null;

  CategoryLeakStat? best;
  for (final leak in leaks) {
    if (leak.amountThisMonth <= 0) continue;
    if (best == null) {
      best = leak;
      continue;
    }
    final bestScore = _momLeakScore(best);
    final leakScore = _momLeakScore(leak);
    if (leakScore > bestScore) best = leak;
  }
  return best ?? leaks.first;
}

double _momLeakScore(CategoryLeakStat leak) {
  final pct = leak.percentChangeFromLastMonth;
  if (pct == null) return double.infinity;
  return pct;
}

InsightItem? _budgetOverspendInsight(
  AppLocalizations l10n,
  BudgetPerformanceSnapshot budgetPerformance,
) {
  final top = budgetPerformance.topOverspendingCategories.firstOrNull;
  if (top == null || top.overspent <= 0) return null;

  final body = l10n.dashboardInsightsBudgetOver(
    top.displayLabel,
    formatMoney(top.overspent),
  );
  return InsightItem(
    fingerprint: buildInsightFingerprint(
      source: InsightSource.dashboardSnapshot,
      type: InsightType.budgetOverspend,
      periodKey: budgetPerformance.periodKey,
      detailKey: top.displayLabel.toLowerCase(),
    ),
    source: InsightSource.dashboardSnapshot,
    type: InsightType.budgetOverspend,
    title: l10n.dashboardInsightsStripTitle,
    body: body,
    periodKey: budgetPerformance.periodKey,
    anchor: DashboardInsightAnchor.budgetPerformance,
  );
}

