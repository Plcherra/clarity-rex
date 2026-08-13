part of 'financial_dashboard_view.dart';

/// Savings sits beside the month, not inside it.
///
/// Money moved into savings was never spent and money taken back out was never
/// earned, so it gets its own line instead of distorting income or spending.
class _SavingsSummaryRow extends StatelessWidget {
  const _SavingsSummaryRow({required this.savings, required this.month});

  final SavingsSnapshot savings;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final moved = savings.changeThisMonth.abs();
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final monthLabel = formatMonthLabel(month);

    final (movement, movementColor) = switch (savings) {
      SavingsSnapshot(grewThisMonth: true) => (
        isCurrentMonth
            ? l10n.dashboardOverviewSavingsMovedIn(formatMoney(moved))
            : l10n.dashboardOverviewSavingsMovedInInMonth(
                formatMoney(moved),
                monthLabel,
              ),
        ClarityColors.financePositive,
      ),
      SavingsSnapshot(shrankThisMonth: true) => (
        isCurrentMonth
            ? l10n.dashboardOverviewSavingsTakenOut(formatMoney(moved))
            : l10n.dashboardOverviewSavingsTakenOutInMonth(
                formatMoney(moved),
                monthLabel,
              ),
        ClarityColors.financeSpending,
      ),
      _ => (
        l10n.dashboardOverviewSavingsUnchanged,
        cs.onSurface.withValues(alpha: 0.5),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _dashboardPanelMuted(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardOverviewSavings,
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
                      formatMoney(savings.balance),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                movement,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: movementColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
