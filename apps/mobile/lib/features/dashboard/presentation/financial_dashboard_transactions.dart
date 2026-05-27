part of 'financial_dashboard_view.dart';

enum _TransactionsViewMode { months, categories, rows }

enum _TransactionsTimeFilter {
  all,
  dashboardMonth,
  latestTransactionMonth,
  latestTransactionYear,
}

enum _TransactionsSortMode { newest, oldest, largest, merchant }

class _DashboardTransactionsSection extends StatefulWidget {
  const _DashboardTransactionsSection({
    required this.snapshot,
    required this.controller,
    required this.transactionController,
    required this.scope,
  });

  final DashboardSnapshot snapshot;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final DashboardScope scope;

  @override
  State<_DashboardTransactionsSection> createState() =>
      _DashboardTransactionsSectionState();
}

class _DashboardTransactionsSectionState
    extends State<_DashboardTransactionsSection> {
  final _searchController = TextEditingController();
  var _mode = _TransactionsViewMode.months;
  var _timeFilter = _TransactionsTimeFilter.all;
  var _sortMode = _TransactionsSortMode.newest;
  String? _categoryFilter;
  String? _accountFilter;
  FinancialRole? _roleFilter;
  List<Transaction> _transactions = const [];
  List<Transaction> _allTransactions = const [];
  List<Account> _accounts = const [];
  Object? _error;
  var _loading = true;
  var _loadGeneration = 0;

  bool get _isAccountScope => widget.scope is AccountDashboardScope;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    widget.controller.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant _DashboardTransactionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_load);
      widget.controller.addListener(_load);
    }
    if (oldWidget.scope != widget.scope ||
        oldWidget.controller != widget.controller) {
      _accountFilter = null;
      _load();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_load);
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.controller.transactionReadDataForScope(
        widget.scope,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _transactions = data.transactions;
        _allTransactions = data.allTransactions;
        _accounts = data.accounts;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  int get _activeFilterCount {
    var count = 0;
    if (_categoryFilter != null) count++;
    if (_timeFilter != _TransactionsTimeFilter.all) count++;
    if (_sortMode != _TransactionsSortMode.newest) count++;
    if (_roleFilter != null) count++;
    if (!_isAccountScope && _accountFilter != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _accountFilter = null;
      _roleFilter = null;
      _timeFilter = _TransactionsTimeFilter.all;
      _sortMode = _TransactionsSortMode.newest;
      _searchController.clear();
    });
  }

  List<ResolvedTransaction> get _resolvedTransactions {
    return resolveTransactions(
      _transactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: widget.controller.categoryDisplayRenames,
      accountsById: {for (final account in _accounts) account.id: account},
      allTransactions: _allTransactions,
    );
  }

  List<ResolvedTransaction> get _filteredTransactions {
    final query = _normalizeSearchText(_searchController.text);
    final range = _activeDateRange;
    final accountsById = {for (final account in _accounts) account.id: account};
    final filtered = _resolvedTransactions.where((resolved) {
      final t = resolved.transaction;
      if (_categoryFilter != null &&
          _displayCategory(resolved) != _categoryFilter) {
        return false;
      }
      if (!_isAccountScope &&
          _accountFilter != null &&
          t.accountId != _accountFilter) {
        return false;
      }
      if (!_matchesTimeFilter(t, range)) return false;
      if (_roleFilter != null && resolved.financialRole != _roleFilter) {
        return false;
      }
      if (query.isNotEmpty && !_matchesSearch(resolved, query, accountsById)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortMode) {
        _TransactionsSortMode.newest => b.transaction.date.compareTo(
          a.transaction.date,
        ),
        _TransactionsSortMode.oldest => a.transaction.date.compareTo(
          b.transaction.date,
        ),
        _TransactionsSortMode.largest => b.transaction.amount.abs().compareTo(
          a.transaction.amount.abs(),
        ),
        _TransactionsSortMode.merchant =>
          a.transaction.description.toLowerCase().compareTo(
            b.transaction.description.toLowerCase(),
          ),
      };
    });
    return filtered;
  }

  DateTimeRange? get _activeDateRange {
    final latest = _latestTransactionDate(_transactions);
    return switch (_timeFilter) {
      _TransactionsTimeFilter.all => null,
      _TransactionsTimeFilter.dashboardMonth => _monthRange(
        widget.controller.spendReference,
      ),
      _TransactionsTimeFilter.latestTransactionMonth =>
        latest == null ? null : _monthRange(latest),
      _TransactionsTimeFilter.latestTransactionYear =>
        latest == null
            ? null
            : DateTimeRange(
                start: DateTime(latest.year),
                end: DateTime(latest.year, 12, 31),
              ),
    };
  }

  bool _matchesTimeFilter(Transaction t, DateTimeRange? range) {
    if (range == null) return true;
    final date = DateTime(t.date.year, t.date.month, t.date.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String get _activeDateRangeDescription {
    if (_timeFilter == _TransactionsTimeFilter.all) {
      final bounds = _transactionDateBounds(_transactions);
      if (bounds == null) return 'No imported history';
      return 'History: ${_dateRangeLabel(bounds)}';
    }
    final range = _activeDateRange;
    if (range == null) return _timeLabel(_timeFilter);
    return switch (_timeFilter) {
      _TransactionsTimeFilter.all => 'All history',
      _TransactionsTimeFilter.dashboardMonth =>
        'Dashboard month: ${_dateRangeLabel(range)}',
      _TransactionsTimeFilter.latestTransactionMonth =>
        'Latest transaction month: ${_dateRangeLabel(range)}',
      _TransactionsTimeFilter.latestTransactionYear =>
        'Latest transaction year: ${_dateRangeLabel(range)}',
    };
  }

  bool _matchesSearch(
    ResolvedTransaction resolved,
    String query,
    Map<String, Account> accountsById,
  ) {
    final transaction = resolved.transaction;
    final account = accountsById[transaction.accountId];
    final haystack = [
      transaction.description,
      _displayCategory(resolved),
      _financialRoleLabel(resolved.financialRole),
      _yearMonthLabel(transaction.date),
      _shortDate(transaction.date),
      formatMoney(transaction.amount),
      if (account != null) account.name,
      if (account?.institution?.trim().isNotEmpty == true)
        account!.institution!,
    ].map(_normalizeSearchText).join(' ');
    return haystack.contains(query);
  }

  List<String> get _categoryOptions {
    final names = <String>{};
    for (final transaction in _resolvedTransactions) {
      if (!_isSpendCategoryTransaction(transaction)) continue;
      names.add(_displayCategory(transaction));
    }
    final sorted = names.toList()
      ..sort((a, b) {
        if (a == 'Unknown') return -1;
        if (b == 'Unknown') return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return sorted;
  }

  List<MonthlyBankGroup> get _monthGroups {
    return monthlyBankGroupsNewestFirstForResolvedTransactions(
      _filteredTransactions,
    );
  }

  List<DashboardCategoryTransactionGroup> get _categoryGroups {
    return spendingCategoryGroupsForResolvedTransactions(_filteredTransactions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _filteredTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(theme: theme, title: 'Transactions'),
                  const SizedBox(height: 6),
                  Text(
                    _sectionSubtitle(filtered.length),
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 0.6,
                      color: cs.onSurface.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_activeFilterCount > 0)
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _TransactionsModePicker(
          selected: _mode,
          onSelected: (mode) => setState(() => _mode = mode),
        ),
        const SizedBox(height: 12),
        _TransactionSearchField(controller: _searchController),
        const SizedBox(height: 12),
        _InlineFilterBar(
          categories: _categoryOptions,
          accounts: _accounts,
          isAccountScope: _isAccountScope,
          category: _categoryFilter,
          accountId: _accountFilter,
          timeFilter: _timeFilter,
          sortMode: _sortMode,
          roleFilter: _roleFilter,
          onCategoryChanged: (value) => setState(() => _categoryFilter = value),
          onAccountChanged: (value) => setState(() => _accountFilter = value),
          onTimeChanged: (value) => setState(() => _timeFilter = value),
          onSortChanged: (value) => setState(() => _sortMode = value),
          onRoleChanged: (value) => setState(() => _roleFilter = value),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _InlineEmptyState(
            message: 'Could not load transactions.',
            actionLabel: 'Retry',
            onAction: _load,
          )
        else
          switch (_mode) {
            _TransactionsViewMode.months => _MonthlyGroupsList(
              groups: _monthGroups,
              controller: widget.controller,
              transactionController: widget.transactionController,
            ),
            _TransactionsViewMode.categories => _CategoryGroupsList(
              groups: _categoryGroups,
              onCategorySelected: (category) {
                setState(() {
                  _categoryFilter = category;
                  _mode = _TransactionsViewMode.rows;
                });
              },
            ),
            _TransactionsViewMode.rows => _InlineTransactionsList(
              transactions: filtered,
              controller: widget.transactionController,
              accountsById: {
                for (final account in _accounts) account.id: account,
              },
              showAccount: !_isAccountScope,
            ),
          },
      ],
    );
  }

  String _sectionSubtitle(int filteredCount) {
    if (_activeFilterCount == 0 && _mode == _TransactionsViewMode.months) {
      return 'Tap a month to inspect transactions | $_activeDateRangeDescription';
    }
    final count = _transactions.length;
    return '$filteredCount of $count transactions | $_activeDateRangeDescription';
  }
}

class _TransactionsModePicker extends StatelessWidget {
  const _TransactionsModePicker({
    required this.selected,
    required this.onSelected,
  });

  final _TransactionsViewMode selected;
  final ValueChanged<_TransactionsViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ModeChip(
          label: 'Months',
          icon: Icons.calendar_month_outlined,
          selected: selected == _TransactionsViewMode.months,
          onTap: () => onSelected(_TransactionsViewMode.months),
        ),
        _ModeChip(
          label: 'Categories',
          icon: Icons.category_outlined,
          selected: selected == _TransactionsViewMode.categories,
          onTap: () => onSelected(_TransactionsViewMode.categories),
        ),
        _ModeChip(
          label: 'Rows',
          icon: Icons.receipt_long_outlined,
          selected: selected == _TransactionsViewMode.rows,
          onTap: () => onSelected(_TransactionsViewMode.rows),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      selectedColor: const Color(0xFFEFE4B8),
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: const Color(0xFFD8D1C5)),
      ),
    );
  }
}

