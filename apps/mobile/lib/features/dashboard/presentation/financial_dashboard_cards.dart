part of 'financial_dashboard_view.dart';

class _BudgetPerformanceCard extends StatelessWidget {
  const _BudgetPerformanceCard({required this.performance});

  final BudgetPerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (performance.budgetedCategoryCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: _dashboardPanel(context),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: _dashboardOutline(context)),
        ),
        child: Text(
          'No budgets set for ${performance.periodLabel} yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.58),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            performance.periodLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${performance.onTrackCategoryCount}/${performance.budgetedCategoryCount} categories on track',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total overspent ${formatMoney(performance.totalOverspent)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: performance.totalOverspent > 0
                  ? ClarityColors.financeNegative
                  : ClarityColors.financePositive,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Budgeted ${formatMoney(performance.totalBudgeted)} / Spent ${formatMoney(performance.totalSpent)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 14),
          if (performance.topOverspendingCategories.isEmpty)
            Text(
              'No overspending categories in this period.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            )
          else
            for (final row in performance.topOverspendingCategories) ...[
              Text(
                '${row.displayLabel}: overspent ${formatMoney(row.overspent)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ClarityColors.financeNegative,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
        ],
      ),
    );
  }
}

class _AccountHealthCard extends StatelessWidget {
  const _AccountHealthCard({
    required this.snapshot,
    required this.budgetPerformance,
    required this.transactionCount,
  });

  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int transactionCount;

  String get _headline {
    if (snapshot.availableThisMonth < 0) {
      return 'Spending is ahead of income by ${formatMoney(-snapshot.availableThisMonth)} this month.';
    }
    if (snapshot.incomeThisMonth > 0 && snapshot.spentThisMonth > 0) {
      return 'Income is ahead of spending by ${formatMoney(snapshot.availableThisMonth)} this month.';
    }
    if (snapshot.spentThisMonth > 0) {
      return 'Spending is active this month; no income is recorded in this scope.';
    }
    if (snapshot.incomeThisMonth > 0) {
      return 'Income is recorded and no spending has posted for this month yet.';
    }
    if (transactionCount > 0) {
      return 'No current-month activity in this scope yet.';
    }
    return 'Connect transactions to build account health.';
  }

  String get _budgetValue {
    if (budgetPerformance.budgetedCategoryCount == 0) return 'No budgets';
    if (budgetPerformance.totalOverspent > 0) {
      return formatMoney(budgetPerformance.totalOverspent);
    }
    return '${budgetPerformance.onTrackCategoryCount}/${budgetPerformance.budgetedCategoryCount} on track';
  }

  String get _budgetDetail {
    if (budgetPerformance.budgetedCategoryCount == 0) {
      return 'Set budgets to compare this month against a target.';
    }
    final topOverspend =
        budgetPerformance.topOverspendingCategories.firstOrNull;
    if (topOverspend != null) {
      return '${topOverspend.displayLabel} is over by ${formatMoney(topOverspend.overspent)}.';
    }
    return 'Budget coverage looks controlled for ${budgetPerformance.periodLabel}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final topPressure = snapshot.topCategories.firstOrNull;
    final pressureValue = topPressure == null
        ? 'None'
        : formatMoney(topPressure.amount);
    final pressureDetail = topPressure == null
        ? 'No spending pressure recorded this month.'
        : '${topPressure.name} is the largest spend pressure this month.';

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: snapshot.availableThisMonth >= 0
                    ? ClarityColors.financePositive
                    : ClarityColors.financeNegative,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _headline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _HealthMetricRow(
            icon: Icons.sync_alt_rounded,
            label: 'This month net',
            value: formatMoney(snapshot.availableThisMonth),
            detail:
                'Income ${formatMoney(snapshot.incomeThisMonth)} / Spending ${formatMoney(snapshot.spentThisMonth)}',
            valueColor: _balanceColor(context, snapshot.availableThisMonth),
          ),
          const SizedBox(height: 14),
          _HealthMetricRow(
            icon: Icons.trending_up_rounded,
            label: 'Spend pressure',
            value: pressureValue,
            detail: pressureDetail,
            valueColor: topPressure == null
                ? cs.onSurface.withValues(alpha: 0.55)
                : ClarityColors.financeSpending,
          ),
          const SizedBox(height: 14),
          _HealthMetricRow(
            icon: Icons.savings_outlined,
            label: 'Budget coverage',
            value: _budgetValue,
            detail: _budgetDetail,
            valueColor: budgetPerformance.totalOverspent > 0
                ? ClarityColors.financeNegative
                : cs.onSurface.withValues(alpha: 0.82),
          ),
        ],
      ),
    );
  }
}

class _HealthMetricRow extends StatelessWidget {
  const _HealthMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: cs.onSurface.withValues(alpha: 0.44)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.52),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
