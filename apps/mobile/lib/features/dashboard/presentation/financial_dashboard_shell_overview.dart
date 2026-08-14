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
class _DashboardOverviewBody extends StatefulWidget {
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
  final ValueChanged<String> onCategoryTap;
  final List<String> availableYearMonths;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  State<_DashboardOverviewBody> createState() => _DashboardOverviewBodyState();
}

class _DashboardOverviewBodyState extends State<_DashboardOverviewBody> {
  DashboardActivityPeriod _period = DashboardActivityPeriod.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final snapshot = widget.snapshot;
    final periodMonths = cashFlowForActivityPeriod(
      monthlyCashFlow: snapshot.monthlyCashFlow,
      reference: snapshot.referenceMonth,
      period: _period,
    );
    final periodCategories = categorySpendForActivityPeriod(
      monthlyCategorySpend: snapshot.monthlyCategorySpend,
      reference: snapshot.referenceMonth,
      period: _period,
    );
    final overviewCard = _FinancialOverviewCard(
      snapshot: snapshot,
      isGlobalScope: widget.scope is GlobalDashboardScope,
      accountCount: widget.scope is GlobalDashboardScope
          ? widget.accountCount
          : null,
      availableYearMonths: widget.availableYearMonths,
      onMonthSelected: widget.onMonthSelected,
      period: _period,
      onPeriodChanged: (period) => setState(() => _period = period),
    );
    final cashFlowChart = _DashboardChartSection(
      sectionKey: widget.monthlyCashFlowKey,
      title: l10n.dashboardOverviewMonthlyCashFlow,
      child: MonthlyCashFlowChart(
        months: snapshot.monthlyCashFlow,
      ),
    );
    final categoryChart = _DashboardChartSection(
      sectionKey: widget.spendingPressureKey,
      title: l10n.dashboardOverviewSpendingByCategory,
      subtitle: l10n.dashboardChartCategorySpendSubtitle,
      child: CategorySpendChart(
        categories: periodCategories,
        onCategoryTap: widget.onCategoryTap,
      ),
    );
    final categoryPieChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSpendingShare,
      subtitle: l10n.dashboardChartSpendingShareSubtitle,
      child: CategorySpendPieChart(
        categories: periodCategories,
        onCategoryTap: widget.onCategoryTap,
      ),
    );
    final spendRadarChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSpendShape,
      subtitle: l10n.dashboardChartSpendRadarSubtitle,
      child: CategorySpendRadarChart(
        categories: periodCategories,
        budgetPerformance: _period == DashboardActivityPeriod.month
            ? widget.budgetPerformance
            : null,
      ),
    );
    final trendChart = _DashboardChartSection(
      title: l10n.dashboardOverviewSixMonthTrend,
      child: SpendTrendChart(
        months: periodMonths,
        showRangeSwitch: false,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        overviewCard,
        SizedBox(height: widget.sectionGap),
        if (widget.wide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cashFlowChart),
              const SizedBox(width: 16),
              Expanded(child: categoryChart),
            ],
          ),
          SizedBox(height: widget.sectionGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: categoryPieChart),
              const SizedBox(width: 16),
              Expanded(child: spendRadarChart),
            ],
          ),
          if (_period != DashboardActivityPeriod.month) ...[
            SizedBox(height: widget.sectionGap),
            trendChart,
          ],
        ] else ...[
          _DashboardCollapsibleChartGroup(
            title: l10n.dashboardSectionCoreCharts,
            initiallyExpanded: true,
            alwaysExpanded: widget.desktop,
            controller: widget.coreChartsController,
            children: [
              cashFlowChart,
              SizedBox(height: widget.sectionGap),
              categoryChart,
              SizedBox(height: widget.sectionGap),
              categoryPieChart,
              SizedBox(height: widget.sectionGap),
              spendRadarChart,
            ],
          ),
          if (_period != DashboardActivityPeriod.month) ...[
            SizedBox(height: widget.sectionGap),
            _DashboardCollapsibleChartGroup(
              title: l10n.dashboardSectionTrendCharts,
              subtitle: l10n.dashboardSectionTrendChartsHint,
              initiallyExpanded: widget.desktop,
              alwaysExpanded: widget.desktop,
              children: [trendChart],
            ),
          ],
        ],
        SizedBox(height: widget.sectionGap),
        if (widget.wide)
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
                      key: widget.budgetPerformanceKey,
                      child: _BudgetPerformanceCard(
                        performance: widget.budgetPerformance,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DashboardBudgetChartPanel(
                      performance: widget.budgetPerformance,
                      onCategoryTap: widget.onCategoryTap,
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
                      budgetPerformance: widget.budgetPerformance,
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
            key: widget.budgetPerformanceKey,
            child: _BudgetPerformanceCard(
              performance: widget.budgetPerformance,
            ),
          ),
          const SizedBox(height: 12),
          _DashboardBudgetChartPanel(
            performance: widget.budgetPerformance,
            onCategoryTap: widget.onCategoryTap,
          ),
          SizedBox(height: widget.sectionGap),
          _SectionTitle(
            theme: theme,
            title: l10n.dashboardOverviewAccountHealth,
          ),
          const SizedBox(height: 16),
          _AccountHealthCard(
            snapshot: snapshot,
            budgetPerformance: widget.budgetPerformance,
            transactionCount: widget.transactionCount,
          ),
        ],
      ],
    );
  }
}
