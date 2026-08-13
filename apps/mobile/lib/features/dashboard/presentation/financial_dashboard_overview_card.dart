part of 'financial_dashboard_view.dart';

class _FinancialOverviewCard extends StatefulWidget {
  const _FinancialOverviewCard({
    required this.snapshot,
    required this.isGlobalScope,
    this.accountCount,
  });

  final DashboardSnapshot snapshot;
  final bool isGlobalScope;
  final int? accountCount;

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
            _NowPositionRow(snapshot: snapshot),
            if (snapshot.savings case final savings?) ...[
              const SizedBox(height: 12),
              _SavingsSummaryRow(
                savings: savings,
                month: snapshot.referenceMonth,
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

class _NowPositionRow extends StatelessWidget {
  const _NowPositionRow({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = <Widget>[
      _CashFlowSummaryMetric(
        label: l10n.dashboardOverviewDebtTotal,
        value: formatMoney(snapshot.debtTotal),
        color: snapshot.debtTotal > 0.005
            ? ClarityColors.financeNegative
            : Theme.of(context).colorScheme.onSurface,
      ),
      if (snapshot.creditAvailableTotal != null)
        _CashFlowSummaryMetric(
          label: l10n.dashboardOverviewCreditAvailable,
          value: formatMoney(snapshot.creditAvailableTotal),
          color: Theme.of(context).colorScheme.onSurface,
        ),
      _CashFlowSummaryMetric(
        label: l10n.dashboardOverviewCashTotal,
        value: formatMoney(snapshot.cashTotal),
        color: _balanceColor(context, snapshot.cashTotal),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: metrics[i]),
        ],
      ],
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
