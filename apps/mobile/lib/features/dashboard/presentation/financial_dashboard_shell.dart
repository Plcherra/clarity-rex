part of 'financial_dashboard_view.dart';

class _DashboardScrollBody extends StatelessWidget {
  const _DashboardScrollBody({
    required this.title,
    required this.controller,
    required this.transactionController,
    required this.budgetController,
    required this.scope,
    required this.snapshot,
    required this.budgetPerformance,
    required this.transactionCount,
    required this.onUploadTransactions,
  });

  final String title;
  final DashboardUiController controller;
  final TransactionUiController transactionController;
  final BudgetUiController budgetController;
  final DashboardScope scope;
  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int transactionCount;
  final Future<void> Function()? onUploadTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFF8F7F4)),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 3.2,
                      color: cs.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DashboardActionRow(
                    onUploadTransactions: onUploadTransactions,
                    onOpenBudgets: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              BudgetsScreen(controller: budgetController),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _CashFlowSummaryCard(snapshot: snapshot),
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
                  _BiggestLeaksCard(leaks: snapshot.biggestLeaksThisMonth),
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
          colors: [const Color(0xFFF3F1ED), cs.surface],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 18),
                      Text(
                        'Loading your financial data...',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
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
      decoration: const BoxDecoration(color: Color(0xFFF8F7F4)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 3.2,
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
          colors: [const Color(0xFFF3F1ED), cs.surface],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0DCD4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
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

class _DashboardActionRow extends StatelessWidget {
  const _DashboardActionRow({
    required this.onUploadTransactions,
    required this.onOpenBudgets,
  });

  final Future<void> Function()? onUploadTransactions;
  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (onUploadTransactions != null)
          _CompactUploadButton(onPressed: onUploadTransactions!),
        OutlinedButton.icon(
          onPressed: onOpenBudgets,
          icon: const Icon(Icons.savings_outlined, size: 18),
          label: const Text('Budgets'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );
  }
}

class _CompactUploadButton extends StatefulWidget {
  const _CompactUploadButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State<_CompactUploadButton> createState() => _CompactUploadButtonState();
}

class _CompactUploadButtonState extends State<_CompactUploadButton> {
  var _busy = false;

  Future<void> _handleTap() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Manual fallback for files from your bank.',
      child: FilledButton.icon(
        onPressed: _busy ? null : _handleTap,
        icon: _busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onPrimary,
                ),
              )
            : const Icon(Icons.upload_file_rounded, size: 18),
        label: Text(_busy ? 'Importing...' : 'Import CSV instead'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
