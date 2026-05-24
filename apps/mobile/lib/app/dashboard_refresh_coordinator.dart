import '../core/models/models.dart';
import '../features/dashboard/application/dashboard_service.dart';
import '../features/finance/application/financial_read_model_service.dart';
import '../features/transactions/data/csv_parser.dart';
import '../features/transactions/domain/transaction_resolution.dart' as tx_res;

/// Coordinates dashboard recomputation from the app service graph.
class DashboardRefreshCoordinator {
  DashboardRefreshCoordinator({
    required this.dashboardService,
    required this.financialReadModelService,
    required this.notifyTransactionDataChanged,
  });

  final DashboardService dashboardService;
  final FinancialReadModelService financialReadModelService;
  final void Function() notifyTransactionDataChanged;

  Future<List<Transaction>> refreshAllState() async {
    final model = await financialReadModelService.load();
    _recomputeDashboard(
      activeAccountTransactions: model.transactions,
      allTransactionsForMetrics: model.transactions,
      transactionsForCsvDiagnostics: model.transactions,
      diagnostics: null,
      model: model,
    );
    notifyTransactionDataChanged();
    return model.transactions;
  }

  Future<void> syncAfterTransactionWorkflow({
    required List<Transaction> activeAccountTransactions,
    required List<Transaction> allTransactionsForMetrics,
    required List<Transaction> transactionsForCsvDiagnostics,
    required CsvParseDiagnostics? diagnostics,
  }) async {
    final model = await financialReadModelService.load();
    _recomputeDashboard(
      activeAccountTransactions: activeAccountTransactions,
      allTransactionsForMetrics: allTransactionsForMetrics,
      transactionsForCsvDiagnostics: transactionsForCsvDiagnostics,
      diagnostics: diagnostics,
      model: model,
    );
  }

  void _recomputeDashboard({
    required List<Transaction> activeAccountTransactions,
    required List<Transaction> allTransactionsForMetrics,
    required List<Transaction> transactionsForCsvDiagnostics,
    required CsvParseDiagnostics? diagnostics,
    required FinancialReadModel model,
  }) {
    dashboardService.recomputeDerivedState(
      activeAccountTransactions: activeAccountTransactions,
      allTransactionsForMetrics: allTransactionsForMetrics,
      transactionsForCsvDiagnostics: transactionsForCsvDiagnostics,
      diag: diagnostics,
      accounts: model.accounts,
      categoryOverrides: const {},
      categoryDisplayRenames: model.categoryDisplayRenamesLower,
      resolveTransactions: (txs, {required allTransactionsContext}) {
        return _resolveTransactions(
          txs,
          model: model,
          allTransactionsContext: allTransactionsContext,
        );
      },
    );
  }

  List<tx_res.ResolvedTransaction> _resolveTransactions(
    List<Transaction> txs, {
    required FinancialReadModel model,
    required List<Transaction> allTransactionsContext,
  }) {
    return tx_res.resolveTransactions(
      txs,
      categoryOverrides: const {},
      categoryDisplayRenamesLower: model.categoryDisplayRenamesLower,
      merchantCategoryMemory: const {},
      accountsById: model.accountsById,
      allTransactions: allTransactionsContext,
    );
  }
}
