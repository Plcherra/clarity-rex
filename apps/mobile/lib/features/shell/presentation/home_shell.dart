import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../auth/application/auth_controller.dart';
import 'import_job_progress_banner.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../assistant/presentation/assistant_screen.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.ui,
    required this.authController,
    this.signOut,
  });

  final AppUiDependencies ui;
  final AuthController authController;
  final Future<void> Function()? signOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _idx = 0;
  int _manageCategoriesRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.ui.notifyAll();
    }
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
      ),
      AccountsScreen(
        controller: widget.ui.accounts,
        dashboardController: widget.ui.dashboard,
        transactionController: widget.ui.transactions,
        budgetController: widget.ui.budgets,
        importJobStatusController: widget.ui.importJobStatus,
        authController: widget.authController,
        signOut: widget.signOut,
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
          onManageCategories: _openCategoryManagement,
          child: IndexedStack(index: _idx, children: pages),
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
