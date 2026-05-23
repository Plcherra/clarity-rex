import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../budgets/domain/budget_models.dart';
import '../domain/dashboard_snapshot.dart';
import '../domain/dashboard_transaction_groups.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/models/models.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../shell/presentation/import_job_progress_banner.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/spend_categories.dart';
import '../../transactions/domain/transaction_resolution.dart';
import '../../transactions/presentation/widgets/transaction_category_dropdown.dart';
import 'month_detail_screen.dart';

typedef SnapshotBuilder =
    Future<DashboardSnapshot> Function(
      DashboardUiController controller,
      DashboardScope scope,
    );

const double _sectionGap = 32.0;
const List<String> _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Color _balanceColor(double v) {
  if (v > 0) return const Color(0xFF1B7A4C);
  if (v < 0) return const Color(0xFFC41E3A);
  return const Color(0xFF3A3A38);
}

String _displayCategory(ResolvedTransaction transaction) {
  final category = transaction.displayCategory.trim();
  if (category.isEmpty) return 'Unknown';
  return category;
}

bool _isSpendCategoryTransaction(ResolvedTransaction transaction) {
  final category = _displayCategory(transaction);
  if (isUnresolvedCategoryLabel(category) ||
      isIncomeCategoryLabel(category) ||
      isIgnoredCategoryLabel(category)) {
    return false;
  }
  return transaction.countsAsSpend;
}

DateTime? _latestTransactionDate(List<Transaction> transactions) {
  DateTime? latest;
  for (final transaction in transactions) {
    if (latest == null || transaction.date.isAfter(latest)) {
      latest = transaction.date;
    }
  }
  return latest;
}

DateTimeRange? _transactionDateBounds(List<Transaction> transactions) {
  DateTime? earliest;
  DateTime? latest;
  for (final transaction in transactions) {
    final date = transaction.date;
    if (earliest == null || date.isBefore(earliest)) earliest = date;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  if (earliest == null || latest == null) return null;
  return DateTimeRange(start: earliest, end: latest);
}

DateTimeRange _monthRange(DateTime date) {
  return DateTimeRange(
    start: DateTime(date.year, date.month),
    end: DateTime(date.year, date.month + 1, 0),
  );
}

String _yearMonthLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return formatYearMonthLabel('${date.year}-$month');
}

String _dateLabel(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}, ${date.year}';
}

String _dateRangeLabel(DateTimeRange range) {
  if (range.start.year == range.end.year &&
      range.start.month == range.end.month &&
      range.start.day == 1 &&
      range.end.day == DateTime(range.end.year, range.end.month + 1, 0).day) {
    return _yearMonthLabel(range.start);
  }
  return '${_dateLabel(range.start)} - ${_dateLabel(range.end)}';
}

String _shortDate(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}';
}

