part of 'financial_dashboard_view.dart';

class _FinancialOverviewCard extends StatelessWidget {
  const _FinancialOverviewCard({
    required this.snapshot,
    required this.isGlobalScope,
    this.accountCount,
  });

  final DashboardSnapshot snapshot;
  final bool isGlobalScope;
  final int? accountCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline(context)),
        boxShadow: _dashboardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGlobalScope ? 'Total balance' : 'Account balance',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(snapshot.totalBalance),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.02,
                color: _balanceColor(context, snapshot.totalBalance),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isGlobalScope && accountCount != null && accountCount! > 0
                ? 'Across $accountCount connected account${accountCount == 1 ? '' : 's'}'
                : 'From your connected accounts',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.46),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _dashboardPanelMuted(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This month',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CashFlowSummaryMetric(
                          label: 'Income',
                          value: formatMoney(snapshot.incomeThisMonth),
                          color: ClarityColors.financePositive,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CashFlowSummaryMetric(
                          label: 'Spending',
                          value: formatMoney(snapshot.spentThisMonth),
                          color: ClarityColors.financeSpending,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CashFlowSummaryMetric(
                          label: 'Net',
                          value: formatMoney(snapshot.availableThisMonth),
                          color: _balanceColor(
                            context,
                            snapshot.availableThisMonth,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity this month — not the same as balance',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowSummaryMetric extends StatelessWidget {
  const _CashFlowSummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyGroupsList extends StatelessWidget {