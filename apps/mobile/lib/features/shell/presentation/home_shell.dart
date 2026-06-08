import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../auth/application/auth_controller.dart';
import 'import_job_progress_banner.dart';
import '../../accounts/data/connect_bank_entry_point_tracker.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../assistant/presentation/assistant_screen.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../plaid/application/plaid_link_service.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/presentation/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.ui,
    required this.authController,
    required this.profileController,
    this.signOut,
  });

  final AppUiDependencies ui;
  final AuthController authController;
  final ProfileController profileController;
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

  Future<void> _connectBank(String surface) async {
    trackConnectBankEntryPoint(
      surface: surface,
      action: ConnectBankEntryAction.connectBank,
    );
    try {
      final result = await widget.ui.accounts.connectBank();
      if (!mounted) return;
      final message = switch (result) {
        PlaidConnectionSuccess(:final institutionName, :final accountsSynced) =>
          'Bank connected successfully: ${institutionName ?? 'your bank'}'
              '${accountsSynced > 0 ? ' and synced $accountsSynced account${accountsSynced == 1 ? '' : 's'}' : ''}.',
        PlaidConnectionExit(:final errorCode) when errorCode != null =>
          'Bank connection stopped before it finished. You can try again. ($errorCode)',
        PlaidConnectionExit(:final status) when status != null =>
          'Bank connection stopped before it finished. Plaid status: $status.',
        PlaidConnectionExit() =>
          'Bank connection cancelled. No account was added.',
      };
      if (result is PlaidConnectionSuccess) {
        widget.ui.notifyDataChanged();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on PlaidLinkServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open bank connection.')),
      );
    }
  }

  void _openAccountsForCsvFallback() {
    trackConnectBankEntryPoint(
      surface: 'dashboard_empty',
      action: ConnectBankEntryAction.importCsvInstead,
    );
    setState(() => _idx = 1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CSV is a manual fallback. Create a manual account, then import CSV instead.',
        ),
      ),
    );
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
        onConnectBank: () => _connectBank('dashboard_empty'),
        onImportCsvInstead: _openAccountsForCsvFallback,
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
      ProfileScreen(
        profileController: widget.profileController,
        authController: widget.authController,
        signOut: widget.signOut,
      ),
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
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
