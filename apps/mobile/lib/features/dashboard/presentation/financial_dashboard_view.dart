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

part 'financial_dashboard_transactions.dart';
part 'financial_dashboard_cards.dart';

const double _sectionGap = 28.0;
const double _cardRadius = 18.0;
const Color _dashboardPanel = Color(0xFFFFFEFC);
const Color _dashboardPanelMuted = Color(0xFFF7F5F0);
const Color _dashboardOutline = Color(0xFFE9E3D8);
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

String _financialRoleLabel(FinancialRole role) {
  return switch (role) {
    FinancialRole.expense => 'Expense',
    FinancialRole.income => 'Income',
    FinancialRole.transfer => 'Transfer',
    FinancialRole.creditCardPayment => 'Credit card payment',
    FinancialRole.refund => 'Refund',
    FinancialRole.adjustment => 'Adjustment',
  };
}

class FinancialDashboardView extends StatefulWidget {
  const FinancialDashboardView({
    super.key,
    required this.controller,
    required this.transactionController,
    required this.budgetController,
    required this.importJobStatusController,
    required this.scope,
    this.showBackButton = false,
    this.title = 'Overview',
    this.onUploadTransactions,
    this.onDeleteCsvImportBatch,
    this.onDeleteAccount,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final ImportJobStatusController importJobStatusController;
  final DashboardScope scope;
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
  var _loadGeneration = 0;

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
        oldWidget.scope != widget.scope) {
      _loadData();
    }
  }

  void _handleControllerChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    _dataNotifier.setLoading();
    try {
      final data = await widget.controller.dashboardViewDataForScope(
        widget.scope,
      );
      if (!mounted || generation != _loadGeneration) return;
      _dataNotifier.setData(data);
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
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
          if (data.isResolvingImportedTransactions && !data.isTrulyEmpty) {
            return const _DashboardResolvingDataBody();
          }
          final scrollBody = _DashboardScrollBody(
            title: widget.title,
            controller: widget.controller,
            transactionController: widget.transactionController,
            budgetController: widget.budgetController,
            scope: widget.scope,
            snapshot: data.snapshot,
            budgetPerformance: data.budgetPerformance,
            hasStatementBalance: data.scopedStatementImportCount > 0,
            transactionCount: data.scopedTransactionCount,
            onUploadTransactions: widget.onUploadTransactions,
          );
          return widget.showBackButton
              ? ImportJobStatusHost(
                  controller: widget.importJobStatusController,
                  child: scrollBody,
                )
              : scrollBody;
        },
      ),
    );
  }
}

class _DashboardDataNotifier extends ChangeNotifier {
  DashboardViewData? _data;
  Object? _error;
  var _loading = false;

  DashboardViewData? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  void setLoading() {
    _data = null;
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void setData(DashboardViewData data) {
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

class _DashboardScrollBody extends StatelessWidget {
  const _DashboardScrollBody({
    required this.title,
    required this.controller,
    required this.transactionController,
    required this.budgetController,
    required this.scope,
    required this.snapshot,
    required this.budgetPerformance,
    required this.hasStatementBalance,
    required this.transactionCount,
    required this.onUploadTransactions,
  });

  final String title;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final DashboardScope scope;
  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final bool hasStatementBalance;
  final int transactionCount;
  final Future<void> Function()? onUploadTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFF8F7F4)),
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
                              BudgetsScreen(controller: budgetController),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _CashFlowSummaryCard(
                    snapshot: snapshot,
                    hasStatementBalance: hasStatementBalance,
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Spending pressure'),
                  const SizedBox(height: 16),
                  _BiggestLeaksCard(leaks: snapshot.biggestLeaksThisMonth),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Budget performance'),
                  const SizedBox(height: 16),
                  _BudgetPerformanceCard(performance: budgetPerformance),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Account health'),
                  const SizedBox(height: 16),
                  _AccountHealthCard(
                    snapshot: snapshot,
                    budgetPerformance: budgetPerformance,
                    hasStatementBalance: hasStatementBalance,
                    transactionCount: transactionCount,
                  ),
                  const SizedBox(height: _sectionGap),
                  _DashboardTransactionsSection(
                    snapshot: snapshot,
                    controller: controller,
                    transactionController: transactionController,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 18),
                      Text(
                        'Loading your financial data...',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardResolvingDataBody extends StatelessWidget {
  const _DashboardResolvingDataBody();

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0DCD4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 18),
                    Text(
                      'Resolving imported transactions',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your statement is connected, but the transaction rows are still loading. Values will appear when the read model is complete.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

class _CashFlowSummaryCard extends StatelessWidget {
  const _CashFlowSummaryCard({
    required this.snapshot,
    required this.hasStatementBalance,
  });

  final DashboardSnapshot snapshot;
  final bool hasStatementBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final availableValue = formatMoney(snapshot.availableThisMonth);
    final net = snapshot.availableThisMonth;
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
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final children = [
                _CashFlowSummaryMetric(
                  label: 'Income',
                  value: formatMoney(snapshot.incomeThisMonth),
                  color: const Color(0xFF1B7A4C),
                ),
                _CashFlowSummaryMetric(
                  label: 'Spending',
                  value: formatMoney(snapshot.spentThisMonth),
                  color: const Color(0xFF9B2C2C),
                ),
                _CashFlowSummaryMetric(
                  label: hasStatementBalance ? 'Balance' : 'Net',
                  value: hasStatementBalance
                      ? formatMoney(snapshot.totalBalance)
                      : formatMoney(net),
                  color: hasStatementBalance
                      ? _balanceColor(snapshot.totalBalance)
                      : _balanceColor(net),
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      children[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: children[i]),
                  ],
                ],
              );
            },
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
