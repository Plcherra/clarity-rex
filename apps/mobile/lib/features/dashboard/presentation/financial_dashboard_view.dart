import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/layout/clarity_breakpoints.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../core/layout/finance_content_constraints.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/platform/app_capabilities.dart';
import '../../../l10n/app_localizations.dart';
import '../../budgets/domain/budget_models.dart';
import '../../finance/application/financial_read_model_service.dart';
import '../domain/dashboard_snapshot.dart';
import '../domain/dashboard_insight_anchor.dart';
import '../domain/dashboard_transaction_groups.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/models/models.dart';
import '../../accounts/presentation/widgets/connect_bank_setup_card.dart';
import '../../shell/presentation/import_job_progress_banner.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/presentation/widgets/transactions_month_mini_analytics.dart';
import '../../transactions/presentation/widgets/transaction_line_tile.dart';
import '../../transactions/domain/transaction_resolution.dart';
import '../../../theme/clarity_colors.dart';
import '../../../theme/clarity_radius.dart';
import '../../../widgets/clarity_card.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../../../widgets/clarity_path_loader.dart';
import '../domain/savings_snapshot.dart';
import 'category_detail_screen.dart';
import 'month_detail_screen.dart';
import 'charts/finance_charts.dart';

part 'financial_dashboard_transactions.dart';
part 'financial_dashboard_transaction_controls.dart';
part 'financial_dashboard_account_filter.dart';
part 'financial_dashboard_transaction_lists.dart';
part 'financial_dashboard_shell.dart';
part 'financial_dashboard_shell_overview.dart';
part 'financial_dashboard_shell_bodies.dart';
part 'financial_dashboard_summary_sections.dart';
part 'financial_dashboard_savings_row.dart';
part 'financial_dashboard_cards.dart';
part 'financial_dashboard_charts.dart';

const double _cardRadius = ClarityRadius.card;

double _dashboardSectionGap(BuildContext context) {
  return ClarityNativeLayout.sectionGap(context);
}

double _dashboardCardRadiusOf(BuildContext context) {
  return ClarityNativeLayout.active(context)
      ? ClarityNativeLayout.cardRadius(context)
      : _cardRadius;
}

EdgeInsets _dashboardCardPaddingOf(
  BuildContext context,
  EdgeInsets desktop,
) {
  return ClarityNativeLayout.active(context)
      ? ClarityNativeLayout.cardPadding(context)
      : desktop;
}
String _monthShort(AppLocalizations l10n, int month) {
  return switch (month) {
    1 => l10n.commonMonthShortJan,
    2 => l10n.commonMonthShortFeb,
    3 => l10n.commonMonthShortMar,
    4 => l10n.commonMonthShortApr,
    5 => l10n.commonMonthShortMay,
    6 => l10n.commonMonthShortJun,
    7 => l10n.commonMonthShortJul,
    8 => l10n.commonMonthShortAug,
    9 => l10n.commonMonthShortSep,
    10 => l10n.commonMonthShortOct,
    11 => l10n.commonMonthShortNov,
    12 => l10n.commonMonthShortDec,
    _ => l10n.commonMonthShortOld,
  };
}

Color _dashboardPanel(BuildContext context) {
  return context.clarityColors.cardFill;
}

Color _dashboardPanelMuted(BuildContext context) {
  return context.clarityColors.surfaceElevated.withValues(alpha: 0.72);
}

Color _dashboardOutline(BuildContext context) {
  return Colors.transparent;
}

List<BoxShadow> _dashboardShadow() => const [];

Color _dashboardSelected(BuildContext context) {
  return context.clarityColors.accent.withValues(alpha: 0.10);
}

Color _balanceColor(BuildContext context, double v) {
  final colors = context.clarityColors;
  if (v > 0) return colors.financePositive;
  if (v < 0) return colors.financeNegative;
  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
}

