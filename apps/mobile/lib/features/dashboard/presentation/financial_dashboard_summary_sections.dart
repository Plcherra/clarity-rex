part of 'financial_dashboard_view.dart';

class _MonthlyGroupsList extends StatelessWidget {
  const _MonthlyGroupsList({
    required this.groups,
    required this.controller,
    required this.transactionController,
  });

  final List<MonthlyBankGroup> groups;
  final DashboardUiController controller;
  final TransactionUiController transactionController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    if (groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: _dashboardCardPaddingOf(
          context,
          const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        ),
        decoration: BoxDecoration(
          color: _dashboardPanel(context),
          borderRadius: BorderRadius.circular(_dashboardCardRadiusOf(context)),
          border: Border.all(color: _dashboardOutline(context)),
        ),
        child: Text(
          l10n.dashboardTransactionsNoMonthsAfterFilter,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MonthCard(
            group: groups[i],
            controller: controller,
            transactionController: transactionController,
          ),
        ],
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.group,
    required this.controller,
    required this.transactionController,
  });

  final MonthlyBankGroup group;
  final DashboardUiController controller;
  final TransactionUiController transactionController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final compact = !isClarityDesktopLayout(context);
    final native = ClarityNativeLayout.active(context);
    final radius = _dashboardCardRadiusOf(context);
    final label = formatYearMonthLabel(group.yearMonth);
    final totalColor = group.totalAmount < 0
        ? ClarityColors.financeNegative
        : group.totalAmount > 0
        ? ClarityColors.financePositive
        : cs.onSurface;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(native ? radius : 22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => MonthDetailScreen(
                controller: controller,
                transactionController: transactionController,
                group: group,
              ),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _dashboardOutline(context)),
          ),
          child: Padding(
            padding: native
                ? ClarityNativeLayout.cardPadding(context)
                : EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 22,
                    vertical: compact ? 14 : 20,
                  ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: (compact
                                ? theme.textTheme.titleSmall
                                : theme.textTheme.titleMedium)
                            ?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.transactions.length == 1
                            ? l10n.commonTransactionCountOne
                            : l10n.commonTransactionCount(
                                group.transactions.length,
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(group.totalAmount),
                      style: (compact
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: totalColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.dashboardTransactionsNetLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.38),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.title});

  final ThemeData theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = !isClarityDesktopLayout(context);
    return Text(
      title,
      style: (compact
              ? theme.textTheme.titleSmall
              : theme.textTheme.titleMedium)
          ?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
      ),
    );
  }
}
