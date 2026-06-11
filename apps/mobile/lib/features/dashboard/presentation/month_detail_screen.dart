import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../../core/formatting/formatting.dart';
import '../../transactions/presentation/widgets/transaction_category_dropdown.dart';
import '../domain/month_deletion_policy.dart';

class MonthDetailScreen extends StatefulWidget {
  const MonthDetailScreen({
    super.key,
    required this.controller,
    required this.transactionController,
    required this.group,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;

  /// Month block from the same [DashboardSnapshot.monthlyGroups] list the user tapped.
  final MonthlyBankGroup group;

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  late final _MonthDetailDataNotifier _dataNotifier;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _dataNotifier = _MonthDetailDataNotifier();
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MonthDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.group != widget.group) {
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    _dataNotifier.setLoading();
    try {
      final lines = await widget.controller.refreshedLinesForMonth(
        widget.group,
      );
      if (!mounted || generation != _loadGeneration) return;
      _dataNotifier.setData(lines);
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _dataNotifier.setError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListenableBuilder(
      listenable: _dataNotifier,
      builder: (context, _) {
        final title = formatYearMonthLabel(widget.group.yearMonth);
        final lines = _dataNotifier.data;
        final monthDeletePolicy = lines == null
            ? null
            : monthDeletionPolicyForLines(lines);
        final monthDeleteAccountId = monthDeletePolicy?.accountId;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F5F2),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(title),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (monthDeleteAccountId != null &&
                  lines != null &&
                  lines.isNotEmpty)
                IconButton(
                  tooltip: 'Delete this month',
                  icon: const Icon(Icons.delete_sweep_rounded),
                  color: Colors.red.shade700,
                  onPressed: () async {
                    final monthLabel = formatYearMonthLabel(
                      widget.group.yearMonth,
                    );
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete $monthLabel transactions?'),
                        content: Text(
                          'This will permanently delete the ${lines.length} visible transaction${lines.length == 1 ? '' : 's'} for this account in $monthLabel. Other months will stay untouched.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete month'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    final deleted = await widget.controller
                        .deleteTransactionsForAccountMonth(
                          accountId: monthDeleteAccountId,
                          yearMonth: widget.group.yearMonth,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          deleted > 0
                              ? 'Deleted $deleted $monthLabel transaction${deleted == 1 ? '' : 's'}.'
                              : 'No transactions were deleted.',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: lines == null
              ? _dataNotifier.error != null
                    ? const Center(child: Text('Could not load transactions.'))
                    : const Center(child: CircularProgressIndicator())
              : _MonthDetailBody(
                  lines: lines,
                  monthDeleteProtectionMessage:
                      monthDeletePolicy?.protectionMessage,
                  controller: widget.controller,
                  transactionController: widget.transactionController,
                  theme: theme,
                  colorScheme: cs,
                ),
        );
      },
    );
  }
}

class _MonthDetailDataNotifier extends ChangeNotifier {
  List<BankStatementLine>? _data;
  Object? _error;
  var _loading = false;

  List<BankStatementLine>? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  void setLoading() {
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void setData(List<BankStatementLine> data) {
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

class _MonthDetailBody extends StatelessWidget {
  const _MonthDetailBody({
    required this.lines,
    required this.monthDeleteProtectionMessage,
    required this.controller,
    required this.transactionController,
    required this.theme,
    required this.colorScheme,
  });

  final List<BankStatementLine> lines;
  final String? monthDeleteProtectionMessage;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final monthTotal = lines.fold<double>(
      0,
      (sum, e) => sum + e.transaction.amount,
    );
    final totalColor = monthTotal < 0
        ? const Color(0xFFC41E3A)
        : monthTotal > 0
        ? const Color(0xFF1B7A4C)
        : colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0DCD4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NET THIS MONTH',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatMoney(monthTotal),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: totalColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${lines.length} transactions',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (monthDeleteProtectionMessage case final message?) ...[
          _PlaidDeleteProtectionNotice(message: message),
          const SizedBox(height: 18),
        ],
        Text(
          'Transactions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4E0D8)),
          ),
          child: lines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 26,
                  ),
                  child: Text(
                    'No transactions left for this month.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      _LineTile(
                        line: lines[i],
                        transactionController: transactionController,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.transactionController});

  final BankStatementLine line;
  final TransactionUiController transactionController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tx = line.transaction;
    final muted = cs.onSurface.withValues(alpha: 0.42);
    final amountColor = tx.amount < 0
        ? const Color(0xFFC41E3A)
        : const Color(0xFF1B7A4C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  formatShortDate(tx.date),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: muted,
                    height: 1.35,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TransactionCategoryField(
                      controller: transactionController,
                      transaction: tx,
                      displayCategory: line.suggestedCategory,
                    ),
                    const SizedBox(height: 6),
                    TransactionRoleField(
                      controller: transactionController,
                      transaction: tx,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(tx.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                  if (!tx.isPlaid)
                    IconButton(
                      tooltip: 'Delete transaction',
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: Colors.red.shade700,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this transaction?'),
                            content: const Text(
                              'This transaction will be permanently deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final deleted = await transactionController
                            .deleteTransaction(tx);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              deleted
                                  ? 'Transaction deleted.'
                                  : 'Could not delete transaction.',
                            ),
                          ),
                        );
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaidDeleteProtectionNotice extends StatelessWidget {
  const _PlaidDeleteProtectionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E0D8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.52),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.62),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
