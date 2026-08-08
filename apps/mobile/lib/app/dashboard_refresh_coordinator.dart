import '../core/models/models.dart';
import '../features/finance/application/financial_read_model_service.dart';

/// Coordinates financial read model refresh after transaction workflows.
class DashboardRefreshCoordinator {
  DashboardRefreshCoordinator({
    required this.financialReadModelService,
    required this.notifyTransactionDataChanged,
  });

  final FinancialReadModelService financialReadModelService;
  final void Function() notifyTransactionDataChanged;

  Future<List<Transaction>> refreshAllState() async {
    final model = await financialReadModelService.load(forceReload: true);
    notifyTransactionDataChanged();
    return model.transactions;
  }

  Future<void> syncAfterTransactionWorkflow() async {
    await financialReadModelService.load(forceReload: true);
  }
}
