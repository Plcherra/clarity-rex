part of 'financial_dashboard_view.dart';

class _DashboardScrollBody extends StatelessWidget {
  const _DashboardScrollBody({
    required this.title,
    required this.controller,
    required this.transactionController,
    required this.scope,
    required this.snapshot,
    required this.budgetPerformance,
    required this.transactionCount,
    required this.loadIssues,
  });

  final String title;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final DashboardScope scope;
  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int transactionCount;
  final List<FinancialReadModelLoadIssue> loadIssues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                  if (title.trim().isNotEmpty) ...[
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 2.4,
                        color: cs.onSurface.withValues(alpha: 0.38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (title.trim().isEmpty) const SizedBox(height: 2),
                  if (loadIssues.isNotEmpty) ...[
                    _FinancialDataStatusBanner(loadIssues: loadIssues),
                    const SizedBox(height: 14),
                  ],
                  _CashFlowSummaryCard(snapshot: snapshot),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Monthly cash flow'),
                  const SizedBox(height: 16),
                  _DashboardChartPanel(
                    child: MonthlyCashFlowChart(
                      monthlyGroups: _chronologicalMonthlyGroups(
                        snapshot.monthlyGroups,
                      ),
                    ),
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Spending by category'),
                  const SizedBox(height: 16),
                  _DashboardChartPanel(
                    child: CategorySpendChart(
                      categories: snapshot.topCategories,
                    ),
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Income vs spending'),
                  const SizedBox(height: 16),
                  _DashboardChartPanel(
                    child: IncomeSpendRatioChart(
                      income: snapshot.incomeThisMonth,
                      spent: snapshot.spentThisMonth,
                    ),
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Six-month spend trend'),
                  const SizedBox(height: 16),
                  _DashboardChartPanel(
                    child: SixMonthSpendTrendChart(
                      monthlyGroups: _chronologicalMonthlyGroups(
                        snapshot.monthlyGroups,
                      ),
                    ),
                  ),
                  const SizedBox(height: _sectionGap),
                  _DashboardTransactionsSection(
                    snapshot: snapshot,
                    controller: controller,
                    transactionController: transactionController,
                    scope: scope,
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Spending pressure'),
                  const SizedBox(height: 16),
                  _DashboardChartPanel(
                    child: BiggestLeaksChart(
                      leaks: snapshot.biggestLeaksThisMonth,
                    ),
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Budget performance'),
                  const SizedBox(height: 16),
                  _BudgetPerformanceCard(performance: budgetPerformance),
                  const SizedBox(height: _sectionGap),
                  _SectionTitle(theme: theme, title: 'Account health'),
                  const SizedBox(height: 16),
                  _AccountHealthCard(
                    snapshot: snapshot,
                    budgetPerformance: budgetPerformance,
                    transactionCount: transactionCount,
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
    final sources =
        loadIssues
            .map((issue) => issue.source.trim())
            .where((source) => source.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final sourceLabel = sources.isEmpty ? 'financial data' : sources.join(', ');
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
                    'Some financial data could not load',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clarity is showing the available records, but $sourceLabel may be incomplete. Rex will treat finance answers as degraded until this refreshes.',
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
              const Expanded(
                child: Center(
                  child: ClarityDiamondLoader(
                    size: 64,
                    label: 'Loading your financial data...',
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
                title: 'Connect your first bank',
                body:
                    'Clarity works best with connected accounts, so balances and transactions stay current automatically.',
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
                    'Resolving imported transactions',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your statement is connected, but the transaction rows are still loading. Values will appear when the read model is complete.',
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
