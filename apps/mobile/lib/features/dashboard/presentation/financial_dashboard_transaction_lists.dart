part of 'financial_dashboard_view.dart';

class _CategoryGroupsList extends StatelessWidget {
  const _CategoryGroupsList({
    required this.groups,
    required this.onCategorySelected,
  });

  final List<DashboardCategoryTransactionGroup> groups;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _InlineEmptyState(message: 'No categories match.');
    }
    return Column(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _CategoryGroupCard(
            group: groups[i],
            onTap: () => onCategorySelected(groups[i].category),
          ),
        ],
      ],
    );
  }
}

class _CategoryGroupCard extends StatelessWidget {
  const _CategoryGroupCard({required this.group, required this.onTap});

  final DashboardCategoryTransactionGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(_cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: _dashboardOutline(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                        '${group.transactionCount} transactions',
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
                      group.amountLabel,
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
                            ? const Color(0xFF9B2C2C)
                            : cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
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

class _InlineTransactionsList extends StatefulWidget {
  const _InlineTransactionsList({
    required this.transactions,
    required this.controller,
    required this.accountsById,
    required this.showAccount,
  });

  final List<ResolvedTransaction> transactions;
  final TransactionUiController controller;
  final Map<String, Account> accountsById;
  final bool showAccount;

  @override
  State<_InlineTransactionsList> createState() =>
      _InlineTransactionsListState();
}

class _InlineTransactionsListState extends State<_InlineTransactionsList> {
  static const _pageSize = 80;

  var _visibleCount = _pageSize;

  @override
  void didUpdateWidget(covariant _InlineTransactionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_listSignature(oldWidget.transactions) !=
        _listSignature(widget.transactions)) {
      _visibleCount = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const _InlineEmptyState(message: 'No transactions match.');
    }
    final visible = widget.transactions.take(_visibleCount).toList();
    final remaining = widget.transactions.length - visible.length;
    final nextCount = remaining < _pageSize ? remaining : _pageSize;
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _InlineTransactionCard(
            transaction: visible[i],
            controller: widget.controller,
            account: widget.accountsById[visible[i].transaction.accountId],
            showAccount: widget.showAccount,
          ),
        ],
        if (remaining > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _visibleCount += _pageSize;
                });
              },
              icon: const Icon(Icons.unfold_more_rounded),
              label: Text(
                'Show $nextCount more (${visible.length} of ${widget.transactions.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: _dashboardOutline(context)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _listSignature(List<ResolvedTransaction> transactions) {
    if (transactions.isEmpty) return 'empty';
    final first = transactions.first.transaction;
    final last = transactions.last.transaction;
    return [
      transactions.length,
      first.fingerprint ?? transactionCategoryKey(first),
      last.fingerprint ?? transactionCategoryKey(last),
    ].join('|');
  }
}

class _InlineTransactionCard extends StatelessWidget {
  const _InlineTransactionCard({
    required this.transaction,
    required this.controller,
    required this.account,
    required this.showAccount,
  });

  final ResolvedTransaction transaction;
  final TransactionUiController controller;
  final Account? account;
  final bool showAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rawTransaction = transaction.transaction;
    final amountColor = rawTransaction.amount < 0
        ? const Color(0xFFC41E3A)
        : rawTransaction.amount > 0
        ? const Color(0xFF1B7A4C)
        : cs.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _shortDate(rawTransaction.date),
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.42),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rawTransaction.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (showAccount && account != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    account!.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TransactionCategoryField(
                  controller: controller,
                  transaction: rawTransaction,
                  displayCategory: _displayCategory(transaction),
                ),
                const SizedBox(height: 6),
                TransactionRoleField(
                  controller: controller,
                  transaction: rawTransaction,
                ),
                if (rawTransaction.pending) ...[
                  const SizedBox(height: 8),
                  const _TransactionMetaChip('Pending'),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(rawTransaction.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_cardRadius),
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
