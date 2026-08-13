part of 'financial_dashboard_view.dart';

class _FinancialOverviewCard extends StatelessWidget {
  const _FinancialOverviewCard({
    required this.snapshot,
    required this.isGlobalScope,
    required this.availableYearMonths,
    required this.onMonthSelected,
    required this.period,
    required this.onPeriodChanged,
    this.accountCount,
  });

  final DashboardSnapshot snapshot;
  final bool isGlobalScope;
  final int? accountCount;
  final List<String> availableYearMonths;
  final ValueChanged<DateTime> onMonthSelected;
  final DashboardActivityPeriod period;
  final ValueChanged<DashboardActivityPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    final desktop = isClarityDesktopLayout(context);
    final totals = dashboardActivityTotals(
      period: period,
      reference: snapshot.referenceMonth,
      incomeThisMonth: snapshot.incomeThisMonth,
      spentThisMonth: snapshot.spentThisMonth,
      monthlyCashFlow: snapshot.monthlyCashFlow,
    );
    final left = totals.income - totals.spent;
    final leftSplit = dashboardActivityLeftSplit(
      period: period,
      reference: snapshot.referenceMonth,
      monthlyCashFlow: snapshot.monthlyCashFlow,
    );
    final now = DateTime.now();
    final viewingCurrentMonth =
        snapshot.referenceMonth.year == now.year &&
        snapshot.referenceMonth.month == now.month;
    final accountCount = this.accountCount ?? 0;
    final periodStrip = _PeriodActivityStrip(
      period: period,
      income: totals.income,
      spent: totals.spent,
      left: left,
      leftCash: leftSplit.cash,
      leftCredit:
          snapshot.creditAvailableTotal != null || leftSplit.credit.abs() > 0.005
          ? leftSplit.credit
          : null,
      showLeftSplit: isGlobalScope,
      selectedMonth: snapshot.referenceMonth,
      availableYearMonths: availableYearMonths,
      onMonthSelected: onMonthSelected,
      onPeriodChanged: onPeriodChanged,
    );
    final nowDetails = <Widget>[
      if (isGlobalScope) ...[
        _CashFlowSummaryMetric(
          label: l10n.dashboardOverviewDebtTotal,
          value: formatMoney(snapshot.debtTotal),
          color: snapshot.debtTotal > 0.005
              ? ClarityColors.financeNegative
              : cs.onSurface,
        ),
        if (snapshot.savings case final savings?) ...[
          const SizedBox(height: 12),
          _SavingsSummaryRow(
            savings: savings,
            month: snapshot.referenceMonth,
            showMovement: viewingCurrentMonth,
          ),
        ],
        const SizedBox(height: 12),
        _LeftSplitRow(
          leftLabel: l10n.dashboardOverviewLeftToUse,
          leftValue: snapshot.cashTotal + (snapshot.creditAvailableTotal ?? 0),
          cash: snapshot.cashTotal,
          credit: snapshot.creditAvailableTotal,
        ),
      ] else if (snapshot.creditAvailableTotal != null) ...[
        _CashFlowSummaryMetric(
          label: l10n.dashboardOverviewCreditAvailable,
          value: formatMoney(snapshot.creditAvailableTotal),
          color: cs.onSurface,
        ),
      ],
    ];
    return Container(
      width: double.infinity,
      padding: native
          ? ClarityNativeLayout.cardPadding(context)
          : const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_dashboardCardRadiusOf(context)),
        border: Border.all(color: _dashboardOutline(context)),
        boxShadow: _dashboardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGlobalScope
                ? l10n.dashboardOverviewTotalBalance
                : l10n.dashboardOverviewAccountBalance,
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
              style: (!desktop
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.displaySmall)
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.02,
                    color: _balanceColor(context, snapshot.totalBalance),
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isGlobalScope && accountCount > 0
                ? l10n.dashboardOverviewNetBalanceHint(
                    accountCount,
                    accountCount == 1 ? '' : 's',
                  )
                : l10n.dashboardOverviewFromConnectedAccounts,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.46),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (desktop && isGlobalScope)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: nowDetails,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: periodStrip),
              ],
            )
          else ...[
            ...nowDetails,
            if (nowDetails.isNotEmpty) const SizedBox(height: 16),
            periodStrip,
          ],
        ],
      ),
    );
  }
}

class _LeftSplitRow extends StatelessWidget {
  const _LeftSplitRow({
    required this.leftLabel,
    required this.leftValue,
    required this.cash,
    this.credit,
    this.creditLabel,
  });

  final String leftLabel;
  final double leftValue;
  final double cash;
  final double? credit;
  final String? creditLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _dashboardPanelMuted(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              leftLabel,
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
                formatMoney(leftValue),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _balanceColor(context, leftValue),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${formatMoney(cash)} ${l10n.dashboardOverviewCashTotal}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _balanceColor(context, cash),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (credit != null)
                  Text(
                    '${formatMoney(credit)} ${creditLabel ?? l10n.dashboardOverviewCreditAvailable}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
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
        color: _dashboardPanelMuted(context),
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
