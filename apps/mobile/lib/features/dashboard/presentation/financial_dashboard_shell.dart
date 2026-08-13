part of 'financial_dashboard_view.dart';

class _DashboardScrollBody extends StatefulWidget {
  const _DashboardScrollBody({
    required this.title,
    required this.controller,
    required this.transactionController,
    required this.scope,
    required this.snapshot,
    required this.scopedTransactions,
    required this.allTransactions,
    required this.accounts,
    required this.budgetPerformance,
    required this.transactionCount,
    required this.loadIssues,
    required this.accountCount,
    this.merchantCategoryMemory = const {},
    this.accountController,
    this.onBankSyncCompleted,
    this.scrollToAnchor,
    this.onScrollToAnchorHandled,
  });

  final String title;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final AccountUiController? accountController;
  final VoidCallback? onBankSyncCompleted;
  final DashboardScope scope;
  final DashboardSnapshot snapshot;
  final List<Transaction> scopedTransactions;
  final List<Transaction> allTransactions;
  final List<Account> accounts;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int transactionCount;
  final List<FinancialReadModelLoadIssue> loadIssues;
  final int accountCount;
  final Map<String, String> merchantCategoryMemory;
  final DashboardInsightAnchor? scrollToAnchor;
  final VoidCallback? onScrollToAnchorHandled;

  @override
  State<_DashboardScrollBody> createState() => _DashboardScrollBodyState();
}

class _DashboardScrollBodyState extends State<_DashboardScrollBody> {
  final _monthlyCashFlowKey = GlobalKey();
  final _spendingPressureKey = GlobalKey();
  final _budgetPerformanceKey = GlobalKey();
  final _coreChartsController = ExpansibleController();
  var _surface = _DashboardSurface.overview;

  @override
  void initState() {
    super.initState();
    _maybeScrollToPendingAnchor();
  }

  @override
  void didUpdateWidget(covariant _DashboardScrollBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToAnchor != oldWidget.scrollToAnchor &&
        widget.scrollToAnchor != null) {
      _maybeScrollToPendingAnchor();
    }
  }

  void _maybeScrollToPendingAnchor() {
    final anchor = widget.scrollToAnchor;
    if (anchor == null) {
      return;
    }
    if (_surface != _DashboardSurface.overview) {
      setState(() => _surface = _DashboardSurface.overview);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToInsightAnchor(anchor);
      widget.onScrollToAnchorHandled?.call();
    });
  }

  @override
  void dispose() {
    _coreChartsController.dispose();
    super.dispose();
  }

  void _openCategoryDetail(String category) {
    final detailCategory = isUnresolvedCategoryLabel(category)
        ? kNeedsCategoryGroupKey
        : category;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CategoryDetailScreen(
          controller: widget.controller,
          transactionController: widget.transactionController,
          scope: widget.scope,
          category: detailCategory,
          referenceMonth: widget.snapshot.referenceMonth,
          budget: _budgetForCategory(detailCategory),
        ),
      ),
    );
  }

  BudgetCategoryPerformance? _budgetForCategory(String category) {
    final normalized = category.trim().toLowerCase();
    for (final entry in widget.budgetPerformance.categories) {
      if (entry.displayLabel.trim().toLowerCase() == normalized) return entry;
    }
    return null;
  }

  void _scrollToInsightAnchor(DashboardInsightAnchor anchor) {
    final key = switch (anchor) {
      DashboardInsightAnchor.connectedAccounts => null,
      DashboardInsightAnchor.monthlyCashFlow => _monthlyCashFlowKey,
      DashboardInsightAnchor.spendingPressure => _spendingPressureKey,
      DashboardInsightAnchor.budgetPerformance => _budgetPerformanceKey,
    };
    if (key == null) {
      return;
    }

    final desktopExpanded = isClarityDesktopLayout(context);
    if (!desktopExpanded) {
      if (anchor == DashboardInsightAnchor.monthlyCashFlow &&
          !_coreChartsController.isExpanded) {
        _coreChartsController.expand();
      }
      if (anchor == DashboardInsightAnchor.spendingPressure &&
          !_coreChartsController.isExpanded) {
        _coreChartsController.expand();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = key.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final native = ClarityNativeLayout.active(context);
    final desktop = isClarityDesktopLayout(context);
    final wide = isClarityWideLayout(context);
    final sectionGap = _dashboardSectionGap(context);
    final pagePad = native
        ? ClarityNativeLayout.pagePadding(context, bottom: 40)
        : EdgeInsets.fromLTRB(desktop ? 24 : 16, 0, desktop ? 24 : 16, 40);

    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                pagePad.left,
                pagePad.top + (native ? 0 : 2),
                pagePad.right,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.title.trim().isNotEmpty) ...[
                    Text(
                      widget.title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 2.4,
                        color: cs.onSurface.withValues(alpha: 0.38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.loadIssues.isNotEmpty) ...[
                    _FinancialDataStatusBanner(loadIssues: widget.loadIssues),
                    SizedBox(height: native ? sectionGap : 14),
                  ],
                  _DashboardSurfaceSwitch(
                    selected: _surface,
                    onSelected: (surface) =>
                        setState(() => _surface = surface),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Expanded(
              child: _surface == _DashboardSurface.overview
                  ? Scrollbar(
                      thumbVisibility: desktop,
                      child: CustomScrollView(
                        physics: desktop
                            ? const ClampingScrollPhysics()
                            : const BouncingScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: pagePad.copyWith(top: 0),
                            sliver: SliverToBoxAdapter(
                              child: _DashboardOverviewBody(
                                snapshot: widget.snapshot,
                                budgetPerformance: widget.budgetPerformance,
                                transactionCount: widget.transactionCount,
                                accountCount: widget.accountCount,
                                scope: widget.scope,
                                sectionGap: sectionGap,
                                wide: wide,
                                desktop: desktop,
                                monthlyCashFlowKey: _monthlyCashFlowKey,
                                spendingPressureKey: _spendingPressureKey,
                                budgetPerformanceKey: _budgetPerformanceKey,
                                coreChartsController: _coreChartsController,
                                onCategoryTap: _openCategoryDetail,
                                availableYearMonths: dashboardAvailableYearMonths(
                                  transactionDates: widget.scopedTransactions
                                      .map((transaction) => transaction.date),
                                ),
                                onMonthSelected:
                                    widget.controller.setSpendReference,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _DashboardTransactionsSection(
                      snapshot: widget.snapshot,
                      scopedTransactions: widget.scopedTransactions,
                      allTransactions: widget.allTransactions,
                      accounts: widget.accounts,
                      merchantCategoryMemory: widget.merchantCategoryMemory,
                      controller: widget.controller,
                      transactionController: widget.transactionController,
                      accountController: widget.accountController,
                      onBankSyncCompleted: widget.onBankSyncCompleted,
                      scope: widget.scope,
                      pagePadding: pagePad.copyWith(top: 0),
                      onCategoryTap: _openCategoryDetail,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
