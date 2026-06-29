part of 'financial_dashboard_view.dart';

enum _TransactionsViewMode { months, categories }

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

  List<ResolvedTransaction> _filteredTransactions(AppLocalizations l10n) {
    final query = _normalizeSearchText(_searchController.text);
    final range = _activeDateRange;
    final accountsById = {for (final account in _accounts) account.id: account};
    final filtered = _resolvedTransactions.where((resolved) {
      final t = resolved.transaction;
      if (_categoryFilter != null &&
          _displayCategory(l10n, resolved) != _categoryFilter) {
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
      if (query.isNotEmpty &&
          !_matchesSearch(l10n, resolved, query, accountsById)) {
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

  String _activeDateRangeDescription(AppLocalizations l10n) {
    if (_timeFilter == _TransactionsTimeFilter.all) {
      final bounds = _transactionDateBounds(_transactions);
      if (bounds == null) return l10n.dashboardTransactionsNoImportedHistory;
      return l10n.dashboardTransactionsHistoryRange(
        _dateRangeLabel(l10n, bounds),
      );
    }
    final range = _activeDateRange;
    if (range == null) return _timeLabel(l10n, _timeFilter);
    return switch (_timeFilter) {
      _TransactionsTimeFilter.all =>
        l10n.dashboardTransactionsTimeFilterAllHistory,
      _TransactionsTimeFilter.dashboardMonth =>
        l10n.dashboardTransactionsDashboardMonthRange(
          _dateRangeLabel(l10n, range),
        ),
      _TransactionsTimeFilter.latestTransactionMonth =>
        l10n.dashboardTransactionsLatestTxMonthRange(
          _dateRangeLabel(l10n, range),
        ),
      _TransactionsTimeFilter.latestTransactionYear =>
        l10n.dashboardTransactionsLatestTxYearRange(
          _dateRangeLabel(l10n, range),
        ),
    };
  }

  bool _matchesSearch(
    AppLocalizations l10n,
    ResolvedTransaction resolved,
    String query,
    Map<String, Account> accountsById,
  ) {
    final transaction = resolved.transaction;
    final account = accountsById[transaction.accountId];
    final haystack = [
      transaction.description,
      _displayCategory(l10n, resolved),
      _financialRoleLabel(l10n, resolved.financialRole),
      _yearMonthLabel(transaction.date),
      _shortDate(l10n, transaction.date),
      formatMoney(transaction.amount),
      if (account != null) account.displayName,
      if (account?.institution?.trim().isNotEmpty == true)
        account!.institution!,
    ].map(_normalizeSearchText).join(' ');
    return haystack.contains(query);
  }

  List<String> _categoryOptions(AppLocalizations l10n) {
    final names = <String>{};
    for (final transaction in _resolvedTransactions) {
      if (!_isSpendCategoryTransaction(transaction)) continue;
      names.add(_displayCategory(l10n, transaction));
    }
    final unknown = l10n.commonUnknown;
    final sorted = names.toList()
      ..sort((a, b) {
        if (a == unknown) return -1;
        if (b == unknown) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return sorted;
  }

  List<MonthlyBankGroup> _monthGroups(AppLocalizations l10n) {
    return monthlyBankGroupsNewestFirstForResolvedTransactions(
      _filteredTransactions(l10n),
    );
  }

  List<DashboardCategoryTransactionGroup> _categoryGroups(
    AppLocalizations l10n,
  ) {
    return spendingCategoryGroupsForResolvedTransactions(
      _filteredTransactions(l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final filtered = _filteredTransactions(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    theme: theme,
                    title: l10n.dashboardTransactionsSectionTitle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sectionSubtitle(filtered.length, l10n),
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
                label: Text(l10n.dashboardTransactionsClearFilters),
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
          categories: _categoryOptions(l10n),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: ClarityDiamondLoader(
                size: 52,
                label: l10n.dashboardTransactionsLoadingLabel,
              ),
            ),
          )
        else if (_error != null)
          _InlineEmptyState(
            message: l10n.dashboardTransactionsLoadError,
            actionLabel: l10n.commonRetry,
            onAction: _load,
          )
        else
          switch (_mode) {
            _TransactionsViewMode.months => _MonthlyGroupsList(
              groups: _monthGroups(l10n),
              controller: widget.controller,
              transactionController: widget.transactionController,
            ),
            _TransactionsViewMode.categories => _CategoryGroupsList(
              groups: _categoryGroups(l10n),
            ),
          },
      ],
    );
  }

  String _sectionSubtitle(int filteredCount, AppLocalizations l10n) {
    final dateRangeDescription = _activeDateRangeDescription(l10n);
    if (_activeFilterCount == 0 && _mode == _TransactionsViewMode.months) {
      return l10n.dashboardTransactionsTapMonthHint(dateRangeDescription);
    }
    final count = _transactions.length;
    return l10n.dashboardTransactionsFilteredCount(
      filteredCount,
      count,
      dateRangeDescription,
    );
  }
}
