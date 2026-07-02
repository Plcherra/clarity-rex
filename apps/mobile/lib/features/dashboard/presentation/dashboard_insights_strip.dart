part of 'financial_dashboard_view.dart';

enum DashboardInsightAnchor {
  monthlyCashFlow,
  spendingPressure,
  budgetPerformance,
}

class DashboardInsightItem {
  const DashboardInsightItem({
    required this.message,
    required this.anchor,
  });

  final String message;
  final DashboardInsightAnchor anchor;
}

List<DashboardInsightItem> buildDashboardInsightItems({
  required AppLocalizations l10n,
  required DashboardSnapshot snapshot,
  required BudgetPerformanceSnapshot budgetPerformance,
}) {
  final items = <DashboardInsightItem>[];

  final netItem = _netCashFlowInsight(l10n, snapshot);
  if (netItem != null) items.add(netItem);

  final leakItem = _momLeakInsight(l10n, snapshot.biggestLeaksThisMonth);
  if (leakItem != null) items.add(leakItem);

  final budgetItem = _budgetOverspendInsight(l10n, budgetPerformance);
  if (budgetItem != null) items.add(budgetItem);

  return items.length <= 3 ? items : items.sublist(0, 3);
}

DashboardInsightItem? _netCashFlowInsight(
  AppLocalizations l10n,
  DashboardSnapshot snapshot,
) {
  if (snapshot.incomeThisMonth <= 0 && snapshot.spentThisMonth <= 0) {
    return null;
  }

  final net = snapshot.availableThisMonth;
  if (net < 0) {
    return DashboardInsightItem(
      message: l10n.dashboardInsightsNetNegative(formatMoney(-net)),
      anchor: DashboardInsightAnchor.monthlyCashFlow,
    );
  }
  if (net > 0) {
    return DashboardInsightItem(
      message: l10n.dashboardInsightsNetPositive(formatMoney(net)),
      anchor: DashboardInsightAnchor.monthlyCashFlow,
    );
  }
  return DashboardInsightItem(
    message: l10n.dashboardInsightsNetBalanced,
    anchor: DashboardInsightAnchor.monthlyCashFlow,
  );
}

DashboardInsightItem? _momLeakInsight(
  AppLocalizations l10n,
  List<CategoryLeakStat> leaks,
) {
  final leak = _topMomLeak(leaks);
  if (leak == null || leak.amountThisMonth <= 0) return null;

  final pct = leak.percentChangeFromLastMonth;
  if (pct == null) {
    return DashboardInsightItem(
      message: l10n.dashboardInsightsMomLeakNew(
        leak.name,
        formatMoney(leak.amountThisMonth),
      ),
      anchor: DashboardInsightAnchor.spendingPressure,
    );
  }
  if (pct <= 0) return null;

  return DashboardInsightItem(
    message: l10n.dashboardInsightsMomLeakUp(
      leak.name,
      _formatPercentChange(pct),
      formatMoney(leak.amountThisMonth),
    ),
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

DashboardInsightItem? _budgetOverspendInsight(
  AppLocalizations l10n,
  BudgetPerformanceSnapshot budgetPerformance,
) {
  final top = budgetPerformance.topOverspendingCategories.firstOrNull;
  if (top == null || top.overspent <= 0) return null;

  return DashboardInsightItem(
    message: l10n.dashboardInsightsBudgetOver(
      top.displayLabel,
      formatMoney(top.overspent),
    ),
    anchor: DashboardInsightAnchor.budgetPerformance,
  );
}

String _formatPercentChange(double fraction) {
  final percent = (fraction * 100).round();
  return '$percent%';
}

class _DashboardInsightsStrip extends StatelessWidget {
  const _DashboardInsightsStrip({
    required this.items,
    required this.onSeeChart,
  });

  final List<DashboardInsightItem> items;
  final ValueChanged<DashboardInsightAnchor> onSeeChart;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashboardInsightsStripTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: cs.onSurface.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _DashboardInsightCard(
            item: items[i],
            onSeeChart: () => onSeeChart(items[i].anchor),
          ),
        ],
      ],
    );
  }
}

class _DashboardInsightCard extends StatelessWidget {
  const _DashboardInsightCard({
    required this.item,
    required this.onSeeChart,
  });

  final DashboardInsightItem item;
  final VoidCallback onSeeChart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onSeeChart,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      l10n.dashboardInsightsSeeChart,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
