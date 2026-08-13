part of 'financial_dashboard_view.dart';

class _FinancialOverviewCard extends StatefulWidget {
  const _FinancialOverviewCard({
    required this.snapshot,
    required this.isGlobalScope,
    required this.availableYearMonths,
    required this.onMonthSelected,
    this.accountCount,
  });

  final DashboardSnapshot snapshot;
  final bool isGlobalScope;
  final int? accountCount;
  final List<String> availableYearMonths;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  State<_FinancialOverviewCard> createState() => _FinancialOverviewCardState();
}

class _FinancialOverviewCardState extends State<_FinancialOverviewCard> {
  DashboardActivityPeriod _period = DashboardActivityPeriod.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    final snapshot = widget.snapshot;
    final totals = dashboardActivityTotals(
      period: _period,
      reference: snapshot.referenceMonth,
      incomeThisMonth: snapshot.incomeThisMonth,
      spentThisMonth: snapshot.spentThisMonth,
      monthlyCashFlow: snapshot.monthlyCashFlow,
    );
    final left = totals.income - totals.spent;
    final now = DateTime.now();
    final viewingCurrentMonth =
        snapshot.referenceMonth.year == now.year &&
        snapshot.referenceMonth.month == now.month;
    return Container(
      width: double.infinity,
      padding: native
          ? ClarityNativeLayout.cardPadding(context)
          : EdgeInsets.fromLTRB(
              !isClarityDesktopLayout(context) ? 16 : 20,
              !isClarityDesktopLayout(context) ? 14 : 18,
              !isClarityDesktopLayout(context) ? 16 : 20,
              !isClarityDesktopLayout(context) ? 16 : 20,
            ),
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
            widget.isGlobalScope
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
              style: (!isClarityDesktopLayout(context)
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
            widget.isGlobalScope
                ? l10n.dashboardOverviewNetBalanceHint
                : l10n.dashboardOverviewFromConnectedAccounts,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.46),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.isGlobalScope &&
              widget.accountCount != null &&
              widget.accountCount! > 0) ...[
            const SizedBox(height: 2),
            Text(
              l10n.commonAcrossAccounts(
                widget.accountCount!,
                widget.accountCount == 1 ? '' : 's',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.46),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (widget.isGlobalScope) ...[
            const SizedBox(height: 14),
            _CashFlowSummaryMetric(
              label: l10n.dashboardOverviewDebtTotal,
              value: formatMoney(snapshot.debtTotal),
              color: snapshot.debtTotal > 0.005
                  ? ClarityColors.financeNegative
                  : cs.onSurface,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.dashboardOverviewDebtHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.42),
                fontWeight: FontWeight.w600,
              ),
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
            if (snapshot.creditLeftIncomplete) ...[
              const SizedBox(height: 6),
              Text(
                l10n.dashboardOverviewCreditLeftPartial,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ClarityColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ] else if (snapshot.creditAvailableTotal != null) ...[
            const SizedBox(height: 14),
            _CashFlowSummaryMetric(
              label: l10n.dashboardOverviewCreditAvailable,
              value: formatMoney(snapshot.creditAvailableTotal),
              color: cs.onSurface,
            ),
          ],
          const SizedBox(height: 16),
          _PeriodActivityStrip(
            period: _period,
            income: totals.income,
            spent: totals.spent,
            left: left,
            cash: snapshot.cashTotal,
            credit: snapshot.creditAvailableTotal,
            selectedMonth: snapshot.referenceMonth,
            availableYearMonths: widget.availableYearMonths,
            onMonthSelected: widget.onMonthSelected,
            showPendingNote:
                _period == DashboardActivityPeriod.month &&
                snapshot.hasPendingCashFlowThisMonth,
            onPeriodChanged: (period) => setState(() => _period = period),
          ),
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
  });

  final String leftLabel;
  final double leftValue;
  final double cash;
  final double? credit;

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
                    '${formatMoney(credit)} ${l10n.dashboardOverviewCreditAvailable}',
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
