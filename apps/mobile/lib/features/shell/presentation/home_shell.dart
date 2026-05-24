import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import 'import_job_progress_banner.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../assistant/presentation/assistant_screen.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.ui, this.signOut});

  final AppUiDependencies ui;
  final Future<void> Function()? signOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;
  int _dashboardReviewRequest = 0;
  int _manageCategoriesRequest = 0;

  void _openDashboardReview() {
    setState(() {
      _idx = 0;
      _dashboardReviewRequest++;
    });
  }

  void _openCategoryManagement() {
    setState(() {
      _idx = 2;
      _manageCategoriesRequest++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final pages = <Widget>[
      DashboardScreen(
        controller: widget.ui.dashboard,
        transactionController: widget.ui.transactions,
        budgetController: widget.ui.budgets,
        importJobStatusController: widget.ui.importJobStatus,
        isRoot: true,
        reviewRequest: _dashboardReviewRequest,
      ),
      AccountsScreen(
        controller: widget.ui.accounts,
        dashboardController: widget.ui.dashboard,
        transactionController: widget.ui.transactions,
        budgetController: widget.ui.budgets,
        importJobStatusController: widget.ui.importJobStatus,
      ),
      BudgetsScreen(
        controller: widget.ui.budgets,
        manageCategoriesRequest: _manageCategoriesRequest,
      ),
      const AssistantScreen(),
    ];

    return HeroMode(
      enabled: false,
      child: Scaffold(
        body: ImportJobStatusHost(
          controller: widget.ui.importJobStatus,
          onReviewIssues: _openDashboardReview,
          onManageCategories: _openCategoryManagement,
          child: IndexedStack(index: _idx, children: pages),
        ),
        floatingActionButton: widget.signOut == null || _idx == 3
            ? null
            : FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Sign out',
                onPressed: widget.signOut,
                child: const Icon(Icons.logout_rounded),
              ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 68,
          indicatorColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance_rounded),
              label: 'Accounts',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Budgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_alt_outlined),
              selectedIcon: Icon(Icons.psychology_alt_rounded),
              label: 'Assistant',
            ),
          ],
        ),
      ),
    );
  }
}
