import '../../../core/models/models.dart';
import '../../budgets/application/budget_cleanup_service.dart';
import '../../transactions/data/transaction_service.dart';
import '../data/account_service.dart';

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.deleted,
    required this.deletedBudgetCount,
    required this.customCategoryCandidates,
  });

  final bool deleted;
  final int deletedBudgetCount;
  final List<BudgetCleanupCategoryCandidate> customCategoryCandidates;
}

class AccountWorkflowService {
  AccountWorkflowService({
    required this.accountService,
    required this.transactionService,
    required this.budgetCleanupService,
    required this.refreshAllState,
    required this.notifyAccountsChanged,
  });

  final AccountService accountService;
  final TransactionService transactionService;
  final BudgetCleanupService budgetCleanupService;
  final Future<void> Function() refreshAllState;
  final void Function() notifyAccountsChanged;

  Future<Account?> addAccount(Account account) async {
    try {
      final created = await accountService.createAccount(account);
      notifyAccountsChanged();
      await refreshAllState();
      return created;
    } on Object {
      return null;
    }
  }

  Future<AccountDeletionResult> deleteAccount(String accountId) async {
    final id = accountId.trim();
    final removedTransactions = await transactionService.fetchTransactions(
      accountId: id,
    );
    await accountService.deleteAccount(id);
    final cleanup = await budgetCleanupService.cleanupAfterTransactionsRemoved(
      removedTransactions,
    );
    notifyAccountsChanged();
    await refreshAllState();
    return AccountDeletionResult(
      deleted: true,
      deletedBudgetCount: cleanup.deletedBudgetCount,
      customCategoryCandidates: cleanup.customCategoryCandidates,
    );
  }

  Future<void> deleteUnusedCustomCategory(String categoryId) async {
    await budgetCleanupService.deleteCustomCategory(categoryId);
    notifyAccountsChanged();
    await refreshAllState();
  }
}