String _normalizeSearchText(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _timeLabel(_TransactionsTimeFilter filter) {
  return switch (filter) {
    _TransactionsTimeFilter.all => 'All history',
    _TransactionsTimeFilter.dashboardMonth => 'Dashboard month',
    _TransactionsTimeFilter.latestTransactionMonth => 'Latest tx month',
    _TransactionsTimeFilter.latestTransactionYear => 'Latest tx year',
  };
}

String _sortLabel(_TransactionsSortMode mode) {
  return switch (mode) {
    _TransactionsSortMode.newest => 'Newest',
    _TransactionsSortMode.oldest => 'Oldest',
    _TransactionsSortMode.largest => 'Largest',
    _TransactionsSortMode.merchant => 'Merchant A-Z',
  };
}

class FinancialDashboardView extends StatefulWidget {
  const FinancialDashboardView({
    super.key,
    required this.controller,
    required this.scope,
    required this.buildSnapshot,
    this.showBackButton = false,
    this.title = 'Overview',
    this.onUploadTransactions,
    this.onDeleteCsvImportBatch,
    this.onDeleteAccount,
  });

  final DashboardUiController controller;
  final DashboardScope scope;
  final SnapshotBuilder buildSnapshot;
  final bool showBackButton;
  final String title;

  /// When set (per-account dashboard only), shows a prominent CSV import control.
  final Future<void> Function()? onUploadTransactions;

  /// Optional per-account delete-one-upload action.
  final Future<void> Function()? onDeleteCsvImportBatch;

  /// Optional account-level delete action (shown as a red trash icon in app bar).
  final Future<void> Function()? onDeleteAccount;

  @override
  State<FinancialDashboardView> createState() => _FinancialDashboardViewState();
}

class _FinancialDashboardViewState extends State<FinancialDashboardView> {
  late final _DashboardDataNotifier _dataNotifier;

  @override
  void initState() {
    super.initState();
    _dataNotifier = _DashboardDataNotifier();
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant FinancialDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.scope != widget.scope ||
        oldWidget.buildSnapshot != widget.buildSnapshot) {
      _loadData();
    }
  }

  void _handleControllerChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    _dataNotifier.setLoading();
    try {
      final snap = await widget.buildSnapshot(widget.controller, widget.scope);
      final budgetPerformance = await widget.controller
          .budgetPerformanceForScope(widget.scope);
      if (!mounted) return;
      _dataNotifier.setData(
        _FinancialDashboardData(
          snapshot: snap,
          budgetPerformance: budgetPerformance,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      _dataNotifier.setError(error);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (widget.onDeleteCsvImportBatch != null)
            IconButton(
              tooltip: 'Delete CSV upload',
              icon: const Icon(Icons.playlist_remove_rounded),
              color: Colors.red.shade500,
              onPressed: widget.onDeleteCsvImportBatch,
            ),
          if (widget.onDeleteAccount != null)
            IconButton(
              tooltip: 'Delete account',
              icon: const Icon(Icons.delete_forever_rounded),
              color: Colors.red.shade700,
              onPressed: widget.onDeleteAccount,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _dataNotifier,
        builder: (context, _) {
          final data = _dataNotifier.data;
          if (data == null) {
            if (_dataNotifier.error != null) {
              return _DashboardLoadMessage(message: '${_dataNotifier.error}');
            }
            return const _DashboardLoadingBody();
          }
          final scrollBody = _DashboardScrollBody(
            title: widget.title,
            controller: widget.controller,
            scope: widget.scope,
            snapshot: data.snapshot,
            budgetPerformance: data.budgetPerformance,
            onUploadTransactions: widget.onUploadTransactions,
          );
          return widget.showBackButton
              ? ImportJobStatusHost(
                  controller: widget.controller.ui.importJobStatus,
                  child: scrollBody,
                )
              : scrollBody;
        },
      ),
    );
  }
}

class _DashboardDataNotifier extends ChangeNotifier {
  _FinancialDashboardData? _data;
  Object? _error;
  var _loading = false;

  _FinancialDashboardData? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  void setLoading() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void setData(_FinancialDashboardData data) {
    _data = data;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void setError(Object error) {
    _error = error;
    _loading = false;
    notifyListeners();
  }
}

class _FinancialDashboardData {
  const _FinancialDashboardData({
    required this.snapshot,
    required this.budgetPerformance,
  });

  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
}

class _DashboardScrollBody extends StatelessWidget {
  const _DashboardScrollBody({
    required this.title,
    required this.controller,
    required this.scope,
    required this.snapshot,
    required this.budgetPerformance,
    required this.onUploadTransactions,
  });

  final String title;
  final DashboardUiController controller;
  final DashboardScope scope;
  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final Future<void> Function()? onUploadTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFF3F1ED), cs.surface],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 3.2,
                      color: cs.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DashboardActionRow(
                    onUploadTransactions: onUploadTransactions,
                    onOpenBudgets: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              BudgetsScreen(controller: controller.ui.budgets),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _ResponsiveMetricCard(
                    label: 'Available this month',
                    value: formatMoney(snapshot.availableThisMonth),
                    large: true,
                    valueColor: _balanceColor(snapshot.availableThisMonth),
                    footnote:
                        'Income ${formatMoney(snapshot.incomeThisMonth)} · '
                        'Spending ${formatMoney(snapshot.spentThisMonth)}',
                  ),
                  const SizedBox(height: _sectionGap),
                  _ResponsiveMetricCard(
                    label: 'Spent this month',
                    value: formatMoney(snapshot.spentThisMonth),
                    large: false,
                    valueColor: const Color(0xFF9B2C2C),
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Budget performance'),
                  const SizedBox(height: 16),
                  _BudgetPerformanceCard(performance: budgetPerformance),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(
                    theme: theme,
                    title: 'Biggest leaks this month',
                  ),
                  const SizedBox(height: 16),
                  _BiggestLeaksCard(leaks: snapshot.biggestLeaksThisMonth),
                  const SizedBox(height: _sectionGap),
                  _BurnRateCard(
                    runwayDays: snapshot.burnRunwayDays,
                    totalBalance: snapshot.totalBalance,
                    spentThisMonth: snapshot.spentThisMonth,
                  ),
                  const SizedBox(height: _sectionGap),
                  _DashboardTransactionsSection(
                    snapshot: snapshot,
                    controller: controller,
                    scope: scope,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingBody extends StatelessWidget {
  const _DashboardLoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _DashboardLoadMessage extends StatelessWidget {
  const _DashboardLoadMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DashboardActionRow extends StatelessWidget {
  const _DashboardActionRow({
    required this.onUploadTransactions,
    required this.onOpenBudgets,
  });

  final Future<void> Function()? onUploadTransactions;
  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (onUploadTransactions != null)
          _CompactUploadButton(onPressed: onUploadTransactions!),
        OutlinedButton.icon(
          onPressed: onOpenBudgets,
          icon: const Icon(Icons.savings_outlined, size: 18),
          label: const Text('Budgets'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );
  }
}

class _CompactUploadButton extends StatefulWidget {
  const _CompactUploadButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State<_CompactUploadButton> createState() => _CompactUploadButtonState();
}

class _CompactUploadButtonState extends State<_CompactUploadButton> {
  var _busy = false;

  Future<void> _handleTap() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: _busy ? null : _handleTap,
      icon: _busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
          : const Icon(Icons.upload_file_rounded, size: 18),
      label: Text(_busy ? 'Uploading...' : 'Upload CSV'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

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
    required this.scope,
  });

  final DashboardSnapshot snapshot;
  final DashboardUiController controller;
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
  List<Transaction> _transactions = const [];
  List<Transaction> _allTransactions = const [];
  List<Account> _accounts = const [];
  Object? _error;
  var _loading = true;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transactions = await widget.controller
          .transactionsForDashboardScope(widget.scope);
      final allTransactions = _isAccountScope
          ? await widget.controller.fetchTransactions()
          : transactions;
      final accounts = await widget.controller.fetchAccounts();
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _allTransactions = allTransactions;
        _accounts = accounts;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
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
    if (!_isAccountScope && _accountFilter != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _accountFilter = null;
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
          onCategoryChanged: (value) => setState(() => _categoryFilter = value),
          onAccountChanged: (value) => setState(() => _accountFilter = value),
          onTimeChanged: (value) => setState(() => _timeFilter = value),
          onSortChanged: (value) => setState(() => _sortMode = value),
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
              controller: widget.controller.ui.transactions,
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
      return 'Tap a month to review transactions | $_activeDateRangeDescription';
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
          borderSide: const BorderSide(color: Color(0xFFE4E0D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE4E0D8)),
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
    required this.onCategoryChanged,
    required this.onAccountChanged,
    required this.onTimeChanged,
    required this.onSortChanged,
  });

  final List<String> categories;
  final List<Account> accounts;
  final bool isAccountScope;
  final String? category;
  final String? accountId;
  final _TransactionsTimeFilter timeFilter;
  final _TransactionsSortMode sortMode;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<_TransactionsTimeFilter> onTimeChanged;
  final ValueChanged<_TransactionsSortMode> onSortChanged;

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
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4E0D8)),
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
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E0D8)),
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
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E0D8)),
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

