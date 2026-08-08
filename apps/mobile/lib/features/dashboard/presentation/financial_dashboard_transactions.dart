part of 'financial_dashboard_view.dart';

enum _TransactionsViewMode { list, months, categories }

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
    required this.scopedTransactions,
    required this.allTransactions,
    required this.accounts,
    required this.controller,
    required this.transactionController,
    required this.scope,
    required this.pagePadding,
    required this.onCategoryTap,
    this.accountController,
    this.onBankSyncCompleted,
  });

  final DashboardSnapshot snapshot;
  final List<Transaction> scopedTransactions;
  final List<Transaction> allTransactions;
  final List<Account> accounts;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final AccountUiController? accountController;
  final VoidCallback? onBankSyncCompleted;
  final DashboardScope scope;
  final EdgeInsets pagePadding;
  final ValueChanged<String> onCategoryTap;

  @override
  State<_DashboardTransactionsSection> createState() =>
      _DashboardTransactionsSectionState();
}

class _DashboardTransactionsSectionState
    extends State<_DashboardTransactionsSection> {
  final _searchController = TextEditingController();
  var _mode = _TransactionsViewMode.list;
  var _timeFilter = _TransactionsTimeFilter.all;
  var _sortMode = _TransactionsSortMode.newest;
  Set<String> _accountIds = {};
  var _refreshing = false;

  bool get _isAccountScope => widget.scope is AccountDashboardScope;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _DashboardTransactionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _accountIds = {};
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshFromBank() async {
    final accounts = widget.accountController;
    if (accounts == null) {
      widget.onBankSyncCompleted?.call();
      return;
    }

    final onlyAccountId = switch (widget.scope) {
      AccountDashboardScope(:final accountId) => accountId,
      GlobalDashboardScope() => null,
    };

    setState(() => _refreshing = true);
    try {
      final result = await refreshConnectedPlaidAccounts(
        accounts: accounts,
        onlyAccountId: onlyAccountId,
      );
      if (!mounted) return;
      // Always reload the read model — CSV-only users still need a refresh.
      widget.onBankSyncCompleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(plaidAccountsRefreshMessage(context.l10n, result)),
        ),
      );
    } on Object {
      if (!mounted) return;
      widget.onBankSyncCompleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountsScreenCouldNotRefreshAccounts),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  int get _activeFilterCount {
    var count = 0;
    // Categories is always locked to the dashboard month — that is not a filter.
    if (_mode != _TransactionsViewMode.categories &&
        _timeFilter != _TransactionsTimeFilter.all) {
      count++;
    }
    if (!_isAccountScope && _accountIds.isNotEmpty) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _accountIds = {};
      _timeFilter = _mode == _TransactionsViewMode.categories
          ? _TransactionsTimeFilter.dashboardMonth
          : _TransactionsTimeFilter.all;
      _searchController.clear();
    });
  }

  List<ResolvedTransaction> get _resolvedTransactions {
    return resolveTransactions(
      widget.scopedTransactions,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: widget.controller.categoryDisplayRenames,
      accountsById: {
        for (final account in widget.accounts) account.id: account,
      },
      allTransactions: widget.allTransactions,
    );
  }

  List<ResolvedTransaction> _filteredTransactions(AppLocalizations l10n) {
    final query = _normalizeSearchText(_searchController.text);
    final range = _activeDateRange;
    final accountsById = {
      for (final account in widget.accounts) account.id: account,
    };
    final filtered = _resolvedTransactions.where((resolved) {
      final t = resolved.transaction;
      if (!_isAccountScope &&
          _accountIds.isNotEmpty &&
          !_accountIds.contains(t.accountId)) {
        return false;
      }
      if (!_matchesTimeFilter(t, range)) return false;
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
    final latest = _latestTransactionDate(widget.scopedTransactions);
    return switch (_timeFilter) {
      _TransactionsTimeFilter.all => null,
      _TransactionsTimeFilter.dashboardMonth => _monthRange(
        widget.snapshot.referenceMonth,
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
      final bounds = _transactionDateBounds(widget.scopedTransactions);
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

  List<MonthlyBankGroup> _monthGroups(AppLocalizations l10n) {
    return monthlyBankGroupsNewestFirstForResolvedTransactions(
      _filteredTransactions(l10n),
    );
  }

  List<DashboardCategoryTransactionGroup> _categoryGroups(
    AppLocalizations l10n,
  ) {
    // Categories always match the dashboard reference month so taps open the
    // same month CategoryDetailScreen shows — not all-history totals.
    final reference = widget.snapshot.referenceMonth;
    final inReferenceMonth = _filteredTransactions(l10n).where((resolved) {
      final date = resolved.transaction.date;
      return date.year == reference.year && date.month == reference.month;
    });
    return spendingCategoryGroupsForResolvedTransactions(inReferenceMonth);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final desktop = isClarityDesktopLayout(context);
    final filtered = _filteredTransactions(l10n);

    return RefreshIndicator(
      onRefresh: _refreshFromBank,
      child: Scrollbar(
        thumbVisibility: desktop,
        child: CustomScrollView(
          physics: desktop
              ? const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                )
              : const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
          slivers: [
            SliverPadding(
              padding: widget.pagePadding.copyWith(bottom: 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sectionSubtitle(filtered.length, l10n),
                            style: theme.textTheme.labelMedium?.copyWith(
                              letterSpacing: 0.6,
                              color: cs.onSurface.withValues(alpha: 0.42),
                              fontWeight: FontWeight.w500,
                            ),
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
                    const SizedBox(height: 12),
                    _TransactionSearchField(controller: _searchController),
                    const SizedBox(height: 12),
                    _InlineFilterBar(
                      accounts: widget.accounts,
                      isAccountScope: _isAccountScope,
                      accountIds: _accountIds,
                      timeFilter: _timeFilter,
                      sortMode: _sortMode,
                      hideTimeFilter: _mode == _TransactionsViewMode.categories,
                      onAccountIdsChanged: (value) =>
                          setState(() => _accountIds = value),
                      onTimeChanged: (value) =>
                          setState(() => _timeFilter = value),
                      onSortChanged: (value) =>
                          setState(() => _sortMode = value),
                    ),
                    const SizedBox(height: 14),
                    _TransactionsModePicker(
                      selected: _mode,
                      onSelected: (mode) => setState(() {
                        _mode = mode;
                        if (mode == _TransactionsViewMode.categories) {
                          _timeFilter = _TransactionsTimeFilter.dashboardMonth;
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_refreshing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: cs.primary,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                    if (_mode == _TransactionsViewMode.months)
                      _MonthlyGroupsList(
                        groups: _monthGroups(l10n),
                        controller: widget.controller,
                        transactionController: widget.transactionController,
                      )
                    else if (_mode == _TransactionsViewMode.categories)
                      _CategoryGroupsList(
                        groups: _categoryGroups(l10n),
                        onCategoryTap: widget.onCategoryTap,
                      ),
                  ],
                ),
              ),
            ),
            if (_mode == _TransactionsViewMode.list)
              _FlatTransactionsSliver(
                transactions: filtered,
                transactionController: widget.transactionController,
                horizontalPadding: widget.pagePadding.left,
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: widget.pagePadding.bottom),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionSubtitle(int filteredCount, AppLocalizations l10n) {
    final dateRangeDescription = _activeDateRangeDescription(l10n);
    if (_activeFilterCount == 0 && _mode == _TransactionsViewMode.months) {
      return l10n.dashboardTransactionsTapMonthHint(dateRangeDescription);
    }
    final count = widget.scopedTransactions.length;
    return l10n.dashboardTransactionsFilteredCount(
      filteredCount,
      count,
      dateRangeDescription,
    );
  }
}
