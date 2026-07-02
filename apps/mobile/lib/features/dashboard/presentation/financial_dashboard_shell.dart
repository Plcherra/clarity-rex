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
    this.onSeeAllInsights,
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
  final VoidCallback? onSeeAllInsights;

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

  void _scrollToInsightAnchor(DashboardInsightAnchor anchor) {
    final key = switch (anchor) {
      DashboardInsightAnchor.monthlyCashFlow => _monthlyCashFlowKey,
      DashboardInsightAnchor.spendingPressure => _spendingPressureKey,
      DashboardInsightAnchor.budgetPerformance => _budgetPerformanceKey,
    };

    if (anchor == DashboardInsightAnchor.monthlyCashFlow &&
        !_coreChartsController.isExpanded) {
      _coreChartsController.expand();
    }
    if (anchor == DashboardInsightAnchor.spendingPressure &&
        !_spendingAnalysisController.isExpanded) {
      _spendingAnalysisController.expand();
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
    final insightItems = buildDashboardInsightItems(
      l10n: l10n,
      snapshot: snapshot,
      budgetPerformance: budgetPerformance,
    );
    final chronologicalGroups = _chronologicalMonthlyGroups(
      snapshot.monthlyGroups,
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
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
                    const SizedBox(height: 14),
                  ],
                  _FinancialOverviewCard(
                    snapshot: snapshot,
                    isGlobalScope: widget.scope is GlobalDashboardScope,
                    accountCount: widget.scope is GlobalDashboardScope
                        ? widget.accountCount
                        : null,
                  ),
                  if (insightItems.isNotEmpty) ...[
                    const SizedBox(height: _sectionGap),
                    _DashboardInsightsStrip(
                      items: insightItems,
                      onSeeChart: _scrollToInsightAnchor,
                      onSeeAllInsights: widget.onSeeAllInsights,
                    ),
                  ],
                  const SizedBox(height: _sectionGap),
                  _DashboardCollapsibleChartGroup(
                    title: l10n.dashboardSectionCoreCharts,
                    initiallyExpanded: true,
                    controller: _coreChartsController,
                    children: [
                      _DashboardChartSection(
                        sectionKey: _monthlyCashFlowKey,
                        title: l10n.dashboardOverviewMonthlyCashFlow,
                        child: MonthlyCashFlowChart(
                          monthlyGroups: chronologicalGroups,
                        ),
                      ),
                      const SizedBox(height: _sectionGap),
                      _DashboardChartSection(
                        title: l10n.dashboardOverviewSpendingByCategory,
                        subtitle: l10n.dashboardChartCategorySpendSubtitle,
                        child: CategorySpendChart(
                          categories: snapshot.topCategories,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  _DashboardCollapsibleChartGroup(
                    title: l10n.dashboardSectionTrendCharts,
                    subtitle: l10n.dashboardSectionTrendChartsHint,
                    initiallyExpanded: false,
                    children: [
                      _DashboardChartSection(
                        title: l10n.dashboardOverviewSixMonthTrend,
                        child: SixMonthSpendTrendChart(
                          monthlyGroups: chronologicalGroups,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  _DashboardTransactionsSection(
                    snapshot: snapshot,
                    controller: widget.controller,
                    transactionController: widget.transactionController,
                    scope: widget.scope,
                  ),
                  const SizedBox(height: _sectionGap),
                  _DashboardCollapsibleChartGroup(
                    title: l10n.dashboardSectionSpendingAnalysis,
                    subtitle: l10n.dashboardSectionSpendingAnalysisHint,
                    initiallyExpanded: false,
                    controller: _spendingAnalysisController,
                    children: [
                      _DashboardChartSection(
                        sectionKey: _spendingPressureKey,
                        title: l10n.dashboardOverviewSpendingPressure,
                        subtitle: l10n.dashboardChartSpendingPressureSubtitle,
                        child: BiggestLeaksChart(
                          leaks: snapshot.biggestLeaksThisMonth,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
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
                  _DashboardBudgetChartPanel(performance: budgetPerformance),
                  const SizedBox(height: _sectionGap),
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
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialDataStatusBanner extends StatelessWidget {
  const _FinancialDataStatusBanner({required this.loadIssues});

  final List<FinancialReadModelLoadIssue> loadIssues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final sources =
        loadIssues
            .map((issue) => issue.source.trim())
            .where((source) => source.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final sourceLabel = sources.isEmpty
        ? l10n.dashboardOverviewDataLoadBannerFallbackSource
        : sources.join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ClarityColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: ClarityColors.warning,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardOverviewDataLoadBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dashboardOverviewDataLoadBannerBody(sourceLabel),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.68),
                      height: 1.3,
                    ),
                  ),
                ],
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
          colors: [cs.surfaceContainerLow, cs.surface],
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
                  child: ClarityDiamondLoader(
                    size: 64,
                    label: context.l10n.dashboardOverviewLoadingLabel,
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

class _DashboardEmptySetupBody extends StatelessWidget {
  const _DashboardEmptySetupBody({
    required this.title,
    required this.onConnectBank,
    required this.onImportCsvInstead,
  });

  final String title;
  final VoidCallback onConnectBank;
  final VoidCallback onImportCsvInstead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 2, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.trim().isNotEmpty)
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 2.4,
                    color: cs.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              ConnectBankSetupCard(
                title: context.l10n.dashboardEmptyConnectFirstBankTitle,
                body: context.l10n.dashboardEmptyConnectFirstBankBody,
                onConnectBank: onConnectBank,
                onImportCsvInstead: onImportCsvInstead,
              ),
              const Spacer(),
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
          colors: [cs.surfaceContainerLow, cs.surface],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ClarityCard(
              padding: const EdgeInsets.all(22),
              backgroundColor: cs.surfaceContainerLow,
              borderColor: _dashboardOutline(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ClarityDiamondLoader(size: 52),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.dashboardResolvingTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.dashboardResolvingBody,
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
