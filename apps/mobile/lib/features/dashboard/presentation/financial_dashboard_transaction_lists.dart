part of 'financial_dashboard_view.dart';

class _FlatTransactionsSliver extends StatelessWidget {
  const _FlatTransactionsSliver({
    required this.transactions,
    required this.transactionController,
    required this.horizontalPadding,
  });

  final List<ResolvedTransaction> transactions;
  final TransactionUiController transactionController;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (transactions.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 0),
        sliver: SliverToBoxAdapter(
          child: _InlineEmptyState(
            message: l10n.dashboardTransactionsNoTransactionsMatch,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final resolved = transactions[index];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                TransactionLineTile(
                  transaction: resolved.transaction,
                  displayCategory: _displayCategory(l10n, resolved),
                  transactionController: transactionController,
                  horizontalPadding: 4,
                ),
              ],
            );
          },
          childCount: transactions.length,
        ),
      ),
    );
  }
}

class _CategoryGroupsList extends StatelessWidget {
  const _CategoryGroupsList({
    required this.groups,
    required this.onCategoryTap,
  });

  final List<DashboardCategoryTransactionGroup> groups;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _InlineEmptyState(
        message: context.l10n.dashboardTransactionsNoCategoriesMatch,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _CategoryGroupCard(
            group: groups[i],
            onTap: () => onCategoryTap(groups[i].category),
          ),
        ],
      ],
    );
  }
}

class _CategoryGroupCard extends StatelessWidget {
  const _CategoryGroupCard({
    required this.group,
    required this.onTap,
  });

  final DashboardCategoryTransactionGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final radius = _dashboardCardRadiusOf(context);
    return Material(
      color: _dashboardPanel(context),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _dashboardOutline(context)),
          ),
          child: Padding(
            padding: _dashboardCardPaddingOf(
              context,
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onSurface.withValues(alpha: 0.28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.category,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.transactions.length == 1
                            ? l10n.commonTransactionCountOne
                            : l10n.commonTransactionCount(
                                group.transactionCount,
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
                      l10n.commonSpent,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatMoney(group.spending),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: group.spending > 0
                            ? ClarityColors.financeSpending
                            : cs.onSurface,
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

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
