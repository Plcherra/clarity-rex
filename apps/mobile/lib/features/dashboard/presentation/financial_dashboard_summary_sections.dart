part of 'financial_dashboard_view.dart';

class _CashFlowSummaryCard extends StatelessWidget {
  const _CashFlowSummaryCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final availableValue = formatMoney(snapshot.availableThisMonth);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: _dashboardPanel,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cash flow',
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
              availableValue,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.02,
                color: _balanceColor(snapshot.availableThisMonth),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Income minus spending',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.46),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CashFlowSummaryMetric(
                  label: 'Income',
                  value: formatMoney(snapshot.incomeThisMonth),
                  color: const Color(0xFF1B7A4C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CashFlowSummaryMetric(
                  label: 'Spending',
                  value: formatMoney(snapshot.spentThisMonth),
                  color: const Color(0xFF9B2C2C),
                ),
              ),
            ],
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
        color: _dashboardPanelMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
    if (groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: _dashboardPanel,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: _dashboardOutline),
        ),
        child: Text(
          'No months to show after filtering this file.',
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
    final label = formatYearMonthLabel(group.yearMonth);
    final totalColor = group.totalAmount < 0
        ? const Color(0xFFC41E3A)
        : group.totalAmount > 0
        ? const Color(0xFF1B7A4C)
        : cs.onSurface;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(22),
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
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: _dashboardOutline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.transactions.length} transactions',
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: totalColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'net',
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
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
      ),
    );
  }
}
