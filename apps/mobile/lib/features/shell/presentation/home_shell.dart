import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../auth/application/auth_controller.dart';
import 'import_job_progress_banner.dart';
import '../../accounts/data/connect_bank_entry_point_tracker.dart';
import '../../accounts/presentation/accounts_navigation_actions.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../plaid/application/plaid_link_service.dart';
import '../../profile/application/locale_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/application/theme_mode_controller.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../rex/presentation/assistant_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.ui,
    required this.authController,
    required this.profileController,
    required this.themeModeController,
    required this.localeController,
    this.signOut,
  });

  final AppUiDependencies ui;
  final AuthController authController;
  final ProfileController profileController;
  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final Future<void> Function()? signOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static int _lastSelectedIndex = 0;

  int _idx = _lastSelectedIndex;
  int _manageCategoriesRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.authController.bindLocalizations(context.l10n);
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
      _selectIndex(2);
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
      final l10n = context.l10n;
      final message = switch (result) {
        PlaidConnectionSuccess(:final institutionName, :final accountsSynced) =>
          l10n.homeShellBankConnectedSuccess(
            institutionName ?? l10n.homeShellBankConnectedYourBank,
            accountsSynced > 0
                ? l10n.homeShellBankConnectedAccountsSynced(accountsSynced)
                : '',
          ),
        PlaidConnectionExit(:final errorCode) when errorCode != null =>
          l10n.homeShellBankConnectionStoppedWithCode(errorCode),
        PlaidConnectionExit(:final status) when status != null =>
          l10n.homeShellBankConnectionStoppedWithStatus(status),
        PlaidConnectionExit() => l10n.homeShellBankConnectionCancelled,
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
        SnackBar(content: Text(context.l10n.homeShellBankConnectionOpenFailed)),
      );
    }
  }

  void _openAccountsForCsvFallback() {
    setState(() => _selectIndex(1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccountsNavigationActions(
        controller: widget.ui.accounts,
        dashboardController: widget.ui.dashboard,
        transactionController: widget.ui.transactions,
        budgetController: widget.ui.budgets,
        importJobStatusController: widget.ui.importJobStatus,
      ).importCsvInstead(context, surface: 'dashboard_empty');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        isActive: _idx == 1,
      ),
      BudgetsScreen(
        controller: widget.ui.budgets,
        manageCategoriesRequest: _manageCategoriesRequest,
      ),
      const AssistantScreen(),
      ProfileScreen(
        profileController: widget.profileController,
        authController: widget.authController,
        themeModeController: widget.themeModeController,
        localeController: widget.localeController,
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
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavigationBar(
              selectedIndex: _idx,
              onDestinationSelected: (i) => setState(() => _selectIndex(i)),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded),
                  label: l10n.navDashboard,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_outlined),
                  selectedIcon: const Icon(Icons.account_balance_rounded),
                  label: l10n.navAccounts,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.savings_outlined),
                  selectedIcon: const Icon(Icons.savings_rounded),
                  label: l10n.navBudgets,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.psychology_alt_outlined),
                  selectedIcon: const Icon(Icons.psychology_alt_rounded),
                  label: l10n.navAssistant,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: l10n.navProfile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectIndex(int index) {
    _idx = index;
    _lastSelectedIndex = index;
  }
}
