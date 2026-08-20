part of 'financial_dashboard_view.dart';

class _PeriodActivityStrip extends StatelessWidget {
  const _PeriodActivityStrip({
    required this.period,
    required this.income,
    required this.spent,
    required this.left,
    required this.leftCash,
    required this.leftCredit,
    required this.showLeftSplit,
    this.isCreditCard = false,
    required this.selectedMonth,
    required this.availableYearMonths,
    required this.onMonthSelected,
    required this.onPeriodChanged,
  });

  final DashboardActivityPeriod period;
  final double income;
  final double spent;
  final double left;
  final double leftCash;
  final double? leftCredit;
  final bool showLeftSplit;
  final bool isCreditCard;
  final DateTime selectedMonth;
  final List<String> availableYearMonths;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DashboardActivityPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
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
                _periodLabel(l10n, period),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _ActivityPeriodSwitch(
              period: period,
              onChanged: onPeriodChanged,
            ),
          ],
        ),
        DashboardMonthSwitcher(
          selectedMonth: selectedMonth,
          availableYearMonths: availableYearMonths,
          onMonthSelected: onMonthSelected,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _CashFlowSummaryMetric(
                label: isCreditCard
                    ? l10n.dashboardOverviewPayments
                    : l10n.commonIncome,
                value: formatMoney(income),
                color: ClarityColors.financePositive,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CashFlowSummaryMetric(
                label: isCreditCard
                    ? l10n.dashboardOverviewCharged
                    : l10n.commonSpending,
                value: formatMoney(spent),
                color: ClarityColors.financeSpending,
              ),
            ),
          ],
        ),
        if (!isCreditCard) ...[
          const SizedBox(height: 10),
          if (showLeftSplit)
            _LeftSplitRow(
              leftLabel: period == DashboardActivityPeriod.month
                  ? l10n.dashboardOverviewLeftThisMonth
                  : l10n.dashboardOverviewLeftThisPeriod,
              leftValue: left,
              cash: leftCash,
              credit: leftCredit,
            )
          else
            _CashFlowSummaryMetric(
              label: period == DashboardActivityPeriod.month
                  ? l10n.dashboardOverviewLeftThisMonth
                  : l10n.dashboardOverviewLeftThisPeriod,
              value: formatMoney(left),
              color: _balanceColor(context, left),
            ),
        ],
      ],
    );
  }

  String _periodLabel(AppLocalizations l10n, DashboardActivityPeriod period) {
    return switch (period) {
      DashboardActivityPeriod.month => l10n.dashboardOverviewThisMonthLabel,
      DashboardActivityPeriod.sixMonths => l10n.dashboardOverviewPeriodSixMonths,
      DashboardActivityPeriod.year => l10n.dashboardOverviewPeriodThisYear,
    };
  }
}

class _ActivityPeriodSwitch extends StatelessWidget {
  const _ActivityPeriodSwitch({
    required this.period,
    required this.onChanged,
  });

  final DashboardActivityPeriod period;
  final ValueChanged<DashboardActivityPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in DashboardActivityPeriod.values) ...[
          if (value != DashboardActivityPeriod.values.first)
            const SizedBox(width: 4),
          _PeriodChip(
            label: switch (value) {
              DashboardActivityPeriod.month =>
                l10n.dashboardOverviewPeriodMonthShort,
              DashboardActivityPeriod.sixMonths =>
                l10n.financeChartRange6Months,
              DashboardActivityPeriod.year => l10n.financeChartRange12Months,
            },
            selected: value == period,
            onTap: () => onChanged(value),
          ),
        ],
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? colors.accent.withValues(alpha: 0.16)
          : colors.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected
                  ? colors.accent
                  : theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ),
      ),
    );
  }
}
