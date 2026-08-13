part of 'financial_dashboard_view.dart';

enum _DashboardSurface { overview, transactions }

class _DashboardSurfaceSwitch extends StatelessWidget {
  const _DashboardSurfaceSwitch({
    required this.selected,
    required this.onSelected,
  });

  final _DashboardSurface selected;
  final ValueChanged<_DashboardSurface> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<_DashboardSurface>(
      segments: [
        ButtonSegment(
          value: _DashboardSurface.overview,
          label: Text(l10n.dashboardSurfaceOverview),
          icon: const Icon(Icons.insights_outlined, size: 18),
        ),
        ButtonSegment(
          value: _DashboardSurface.transactions,
          label: Text(l10n.dashboardSurfaceTransactions),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (next) {
        if (next.isEmpty) return;
        onSelected(next.first);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Graphs, budget, and account health — no transaction list.
class _DashboardOverviewBody extends StatelessWidget {
  const _DashboardOverviewBody({
    required this.snapshot,
    required this.budgetPerformance,
    required this.transactionCount,
    required this.accountCount,
    required this.scope,
    required this.sectionGap,
    required this.wide,
    required this.desktop,
    required this.monthlyCashFlowKey,
    required this.spendingPressureKey,
    required this.budgetPerformanceKey,
    required this.coreChartsController,
    required this.spendingAnalysisController,
    required this.onCategoryTap,
    required this.availableYearMonths,
    required this.onMonthSelected,
  });

  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int transactionCount;
  final int accountCount;
  final DashboardScope scope;
  final double sectionGap;
  final bool wide;
  final bool desktop;
  final GlobalKey monthlyCashFlowKey;
  final GlobalKey spendingPressureKey;
  final GlobalKey budgetPerformanceKey;
  final ExpansibleController coreChartsController;
  final ExpansibleController spendingAnalysisController;
  final ValueChanged<String> onCategoryTap;
  final List<String> availableYearMonths;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final overviewCard = _FinancialOverviewCard(
      snapshot: snapshot,
      isGlobalScope: scope is GlobalDashboardScope,
      accountCount: scope is GlobalDashboardScope ? accountCount : null,
      availableYearMonths: availableYearMonths,
      onMonthSelected: onMonthSelected,
    );
    final cashFlowChart = _DashboardChartSection(
      sectionKey: monthlyCashFlowKey,
      title: l10n.dashboardOverviewMonthlyCashFlow,
      child: MonthlyCashFlowChart(months: snapshot.monthlyCashFlow),
    );
    final categoryChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSpendingByCategory,
      subtitle: l10n.dashboardChartCategorySpendSubtitle,
      child: CategorySpendChart(
        categories: snapshot.topCategories,
        onCategoryTap: onCategoryTap,
      ),
    );
    final spendRadarChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSpendShape,
      subtitle: l10n.dashboardChartSpendRadarSubtitle,
      child: CategorySpendRadarChart(
        categories: snapshot.topCategories,
        budgetPerformance: budgetPerformance,
      ),
    );
    final trendChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSixMonthTrend,
      child: SpendTrendChart(months: snapshot.monthlyCashFlow),
    );
    final pressureChart = _DashboardChartSection(
      sectionKey: spendingPressureKey,
      title: l10n.dashboardOverviewSpendingPressure,
      subtitle: l10n.dashboardChartSpendingPressureSubtitle,
      child: BiggestLeaksChart(
        leaks: snapshot.biggestLeaksThisMonth,
        onCategoryTap: onCategoryTap,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Expanded(child: spendRadarChart),
              const SizedBox(width: 16),
              Expanded(child: pressureChart),
            ],
          ),
          SizedBox(height: sectionGap),
          trendChart,
        ] else ...[
          _DashboardCollapsibleChartGroup(
            title: l10n.dashboardSectionCoreCharts,
            initiallyExpanded: true,
            alwaysExpanded: desktop,
            controller: coreChartsController,
            children: [
              cashFlowChart,
              SizedBox(height: sectionGap),
              categoryChart,
              SizedBox(height: sectionGap),
              spendRadarChart,
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
            controller: spendingAnalysisController,
            children: [pressureChart],
          ),
        ],
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
                      title: l10n.dashboardOverviewBudgetPerformance,
                    ),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: budgetPerformanceKey,
                      child: _BudgetPerformanceCard(
                        performance: budgetPerformance,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DashboardBudgetChartPanel(
                      performance: budgetPerformance,
                      onCategoryTap: onCategoryTap,
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
                      transactionCount: transactionCount,
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
            key: budgetPerformanceKey,
            child: _BudgetPerformanceCard(performance: budgetPerformance),
          ),
          const SizedBox(height: 12),
          _DashboardBudgetChartPanel(
            performance: budgetPerformance,
            onCategoryTap: onCategoryTap,
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
            transactionCount: transactionCount,
          ),
        ],
      ],
    );
  }
}
