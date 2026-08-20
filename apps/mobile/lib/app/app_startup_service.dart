import 'dart:async';

import '../core/supabase/supabase_exceptions.dart';
import '../core/supabase/supabase_realtime_supervisor.dart';
import '../features/accounts/data/account_service.dart';
import '../features/auth/application/auth_service.dart';
import '../features/budgets/data/budget_service.dart';
import '../features/categories/application/category_read_model.dart';
import '../features/categories/data/category_service.dart';
import '../features/transactions/data/transaction_service.dart';

class AppStartupService {
  AppStartupService({
    required this.authService,
    required this.budgetService,
    required this.accountService,
    required this.categoryService,
    required this.categoryReadModel,
    required this.transactionService,
    required this.notifyDashboardAndBudgetsChanged,
    required this.notifyAccountsChanged,
    required this.notifyTransactionDataChanged,
    SupabaseRealtimeSupervisor? realtime,
  }) : _realtime =
           realtime ??
           SupabaseRealtimeSupervisor(
             refreshSession: () async {
               await authService.refreshAuthSession();
             },
             hasSession: () => authService.currentSession != null,
           );

  final AuthService authService;
  final BudgetService budgetService;
  final AccountService accountService;
  final CategoryService categoryService;
  final CategoryReadModel categoryReadModel;
  final TransactionService transactionService;
  final void Function() notifyDashboardAndBudgetsChanged;
  final void Function() notifyAccountsChanged;
  final void Function() notifyTransactionDataChanged;
  final SupabaseRealtimeSupervisor _realtime;

  StreamSubscription<dynamic>? _authSubscription;

  Future<void> hydrateForStartup() async {
    _startAuthWatcher();
    await _fetchInitialSupabaseData();
    await _startSupabaseWatchers();
  }

  /// Real background resume: refresh JWT, then resubscribe if the socket died.
  Future<void> recoverAfterResume() async {
    if (authService.currentSession == null) return;
    await _realtime.recoverAfterResume();
  }

  Future<void> _fetchInitialSupabaseData() async {
    final accountsLoaded = await _runIfAuthenticated(
      accountService.fetchAccounts,
    );
    if (accountsLoaded) notifyAccountsChanged();

    final budgetsLoaded = await _runIfAuthenticated(budgetService.fetchBudgets);
    if (budgetsLoaded) notifyDashboardAndBudgetsChanged();

    final categoriesLoaded = await _runIfAuthenticated(
      categoryReadModel.refresh,
    );
    if (categoriesLoaded) notifyTransactionDataChanged();

    final transactionsLoaded = await _runIfAuthenticated(
      transactionService.fetchTransactions,
    );
    if (transactionsLoaded) notifyTransactionDataChanged();
  }

  Future<void> _startSupabaseWatchers() async {
    if (_realtime.isListening) return;
    await _realtime.start(_financeWatches());
  }

  List<SupabaseRealtimeWatch> _financeWatches() {
    return [
      SupabaseRealtimeWatch(
        name: 'accounts',
        open: accountService.watchAccounts,
        onData: (_) => notifyAccountsChanged(),
      ),
      SupabaseRealtimeWatch(
        name: 'budgets',
        open: budgetService.watchBudgets,
        onData: (_) => notifyDashboardAndBudgetsChanged(),
      ),
      SupabaseRealtimeWatch(
        name: 'categories',
        open: categoryService.watchCategories,
        onData: (rows) {
          categoryReadModel.applyRemoteCategories(rows);
          notifyDashboardAndBudgetsChanged();
          notifyTransactionDataChanged();
        },
      ),
      SupabaseRealtimeWatch(
        name: 'transactions',
        open: transactionService.watchTransactions,
        onData: (_) => notifyTransactionDataChanged(),
      ),
    ];
  }

  void _startAuthWatcher() {
    _authSubscription ??= authService.authStateChanges.listen((_) async {
      if (authService.currentUser == null) {
        _stopSupabaseWatchers();
        notifyAccountsChanged();
        notifyDashboardAndBudgetsChanged();
        notifyTransactionDataChanged();
        return;
      }

      await _fetchInitialSupabaseData();
      await _startSupabaseWatchers();
    });
  }

  Future<bool> _runIfAuthenticated(Future<Object?> Function() action) async {
    try {
      await action();
      return true;
    } on SupabaseAuthRequiredException {
      return false;
    }
  }

  void dispose() {
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    _stopSupabaseWatchers();
  }

  void _stopSupabaseWatchers() {
    _realtime.stop();
    categoryReadModel.stopWatching();
  }
}
