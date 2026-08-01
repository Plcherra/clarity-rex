part of 'financial_dashboard_view.dart';

class _DashboardScrollBody extends StatefulWidget {
  const _DashboardScrollBody({
    required this.title,
    required this.controller,
    required this.transactionController,
    required this.scope,
    required this.snapshot,
    required this.budgetPerformance,
    required this.transactionCount,
    required this.loadIssues,
    required this.accountCount,
    this.scrollToAnchor,
    this.onScrollToAnchorHandled,
  });

  final String title;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final DashboardScope scope;
  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int transactionCount;
  final List<FinancialReadModelLoadIssue> loadIssues;
  final int accountCount;
  final DashboardInsightAnchor? scrollToAnchor;
  final VoidCallback? onScrollToAnchorHandled;

  @override
  State<_DashboardScrollBody> createState() => _DashboardScrollBodyState();
}

class _DashboardScrollBodyState extends State<_DashboardScrollBody> {
  final _monthlyCashFlowKey = GlobalKey();
  final _spendingPressureKey = GlobalKey();
  final _budgetPerformanceKey = GlobalKey();
  final _coreChartsController = ExpansionTileController();
  final _spendingAnalysisController = ExpansionTileController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToInsightAnchor(anchor);
      widget.onScrollToAnchorHandled?.call();
    });
  }

  @override
  void dispose() {
    _coreChartsController.dispose();
    _spendingAnalysisController.dispose();
    super.dispose();
  }

  void _openCategoryDetail(String category) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CategoryDetailScreen(
          controller: widget.controller,
          transactionController: widget.transactionController,
          scope: widget.scope,
          category: category,
          referenceMonth: widget.snapshot.referenceMonth,
          budget: _budgetForCategory(category),
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
          !_spendingAnalysisController.isExpanded) {
        _spendingAnalysisController.expand();
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
    final l10n = context.l10n;
    final snapshot = widget.snapshot;
    final budgetPerformance = widget.budgetPerformance;
    final wide = isClarityWideLayout(context);
    final desktop = isClarityDesktopLayout(context);
    final native = ClarityNativeLayout.active(context);
    final sectionGap = _dashboardSectionGap(context);
    final pagePad = native
        ? ClarityNativeLayout.pagePadding(context, bottom: 40)
        : EdgeInsets.fromLTRB(desktop ? 24 : 16, 0, desktop ? 24 : 16, 40);
    final overviewCard = _FinancialOverviewCard(
      snapshot: snapshot,
      isGlobalScope: widget.scope is GlobalDashboardScope,
      accountCount: widget.scope is GlobalDashboardScope
          ? widget.accountCount
          : null,
    );
    // Finance charts already surface spending pressure; companion insights live
    // under Assistant Overview.
    final cashFlowChart = _DashboardChartSection(
      sectionKey: _monthlyCashFlowKey,
      title: l10n.dashboardOverviewMonthlyCashFlow,
      child: MonthlyCashFlowChart(months: snapshot.monthlyCashFlow),
    );
    final categoryChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSpendingByCategory,
      subtitle: l10n.dashboardChartCategorySpendSubtitle,
      child: CategorySpendChart(
        categories: snapshot.topCategories,
        onCategoryTap: _openCategoryDetail,
      ),
    );
    final trendChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSixMonthTrend,
      child: SpendTrendChart(months: snapshot.monthlyCashFlow),
    );
    final pressureChart = _DashboardChartSection(
      sectionKey: _spendingPressureKey,
      title: l10n.dashboardOverviewSpendingPressure,
      subtitle: l10n.dashboardChartSpendingPressureSubtitle,
      child: BiggestLeaksChart(
        leaks: snapshot.biggestLeaksThisMonth,
        onCategoryTap: _openCategoryDetail,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface),
      child: SafeArea(
        child: Scrollbar(
          thumbVisibility: desktop,
          child: CustomScrollView(
            physics: desktop
                ? const ClampingScrollPhysics()
                : const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: pagePad,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
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
                    if (widget.title.trim().isEmpty) const SizedBox(height: 2),
                    if (widget.loadIssues.isNotEmpty) ...[
                      _FinancialDataStatusBanner(loadIssues: widget.loadIssues),
                      SizedBox(height: native ? sectionGap : 14),
                    ],
                    overviewCard,
                    SizedBox(height: sectionGap),
                    if (wide) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cashFlowChart),
                          const SizedBox(width: 16),
                          Expanded(child: categoryChart),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: trendChart),
                          const SizedBox(width: 16),
                          Expanded(child: pressureChart),
                        ],
                      ),
                    ] else ...[
                      _DashboardCollapsibleChartGroup(
                        title: l10n.dashboardSectionCoreCharts,
                        initiallyExpanded: true,
                        alwaysExpanded: desktop,
                        controller: _coreChartsController,
                        children: [
                          cashFlowChart,
                          SizedBox(height: sectionGap),
                          categoryChart,
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _DashboardCollapsibleChartGroup(
                        title: l10n.dashboardSectionTrendCharts,
                        subtitle: l10n.dashboardSectionTrendChartsHint,
                        initiallyExpanded: desktop,
                        alwaysExpanded: desktop,
                        children: [trendChart],
                      ),
                      SizedBox(height: sectionGap),
                      _DashboardCollapsibleChartGroup(
                        title: l10n.dashboardSectionSpendingAnalysis,
                        subtitle: l10n.dashboardSectionSpendingAnalysisHint,
                        initiallyExpanded: desktop,
                        alwaysExpanded: desktop,
                        controller: _spendingAnalysisController,
                        children: [pressureChart],
                      ),
                    ],
                    SizedBox(height: sectionGap),
                    _DashboardTransactionsSection(
                      snapshot: snapshot,
                      controller: widget.controller,
                      transactionController: widget.transactionController,
                      scope: widget.scope,
                    ),
                    SizedBox(height: sectionGap),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  theme: theme,
                                  title:
                                      l10n.dashboardOverviewBudgetPerformance,
                                ),
                                const SizedBox(height: 16),
                                KeyedSubtree(
                                  key: _budgetPerformanceKey,
                                  child: _BudgetPerformanceCard(
                                    performance: budgetPerformance,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _DashboardBudgetChartPanel(
                                  performance: budgetPerformance,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  theme: theme,
                                  title: l10n.dashboardOverviewAccountHealth,
                                ),
                                const SizedBox(height: 16),
                                _AccountHealthCard(
                                  snapshot: snapshot,
                                  budgetPerformance: budgetPerformance,
                                  transactionCount: widget.transactionCount,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _SectionTitle(
                        theme: theme,
                        title: l10n.dashboardOverviewBudgetPerformance,
                      ),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: _budgetPerformanceKey,
                        child: _BudgetPerformanceCard(
                          performance: budgetPerformance,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DashboardBudgetChartPanel(
                        performance: budgetPerformance,
                      ),
                      SizedBox(height: sectionGap),
                      _SectionTitle(
                        theme: theme,
                        title: l10n.dashboardOverviewAccountHealth,
                      ),
                      const SizedBox(height: 16),
                      _AccountHealthCard(
                        snapshot: snapshot,
                        budgetPerformance: budgetPerformance,
                        transactionCount: widget.transactionCount,
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