class _BiggestLeaksCard extends StatelessWidget {
  const _BiggestLeaksCard({required this.leaks});

  final List<CategoryLeakStat> leaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (leaks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Text(
          'No spending this month.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < leaks.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            _LeakRow(stat: leaks[i]),
          ],
        ],
      ),
    );
  }
}

class _BudgetPerformanceCard extends StatelessWidget {
  const _BudgetPerformanceCard({required this.performance});

  final BudgetPerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (performance.budgetedCategoryCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE4E0D8)),
        ),
        child: Text(
          'No budgets set for ${performance.periodLabel} yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.58),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            performance.periodLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${performance.onTrackCategoryCount}/${performance.budgetedCategoryCount} categories on track',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total overspent ${formatMoney(performance.totalOverspent)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: performance.totalOverspent > 0
                  ? const Color(0xFFC41E3A)
                  : const Color(0xFF1B7A4C),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Budgeted ${formatMoney(performance.totalBudgeted)} · Spent ${formatMoney(performance.totalSpent)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 14),
          if (performance.topOverspendingCategories.isEmpty)
            Text(
              'No overspending categories in this period.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.58),
              ),
            )
          else
            for (final row in performance.topOverspendingCategories) ...[
              Text(
                '${row.displayLabel}: overspent ${formatMoney(row.overspent)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC41E3A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
        ],
      ),
    );
  }
}

