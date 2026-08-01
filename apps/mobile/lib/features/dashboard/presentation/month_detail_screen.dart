import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/layout/finance_content_constraints.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../../core/formatting/formatting.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../domain/month_deletion_policy.dart';
import 'month_detail_body.dart';

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
                                backgroundColor: Theme.of(
                                  ctx,
                                ).colorScheme.error,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                dialogL10n.monthDetailDeleteMonthButton,
                              ),
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
                          child: Text(
                            context.l10n.dashboardTransactionsLoadError,
                          ),
                        )
                      : Center(
                          child: ClarityDiamondLoader(
                            size: 56,
                            label: context.l10n.monthDetailLoadingMonth,
                          ),
                        )
                : MonthDetailBody(
                    lines: lines,
                    monthDeleteProtectionMessage:
                        monthDeletePolicy?.blockReason ==
                            MonthDeletionBlockReason.plaidSynced
                        ? context.l10n.monthDetailPlaidDeleteProtection
                        : null,
                    transactionController: widget.transactionController,
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
