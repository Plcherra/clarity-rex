import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/friendly_service_error.dart';
import '../../auth/application/auth_controller.dart';
import 'import_job_progress_banner.dart';
import '../../accounts/data/connect_bank_entry_point_tracker.dart';
import '../../accounts/presentation/accounts_navigation_actions.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../dashboard/application/dashboard_deep_link_navigation.dart';
import '../../dashboard/domain/dashboard_insight_anchor.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../plaid/application/plaid_link_service.dart';
import '../../profile/application/locale_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/application/theme_mode_controller.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../rex/presentation/assistant_chat_visible_provider.dart';
import '../../../rex/presentation/assistant_screen.dart';
import '../../../rex/voice/presentation/voice_clarity_action_listener.dart';
import '../../../app/ui_dependencies.dart';
import '../../../core/layout/clarity_breakpoints.dart';
import 'home_shell_layout.dart';

/// Shell tab index for the Assistant destination (Dashboard=0 … Assistant=3).
const assistantShellTabIndex = 3;

class HomeShell extends ConsumerStatefulWidget {
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
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  static int _lastSelectedIndex = 0;

  int _idx = _lastSelectedIndex;
  int _manageCategoriesRequest = 0;
  DashboardInsightAnchor? _pendingDashboardAnchor;
  int _handledDashboardDeepLinkToken = 0;
  /// Tracks prior lifecycle so screenshot/Control Center (inactive→resumed)
  /// does not hard-reload finance like a true background return.
  AppLifecycleState? _lastLifecycleState;

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
    final previous = _lastLifecycleState;
    _lastLifecycleState = state;
    // iOS screenshots briefly go inactive→resumed without pausing. Only refresh
    // after a real background (paused/hidden) so Dashboard does not flash-load.
    final returningFromBackground =
        previous == AppLifecycleState.paused ||
        previous == AppLifecycleState.hidden;
    if (state == AppLifecycleState.resumed && returningFromBackground) {
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
      ).showSnackBar(SnackBar(content: Text(friendlyPlaidLinkError(context.l10n, error))));
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

  Widget _shellTab(Widget child, {required double maxWidth}) {
    return ShellContentConstraints(maxWidth: maxWidth, child: child);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DashboardDeepLinkRequest?>(dashboardDeepLinkRequestProvider, (
      previous,
      next,
    ) {
      if (next == null || next.token == _handledDashboardDeepLinkToken) {
        return;
      }
      setState(() {
        _selectIndex(dashboardDeepLinkOpensAccounts(next.anchor) ? 1 : 0);
        _pendingDashboardAnchor = dashboardDeepLinkOpensAccounts(next.anchor)
            ? null
            : next.anchor;
      });
    });

    final l10n = context.l10n;
    final pages = <Widget>[
      _shellTab(
        maxWidth: clarityFinanceContentMaxWidth,
        DashboardScreen(
          controller: widget.ui.dashboard,
          transactionController: widget.ui.transactions,
          budgetController: widget.ui.budgets,
          importJobStatusController: widget.ui.importJobStatus,
          isRoot: true,
          onConnectBank: () => _connectBank('dashboard_empty'),
          onImportCsvInstead: _openAccountsForCsvFallback,
          scrollToAnchor: _pendingDashboardAnchor,
          onScrollToAnchorHandled: () {
            final request = ref.read(dashboardDeepLinkRequestProvider);
            if (request != null) {
              _handledDashboardDeepLinkToken = request.token;
            }
            if (_pendingDashboardAnchor != null) {
              setState(() => _pendingDashboardAnchor = null);
            }
          },
        ),
      ),
      _shellTab(
        maxWidth: clarityFinanceContentMaxWidth,
        AccountsScreen(
          controller: widget.ui.accounts,
          dashboardController: widget.ui.dashboard,
          transactionController: widget.ui.transactions,
          budgetController: widget.ui.budgets,
          importJobStatusController: widget.ui.importJobStatus,
          isActive: _idx == 1,
        ),
      ),
      _shellTab(
        maxWidth: clarityFinanceContentMaxWidth,
        BudgetsScreen(
          controller: widget.ui.budgets,
          manageCategoriesRequest: _manageCategoriesRequest,
        ),
      ),
      _shellTab(
        maxWidth: clarityAssistantContentMaxWidth,
        AssistantScreen(profileController: widget.profileController),
      ),
      _shellTab(
        maxWidth: clarityProfileContentMaxWidth,
        ProfileScreen(
          profileController: widget.profileController,
          authController: widget.authController,
          themeModeController: widget.themeModeController,
          localeController: widget.localeController,
          signOut: widget.signOut,
        ),
      ),
    ];

    final navDestinations = [
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
    ];

    return HeroMode(
      enabled: false,
      child: VoiceClarityActionListener(
        child: HomeShellAdaptiveScaffold(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _selectIndex(i)),
          destinations: navDestinations,
          body: ImportJobStatusHost(
            controller: widget.ui.importJobStatus,
            onManageCategories: _openCategoryManagement,
            child: IndexedStack(index: _idx, children: pages),
          ),
        ),
      ),
    );
  }

  void _selectIndex(int index) {
    _idx = index;
    _lastSelectedIndex = index;
    // IndexedStack keeps every shell tab alive; without this, a focused
    // composer or search field keeps the keyboard up on the next destination.
    FocusManager.instance.primaryFocus?.unfocus();
    if (index != assistantShellTabIndex) {
      ref.read(assistantChatVisibleProvider.notifier).setVisible(false);
      return;
    }
    ref.read(assistantChatVisibilityResyncProvider.notifier).request();
  }
}