class _LeakRow extends StatelessWidget {
  const _LeakRow({required this.stat});

  final CategoryLeakStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = stat.percentChangeFromLastMonth;
    final goodTrend = pct != null && pct < 0;
    final badTrend = pct != null && pct > 0;
    final trendColor = goodTrend
        ? const Color(0xFF1B7A4C)
        : badTrend
        ? const Color(0xFFC41E3A)
        : cs.onSurface.withValues(alpha: 0.4);

    Widget trendWidget;
    if (pct == null && stat.amountLastMonth <= 0 && stat.amountThisMonth > 0) {
      trendWidget = Text(
        'New',
        style: theme.textTheme.labelMedium?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (pct == null) {
      trendWidget = Text(
        '—',
        style: theme.textTheme.labelLarge?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.35),
        ),
      );
    } else {
      final pctLabel =
          '${pct >= 0 ? '+' : ''}${(pct * 100).abs().toStringAsFixed(0)}%';
      trendWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pct >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 18,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            pctLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            stat.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(stat.amountThisMonth),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 4),
            trendWidget,
          ],
        ),
      ],
    );
  }
}

class _BurnRateCard extends StatelessWidget {
  const _BurnRateCard({
    required this.runwayDays,
    required this.totalBalance,
    required this.spentThisMonth,
  });

  final int? runwayDays;
  final double totalBalance;
  final double spentThisMonth;

  String _message() {
    if (runwayDays != null) {
      final x = runwayDays!;
      return "You're burning through money at a rate that will last you $x more day${x == 1 ? '' : 's'}.";
    }
    if (totalBalance <= 0) {
      return 'With no positive balance, runway cannot be estimated from this pace.';
    }
    if (spentThisMonth <= 0) {
      return 'No spending recorded yet this month to estimate burn rate.';
    }
    return 'Not enough data to estimate how long your balance will last.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0DCD4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            color: cs.onSurface.withValues(alpha: 0.45),
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _message(),
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyGroupsList extends StatelessWidget {
  const _MonthlyGroupsList({required this.groups, required this.controller});

  final List<MonthlyBankGroup> groups;
  final DashboardUiController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE4E0D8)),
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
          _MonthCard(group: groups[i], controller: controller),
        ],
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.group, required this.controller});

  final MonthlyBankGroup group;
  final DashboardUiController controller;

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
              builder: (context) =>
                  MonthDetailScreen(controller: controller, group: group),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4E0D8)),
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
                          letterSpacing: -0.2,
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
                        letterSpacing: -0.4,
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
        letterSpacing: -0.2,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
      ),
    );
  }
}

class _ResponsiveMetricCard extends StatelessWidget {
  const _ResponsiveMetricCard({
    required this.label,
    required this.value,
    required this.large,
    this.valueColor,
    this.footnote,
  });

  final String label;
  final String value;
  final bool large;
  final Color? valueColor;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = valueColor ?? cs.onSurface;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final valueSize = large
            ? (w * 0.15).clamp(34.0, 72.0)
            : (w * 0.12).clamp(30.0, 58.0);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: w >= 380 ? 28 : 20,
            vertical: large ? 32 : 28,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE0DCD4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 2.6,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.36),
                ),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -2,
                    height: 1.02,
                    color: color,
                    fontSize: valueSize,
                  ),
                ),
              ),
              if (footnote != null) ...[
                const SizedBox(height: 12),
                Text(
                  footnote!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.42),
                    letterSpacing: 0.2,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
