import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/finance_content_constraints.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../../budgets/domain/budget_models.dart';
import '../../transactions/domain/bank_statement_monthly.dart';
import '../../transactions/domain/transaction_resolution.dart';
import '../../transactions/presentation/widgets/transaction_line_tile.dart';
import '../domain/category_month_detail.dart';
import '../domain/dashboard_snapshot.dart';
import '../domain/dashboard_transaction_groups.dart';
import 'category_detail_insights.dart';
import 'category_detail_merchants.dart';
import 'category_detail_panel.dart';

/// The transactions and insights behind one bar of a dashboard spending chart.
class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({
    required this.controller,
    required this.transactionController,
    required this.scope,
    required this.category,
    required this.referenceMonth,
    this.budget,
    super.key,
  });

  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final DashboardScope scope;

  /// Display label of the tapped category.
  final String category;

  /// The month the dashboard is showing — the detail must match its bars.
  final DateTime referenceMonth;

  /// Budget line for this category in the same month, when one exists.
  final BudgetCategoryPerformance? budget;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  CategoryMonthDetail? _detail;
  Object? _error;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant CategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.category != widget.category ||
        oldWidget.scope != widget.scope) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() => _load();

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final data = await widget.controller.transactionReadDataForScope(
        widget.scope,
      );
      if (!mounted || generation != _loadGeneration) return;
      final resolved = resolveTransactions(
        data.transactions,
        categoryOverrides: const {},
        categoryDisplayRenamesLower: widget.controller.categoryDisplayRenames,
        merchantCategoryMemory: data.merchantCategoryMemory,
        accountsById: {
          for (final account in data.accounts) account.id: account,
        },
        allTransactions: data.allTransactions,
      );
      setState(() {
        _error = null;
        _detail = buildCategoryMonthDetail(
          resolved: resolved,
          reference: widget.referenceMonth,
          category: widget.category,
        );
      });
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final detail = _detail;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNeedsCategoryGroupKey(widget.category)
                  ? l10n.dashboardNeedsCategoryLabel
                  : widget.category,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              formatYearMonthLabel(yearMonthKey(widget.referenceMonth)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
      body: FinanceContentConstraints(
        child: detail == null
            ? Center(
                child: _error != null
                    ? Text(l10n.dashboardTransactionsLoadError)
                    : ClarityDiamondLoader(
                        size: 56,
                        label: l10n.categoryDetailLoading,
                      ),
              )
            : _CategoryDetailBody(
                detail: detail,
                budget: widget.budget,
                transactionController: widget.transactionController,
              ),
      ),
    );
  }
}

class _CategoryDetailBody extends StatelessWidget {
  const _CategoryDetailBody({
    required this.detail,
    required this.budget,
    required this.transactionController,
  });

  final CategoryMonthDetail detail;
  final BudgetCategoryPerformance? budget;
  final TransactionUiController transactionController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        CategoryDetailSummaryCard(detail: detail, budget: budget),
        const SizedBox(height: 18),
        if (detail.merchants.isEmpty)
          CategoryDetailPanel(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            child: Text(
              l10n.categoryDetailNoTransactions,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          CategoryDetailMerchants(
            detail: detail,
            buildTransactionRow: (row) => DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: TransactionLineTile(
                transaction: row.transaction,
                displayCategory: row.displayCategory,
                transactionController: transactionController,
                horizontalPadding: 0,
              ),
            ),
          ),
      ],
    );
  }
}