String _displayCategory(AppLocalizations l10n, ResolvedTransaction transaction) {
  final category = transaction.displayCategory.trim();
  if (category.isEmpty) return l10n.commonUnknown;
  return category;
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

String _dateLabel(AppLocalizations l10n, DateTime date) {
  return '${_monthShort(l10n, date.month)} ${date.day}, ${date.year}';
}

String _dateRangeLabel(AppLocalizations l10n, DateTimeRange range) {
  if (range.start.year == range.end.year &&
      range.start.month == range.end.month &&
      range.start.day == 1 &&
      range.end.day == DateTime(range.end.year, range.end.month + 1, 0).day) {
    return _yearMonthLabel(range.start);
  }
  return '${_dateLabel(l10n, range.start)} - ${_dateLabel(l10n, range.end)}';
}

String _shortDate(AppLocalizations l10n, DateTime date) {
  return '${_monthShort(l10n, date.month)} ${date.day}';
}

String _normalizeSearchText(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _timeLabel(AppLocalizations l10n, _TransactionsTimeFilter filter) {
  return switch (filter) {
    _TransactionsTimeFilter.all => l10n.dashboardTransactionsTimeFilterAllHistory,
    _TransactionsTimeFilter.dashboardMonth =>
      l10n.dashboardTransactionsTimeFilterDashboardMonth,
    _TransactionsTimeFilter.latestTransactionMonth =>
      l10n.dashboardTransactionsTimeFilterLatestTxMonth,
    _TransactionsTimeFilter.latestTransactionYear =>
      l10n.dashboardTransactionsTimeFilterLatestTxYear,
  };
}

String _sortLabel(AppLocalizations l10n, _TransactionsSortMode mode) {
  return switch (mode) {
    _TransactionsSortMode.newest => l10n.dashboardTransactionsSortNewest,
    _TransactionsSortMode.oldest => l10n.dashboardTransactionsSortOldest,
    _TransactionsSortMode.largest => l10n.dashboardTransactionsSortLargest,
    _TransactionsSortMode.merchant => l10n.dashboardTransactionsSortMerchant,
  };
}

String _financialRoleLabel(AppLocalizations l10n, FinancialRole role) {
  return switch (role) {
    FinancialRole.expense => l10n.commonExpense,
    FinancialRole.income => l10n.commonIncome,
    FinancialRole.transfer => l10n.commonTransfer,
    FinancialRole.creditCardPayment => l10n.commonCreditCardPayment,
    FinancialRole.refund => l10n.commonRefund,
    FinancialRole.adjustment => l10n.commonAdjustment,
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
    this.title = '',
    this.onUploadTransactions,
    this.onDeleteCsvImportBatch,
    this.onDeleteAccount,
    this.onConnectBank,
    this.onImportCsvInstead,
    this.scrollToAnchor,
    this.onScrollToAnchorHandled,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final ImportJobStatusController importJobStatusController;
  final DashboardScope scope;
  final bool showBackButton;
  final String title;

  /// Optional per-account CSV import fallback action.
  final Future<void> Function()? onUploadTransactions;

  /// Optional per-account delete-one-upload action.
  final Future<void> Function()? onDeleteCsvImportBatch;

  /// Optional account-level delete action (shown as a red trash icon in app bar).
  final Future<void> Function()? onDeleteAccount;

  final VoidCallback? onConnectBank;
  final VoidCallback? onImportCsvInstead;
  final DashboardInsightAnchor? scrollToAnchor;
  final VoidCallback? onScrollToAnchorHandled;

  @override
  State<FinancialDashboardView> createState() => _FinancialDashboardViewState();
}

class _FinancialDashboardViewState extends State<FinancialDashboardView> {
  late final _DashboardDataNotifier _dataNotifier;
  var _loadGeneration = 0;
  var _uploadingTransactions = false;

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

  Future<void> _handleUploadTransactions() async {
    final uploadTransactions = widget.onUploadTransactions;
    if (_uploadingTransactions || uploadTransactions == null) return;
    setState(() => _uploadingTransactions = true);
    try {
      await uploadTransactions();
    } finally {
      if (mounted) setState(() => _uploadingTransactions = false);
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
    final l10n = context.l10n;

    Widget constrainBody(Widget child) {
      if (!widget.showBackButton) return child;
      return FinanceContentConstraints(child: child);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: cs.surface,
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
          if (widget.onUploadTransactions != null &&
              AppCapabilities.instance.supportsCsvImport)
            IconButton(
              tooltip: l10n.dashboardOverviewImportCsvTooltip,
              icon: _uploadingTransactions
                  ? const ClarityInlineLoader(size: 19, strokeWidth: 2)
                  : const Icon(Icons.upload_file_rounded),
              color: cs.onSurface.withValues(alpha: 0.72),
              onPressed: _uploadingTransactions
                  ? null
                  : _handleUploadTransactions,
            ),
          if (widget.onDeleteCsvImportBatch != null)
            IconButton(
              tooltip: l10n.dashboardOverviewDeleteCsvUploadTooltip,
              icon: const Icon(Icons.playlist_remove_rounded),
              color: cs.error,
              onPressed: widget.onDeleteCsvImportBatch,
            ),
          if (widget.onDeleteAccount != null)
            IconButton(
              tooltip: l10n.dashboardOverviewDeleteAccountTooltip,
              icon: const Icon(Icons.delete_forever_rounded),
              color: cs.error,
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
              return constrainBody(
                _DashboardLoadMessage(message: '${_dataNotifier.error}'),
              );
            }
            return constrainBody(const _DashboardLoadingBody());
          }
          if (data.isResolvingImportedTransactions && !data.isTrulyEmpty) {
            return constrainBody(const _DashboardResolvingDataBody());
          }
          if (data.isTrulyEmpty &&
              widget.scope is GlobalDashboardScope &&
              widget.onConnectBank != null &&
              widget.onImportCsvInstead != null) {
            return constrainBody(
              _DashboardEmptySetupBody(
                title: widget.title,
                onConnectBank: widget.onConnectBank!,
                onImportCsvInstead: widget.onImportCsvInstead!,
              ),
            );
          }
          final scrollBody = _DashboardScrollBody(
            title: widget.title,
            controller: widget.controller,
            transactionController: widget.transactionController,
            scope: widget.scope,
            snapshot: data.snapshot,
            budgetPerformance: data.budgetPerformance,
            transactionCount: data.scopedTransactionCount,
            loadIssues: data.loadIssues,
            accountCount: data.accountCount,
            scrollToAnchor: widget.scrollToAnchor,
            onScrollToAnchorHandled: widget.onScrollToAnchorHandled,
          );
          final body = widget.showBackButton
              ? ImportJobStatusHost(
                  controller: widget.importJobStatusController,
                  child: scrollBody,
                )
              : scrollBody;
          return constrainBody(body);
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