class _TransactionSearchField extends StatelessWidget {
  const _TransactionSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.search_rounded,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
        hintText: 'Search merchant, category, month, or amount',
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _dashboardOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _dashboardOutline),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _InlineFilterBar extends StatelessWidget {
  const _InlineFilterBar({
    required this.categories,
    required this.accounts,
    required this.isAccountScope,
    required this.category,
    required this.accountId,
    required this.timeFilter,
    required this.sortMode,
    required this.roleFilter,
    required this.onCategoryChanged,
    required this.onAccountChanged,
    required this.onTimeChanged,
    required this.onSortChanged,
    required this.onRoleChanged,
  });

  final List<String> categories;
  final List<Account> accounts;
  final bool isAccountScope;
  final String? category;
  final String? accountId;
  final _TransactionsTimeFilter timeFilter;
  final _TransactionsSortMode sortMode;
  final FinancialRole? roleFilter;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<_TransactionsTimeFilter> onTimeChanged;
  final ValueChanged<_TransactionsSortMode> onSortChanged;
  final ValueChanged<FinancialRole?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PopupFilterChip<String?>(
          label: category ?? 'Category',
          active: category != null,
          icon: Icons.category_outlined,
          values: [null, ...categories],
          labelFor: (value) => value ?? 'All categories',
          onSelected: onCategoryChanged,
        ),
        if (!isAccountScope)
          _PopupFilterChip<String?>(
            label: _accountLabel(accountId) ?? 'Account',
            active: accountId != null,
            icon: Icons.account_balance_outlined,
            values: [null, ...accounts.map((a) => a.id)],
            labelFor: (value) => _accountLabel(value) ?? 'All accounts',
            onSelected: onAccountChanged,
          ),
        _PopupFilterChip<_TransactionsTimeFilter>(
          label: _timeLabel(timeFilter),
          active: timeFilter != _TransactionsTimeFilter.all,
          icon: Icons.date_range_outlined,
          values: _TransactionsTimeFilter.values,
          labelFor: _timeLabel,
          onSelected: onTimeChanged,
        ),
        _PopupFilterChip<_TransactionsSortMode>(
          label: _sortLabel(sortMode),
          active: sortMode != _TransactionsSortMode.newest,
          icon: Icons.sort_rounded,
          values: _TransactionsSortMode.values,
          labelFor: _sortLabel,
          onSelected: onSortChanged,
        ),
        _PopupFilterChip<FinancialRole?>(
          label: roleFilter == null ? 'Role' : _financialRoleLabel(roleFilter!),
          active: roleFilter != null,
          icon: Icons.account_tree_outlined,
          values: <FinancialRole?>[null, ...FinancialRole.values],
          labelFor: (value) =>
              value == null ? 'All roles' : _financialRoleLabel(value),
          onSelected: onRoleChanged,
        ),
      ],
    );
  }

  String? _accountLabel(String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account.name;
    }
    return null;
  }
}

class _PopupFilterChip<T> extends StatelessWidget {
  const _PopupFilterChip({
    required this.label,
    required this.active,
    required this.icon,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final IconData icon;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem<T>(value: value, child: Text(labelFor(value))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFE4B8) : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD8D1C5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.72)),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

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
            border: Border.all(color: _dashboardOutline),
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
                side: const BorderSide(color: Color(0xFFD8D1C5)),
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
        color: _dashboardPanel,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline),
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
                    account!.name,
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
        color: _dashboardPanel,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline),
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
