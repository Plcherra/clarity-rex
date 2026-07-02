part of 'financial_dashboard_view.dart';

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
  return generateDashboardInsightItems(
    l10n: l10n,
    snapshot: snapshot,
    budgetPerformance: budgetPerformance,
  )
      .map(
        (item) => DashboardInsightItem(
          message: item.body,
          anchor: item.anchor ?? DashboardInsightAnchor.monthlyCashFlow,
        ),
      )
      .toList();
}

class _DashboardInsightsStrip extends StatelessWidget {
  const _DashboardInsightsStrip({
    required this.items,
    required this.onSeeChart,
    this.onSeeAllInsights,
  });

  final List<DashboardInsightItem> items;
  final ValueChanged<DashboardInsightAnchor> onSeeChart;
  final VoidCallback? onSeeAllInsights;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.dashboardInsightsStripTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: cs.onSurface.withValues(alpha: 0.82),
                ),
              ),
            ),
            if (onSeeAllInsights != null)
              TextButton(
                onPressed: onSeeAllInsights,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.insightsSeeAll),
              ),
          ],
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
