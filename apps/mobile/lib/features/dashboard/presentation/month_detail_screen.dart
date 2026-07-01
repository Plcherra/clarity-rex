import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/layout/finance_content_constraints.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../../core/formatting/formatting.dart';
import '../../../theme/clarity_colors.dart';
import '../../../widgets/clarity_diamond_loader.dart';
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
          backgroundColor: cs.surface,
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
                  tooltip: context.l10n.monthDetailDeleteMonthTooltip,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  color: cs.error,
                  onPressed: () async {
                    final monthLabel = formatYearMonthLabel(
                      widget.group.yearMonth,
                    );
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) {
                        final dialogL10n = ctx.l10n;
                        final transactionSuffix = lines.length == 1 ? '' : 's';
                        return AlertDialog(
                          title: Text(
                            dialogL10n.monthDetailDeleteMonthTitle(monthLabel),
                          ),
                          content: Text(
                            dialogL10n.monthDetailDeleteMonthBody(
                              lines.length,
                              transactionSuffix,
                              monthLabel,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(dialogL10n.commonCancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(ctx).colorScheme.error,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(dialogL10n.monthDetailDeleteMonthButton),
                            ),
                          ],
                        );
                      },
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
                              ? context.l10n.monthDetailDeletedTransactions(
                                  deleted,
                                  monthLabel,
                                  deleted == 1 ? '' : 's',
                                )
                              : context.l10n.monthDetailNothingDeleted,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: FinanceContentConstraints(
            child: lines == null
                ? _dataNotifier.error != null
                      ? Center(
                          child: Text(context.l10n.dashboardTransactionsLoadError),
                        )
                      : Center(
                          child: ClarityDiamondLoader(
                            size: 56,
                            label: context.l10n.monthDetailLoadingMonth,
                          ),
                        )
                : _MonthDetailBody(
                    lines: lines,
                    monthDeleteProtectionMessage:
                        monthDeletePolicy?.blockReason ==
                            MonthDeletionBlockReason.plaidSynced
                        ? context.l10n.monthDetailPlaidDeleteProtection
                        : null,
                    controller: widget.controller,
                    transactionController: widget.transactionController,
                    theme: theme,
                    colorScheme: cs,
                  ),
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
    final l10n = context.l10n;
    final monthTotal = lines.fold<double>(
      0,
      (sum, e) => sum + e.transaction.amount,
    );
    final totalColor = monthTotal < 0
        ? ClarityColors.financeNegative
        : monthTotal > 0
        ? ClarityColors.financePositive
        : colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.monthDetailNetThisMonth,
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
                lines.length == 1
                    ? l10n.commonTransactionCountOne
                    : l10n.commonTransactionCount(lines.length),
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
          l10n.dashboardTransactionsSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          ),
          child: lines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 26,
                  ),
                  child: Text(
                    l10n.monthDetailNoTransactionsLeft,
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
        ? ClarityColors.financeNegative
        : ClarityColors.financePositive;

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
                      tooltip: context.l10n.monthDetailDeleteTransactionTooltip,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: cs.error,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            final dialogL10n = ctx.l10n;
                            return AlertDialog(
                              title: Text(
                                dialogL10n.monthDetailDeleteTransactionTitle,
                              ),
                              content: Text(
                                dialogL10n.monthDetailDeleteTransactionBody,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(dialogL10n.commonCancel),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      ctx,
                                    ).colorScheme.error,
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(dialogL10n.commonDelete),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirm != true) return;
                        final deleted = await transactionController
                            .deleteTransaction(tx);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              deleted
                                  ? context.l10n.monthDetailTransactionDeleted
                                  : context
                                        .l10n
                                        .monthDetailDeleteTransactionFailed,
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
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.78)),
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
