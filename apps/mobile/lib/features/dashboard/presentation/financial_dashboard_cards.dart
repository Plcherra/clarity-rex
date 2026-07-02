part of 'financial_dashboard_view.dart';

class _BudgetPerformanceCard extends StatelessWidget {
  const _BudgetPerformanceCard({required this.performance});

  final BudgetPerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
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
          l10n.dashboardBudgetNoBudgetsForPeriod(performance.periodLabel),
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
            l10n.dashboardBudgetCategoriesOnTrack(
              performance.onTrackCategoryCount,
              performance.budgetedCategoryCount,
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.dashboardBudgetTotalOverspent(
              formatMoney(performance.totalOverspent),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: performance.totalOverspent > 0
                  ? ClarityColors.financeNegative
                  : ClarityColors.financePositive,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.dashboardBudgetBudgetedSpentLine(
              formatMoney(performance.totalBudgeted),
              formatMoney(performance.totalSpent),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 14),
          if (performance.topOverspendingCategories.isEmpty)
            Text(
              l10n.dashboardBudgetNoOverspendingCategories,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            )
          else
            for (final row in performance.topOverspendingCategories) ...[
              Text(
                l10n.dashboardBudgetCategoryOverspent(
                  row.displayLabel,
                  formatMoney(row.overspent),
                ),
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

  String _headline(AppLocalizations l10n) {
    if (snapshot.availableThisMonth < 0) {
      return l10n.dashboardHealthSpendingAheadOfIncome(
        formatMoney(-snapshot.availableThisMonth),
      );
    }
    if (snapshot.incomeThisMonth > 0 && snapshot.spentThisMonth > 0) {
      return l10n.dashboardHealthIncomeAheadOfSpending(
        formatMoney(snapshot.availableThisMonth),
      );
    }
    if (snapshot.spentThisMonth > 0) {
      return l10n.dashboardHealthSpendingActiveNoIncome;
    }
    if (snapshot.incomeThisMonth > 0) {
      return l10n.dashboardHealthIncomeNoSpending;
    }
    if (transactionCount > 0) {
      return l10n.dashboardHealthNoCurrentMonthActivity;
    }
    return l10n.dashboardHealthConnectTransactions;
  }

  String _budgetValue(AppLocalizations l10n) {
    if (budgetPerformance.budgetedCategoryCount == 0) {
      return l10n.dashboardHealthNoBudgets;
    }
    if (budgetPerformance.totalOverspent > 0) {
      return formatMoney(budgetPerformance.totalOverspent);
    }
    return l10n.commonOnTrack(
      budgetPerformance.onTrackCategoryCount,
      budgetPerformance.budgetedCategoryCount,
    );
  }

  String _budgetDetail(AppLocalizations l10n) {
    if (budgetPerformance.budgetedCategoryCount == 0) {
      return l10n.dashboardHealthSetBudgets;
    }
    final topOverspend =
        budgetPerformance.topOverspendingCategories.firstOrNull;
    if (topOverspend != null) {
      return l10n.dashboardHealthCategoryOverBy(
        topOverspend.displayLabel,
        formatMoney(topOverspend.overspent),
      );
    }
    return l10n.dashboardHealthBudgetControlled(budgetPerformance.periodLabel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final topPressure = snapshot.topCategories.firstOrNull;
    final pressureValue = topPressure == null
        ? l10n.commonNone
        : formatMoney(topPressure.amount);
    final pressureDetail = topPressure == null
        ? l10n.dashboardHealthNoSpendingPressure
        : l10n.dashboardHealthTopSpendPressure(topPressure.name);

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
                  _headline(l10n),
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
            label: l10n.dashboardHealthThisMonthNet,
            value: formatMoney(snapshot.availableThisMonth),
            detail: l10n.dashboardHealthIncomeSpendingLine(
              formatMoney(snapshot.incomeThisMonth),
              formatMoney(snapshot.spentThisMonth),
            ),
            valueColor: _balanceColor(context, snapshot.availableThisMonth),
          ),
          const SizedBox(height: 14),
          _HealthMetricRow(
            icon: Icons.trending_up_rounded,
            label: l10n.dashboardHealthSpendPressureLabel,
            value: pressureValue,
            detail: pressureDetail,
            valueColor: topPressure == null
                ? cs.onSurface.withValues(alpha: 0.55)
                : ClarityColors.financeSpending,
          ),
          const SizedBox(height: 14),
          _HealthMetricRow(
            icon: Icons.savings_outlined,
            label: l10n.dashboardHealthBudgetCoverageLabel,
            value: _budgetValue(l10n),
            detail: _budgetDetail(l10n),
            valueColor: budgetPerformance.totalOverspent > 0
                ? ClarityColors.financeNegative
                : cs.onSurface.withValues(alpha: 0.82),
          ),
          if (snapshot.burnRunwayDays case final runway?) ...[
            const SizedBox(height: 14),
            _HealthMetricRow(
              icon: Icons.hourglass_bottom_rounded,
              label: l10n.dashboardHealthBurnRunwayLabel,
              value: l10n.dashboardHealthBurnRunwayDays(runway),
              detail: l10n.dashboardHealthBurnRunwayDetail(runway),
              valueColor: runway <= 14
                  ? ClarityColors.financeNegative
                  : runway <= 30
                  ? ClarityColors.warning
                  : cs.onSurface.withValues(alpha: 0.82),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardBudgetChartPanel extends StatelessWidget {
  const _DashboardBudgetChartPanel({required this.performance});

  final BudgetPerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    if (performance.budgetedCategoryCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return ClarityCard(
      padding: EdgeInsets.zero,
      backgroundColor: _dashboardPanel(context),
      borderColor: _dashboardOutline(context),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: cs.primary.withValues(alpha: 0.08),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          initiallyExpanded: false,
          iconColor: cs.onSurface.withValues(alpha: 0.56),
          collapsedIconColor: cs.onSurface.withValues(alpha: 0.56),
          title: Text(
            l10n.dashboardOverviewBudgetVsSpentChart,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            l10n.dashboardBudgetCategoriesOnTrack(
              performance.onTrackCategoryCount,
              performance.budgetedCategoryCount,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
            ),
          ),
          children: [BudgetVsSpentChart(performance: performance)],
        ),
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
