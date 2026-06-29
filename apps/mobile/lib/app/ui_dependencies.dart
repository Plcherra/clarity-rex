import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../core/supabase/supabase_records.dart';
import '../features/accounts/application/account_workflow_service.dart';
import '../features/accounts/data/account_service.dart';
import '../features/accounts/data/plaid_account_service.dart';
import '../features/budgets/application/budget_workflow_service.dart';
import '../features/budgets/data/budget_service.dart';
import '../features/budgets/domain/budget_models.dart';
import '../features/categories/application/category_read_model.dart';
import '../features/categories/data/category_service.dart';
import '../features/categories/domain/category_normalization.dart';
import '../features/dashboard/application/dashboard_service.dart';
import '../features/dashboard/domain/dashboard_snapshot.dart';
import '../features/finance/application/financial_read_model_service.dart';
import '../features/finance/data/financial_audit_service.dart';
import '../features/plaid/application/plaid_link_service.dart';
import '../features/transactions/application/category_workflow_service.dart';
import '../features/transactions/application/import_job_status_service.dart';
import '../features/transactions/application/transaction_record_mapper.dart';
import '../features/transactions/application/transaction_workflow_service.dart';
import '../features/transactions/data/csv_import_service.dart';
import '../features/transactions/data/merchant_category_rule_service.dart';
import '../features/transactions/data/transaction_service.dart';
import '../features/transactions/domain/bank_statement_monthly.dart';
import '../features/transactions/domain/spend_categories.dart';

final class AppUiControllerBindings {
  const AppUiControllerBindings({
    required this.dashboardService,
    required this.transactionService,
    required this.categoryService,
    required this.categoryWorkflowService,
    required this.transactionWorkflowService,
    required this.categoryReadModel,
    required this.financialReadModelService,
    required this.financialAuditService,
    required this.accountService,
    required this.budgetService,
    required this.budgetWorkflowService,
    required this.importJobStatusService,
    required this.accountWorkflowService,
    required this.plaidLinkService,
    required this.plaidAccountService,
    required this.notifyImportJobStatusChanged,
  });

  final DashboardService dashboardService;
  final TransactionService transactionService;
  final CategoryService categoryService;
  final CategoryWorkflowService categoryWorkflowService;
  final TransactionWorkflowService transactionWorkflowService;
  final CategoryReadModel categoryReadModel;
  final FinancialReadModelService financialReadModelService;
  final FinancialAuditService financialAuditService;
  final AccountService accountService;
  final BudgetService budgetService;
  final BudgetWorkflowService budgetWorkflowService;
  final ImportJobStatusService importJobStatusService;
  final AccountWorkflowService accountWorkflowService;
  final PlaidLinkService plaidLinkService;
  final PlaidAccountService plaidAccountService;
  final VoidCallback notifyImportJobStatusChanged;
}

final class AppUiDependencies {
  AppUiDependencies(AppUiControllerBindings bindings)
    : dashboard = DashboardUiController._(bindings),
      transactions = TransactionUiController._(bindings),
      accounts = AccountUiController._(bindings),
      budgets = BudgetUiController._(bindings),
      importJobStatus = ImportJobStatusController._(bindings);

  final DashboardUiController dashboard;
  final TransactionUiController transactions;
  final AccountUiController accounts;
  final BudgetUiController budgets;
  final ImportJobStatusController importJobStatus;

  void notifyDashboard() => dashboard.notifyChanged();
  void notifyTransactions() => transactions.notifyChanged();
  void notifyAccounts() => accounts.notifyChanged();
  void notifyBudgets() => budgets.notifyChanged();
  void notifyImportJobStatus() => importJobStatus.notifyChanged();

  void notifyDataChanged() {
    notifyDashboard();
    notifyTransactions();
    notifyAccounts();
    notifyBudgets();
  }

  void notifyAll() {
    notifyDataChanged();
    notifyImportJobStatus();
  }

  void dispose() {
    dashboard.dispose();
    transactions.dispose();
    accounts.dispose();
    budgets.dispose();
    importJobStatus.dispose();
  }
}

base class _UiController extends ChangeNotifier {
  _UiController(this.bindings);

  final AppUiControllerBindings bindings;

  void notifyChanged() => notifyListeners();

  Future<FinancialReadModel> loadFinancialReadModel() {
    return bindings.financialReadModelService.load();
  }

  Future<List<Account>> fetchAccounts() async {
    return bindings.accountService.fetchAccounts();
  }

  Stream<List<Account>> watchAccounts() {
    return bindings.accountService.watchAccounts();
  }

  Future<List<Transaction>> fetchTransactions({String? accountId}) async {
    final model = await loadFinancialReadModel();
    if (accountId == null) return model.transactions;
    return model.transactionsByAccount[accountId] ?? const <Transaction>[];
  }

  Stream<List<Transaction>> watchTransactions({String? accountId}) {
    return bindings.transactionService
        .watchTransactions(accountId: accountId)
        .map(
          (records) => records
              .map(
                (record) => transactionFromRecord(
                  record,
                  categoryNameForId:
                      bindings.categoryReadModel.categoryNameForId,
                ),
              )
              .toList(),
        );
  }

  Future<Map<String, List<Transaction>>> fetchTransactionsByAccount() async {
    return (await loadFinancialReadModel()).transactionsByAccount;
  }
}

final class DashboardTransactionReadData {
  const DashboardTransactionReadData({
    required this.transactions,
    required this.allTransactions,
    required this.accounts,
  });

  final List<Transaction> transactions;
  final List<Transaction> allTransactions;
  final List<Account> accounts;
}

final class AccountOverviewItem {
  const AccountOverviewItem({
    required this.account,
    required this.availableThisMonth,
    required this.incomeThisMonth,
    required this.spentThisMonth,
    required this.statementBalance,
    required this.netCashFlow,
  });

  final Account account;
  final double availableThisMonth;
  final double incomeThisMonth;
  final double spentThisMonth;
  final double? statementBalance;
  final double netCashFlow;

  double get cashFlowThisMonth => availableThisMonth;

  /// Signed balance for net-worth math (credit debt is negative).
  double? get signedBalance => statementBalance;

  /// Balance shown on account cards (credit debt as a positive amount owed).
  double? get displayBalanceAmount {
    final normalized = statementBalance;
    if (normalized != null) {
      return switch (account.type) {
        AccountType.creditCard => normalized.abs(),
        AccountType.checking || AccountType.savings => normalized,
      };
    }
    return account.currentBalance;
  }

  String get balanceLabel {
    return switch (account.type) {
      AccountType.creditCard => 'Balance owed',
      AccountType.checking || AccountType.savings => 'Balance',
    };
  }
}

final class DashboardViewData {
  const DashboardViewData({
    required this.snapshot,
    required this.budgetPerformance,
    required this.scopedTransactionCount,
    required this.totalTransactionCount,
    required this.accountCount,
    required this.scopedStatementImportCount,
    required this.totalStatementImportCount,
    required this.loadIssues,
  });

  final DashboardSnapshot snapshot;
  final BudgetPerformanceSnapshot budgetPerformance;
  final int scopedTransactionCount;
  final int totalTransactionCount;
  final int accountCount;
  final int scopedStatementImportCount;
  final int totalStatementImportCount;
  final List<FinancialReadModelLoadIssue> loadIssues;

  bool get isResolvingImportedTransactions {
    return scopedTransactionCount == 0 && scopedStatementImportCount > 0;
  }

  bool get isTrulyEmpty {
    return accountCount == 0;
  }
}

final class DashboardUiController extends _UiController {
  DashboardUiController._(super.bindings);

  DateTime get spendReference => bindings.dashboardService.spendReference;

  Map<String, String> get categoryDisplayRenames =>
      bindings.categoryReadModel.categoryDisplayRenames;

  Future<DashboardSnapshot> buildSnapshot(DashboardScope scope) async {
    final model = await loadFinancialReadModel();
    final reference = _dashboardReferenceFor(model, scope);
    return model.dashboardSnapshot(scope: scope, reference: reference);
  }

  Future<DashboardViewData> dashboardViewDataForScope(
    DashboardScope scope,
  ) async {
    final model = await loadFinancialReadModel();
    final reference = _dashboardReferenceFor(model, scope);
    final snapshot = model.dashboardSnapshot(
      scope: scope,
      reference: reference,
    );
    final budgetPerformance = model.budgetPerformanceForScope(
      scope,
      periodType: BudgetPeriodType.monthly,
      periodKey: _monthKey(reference),
    );
    return DashboardViewData(
      snapshot: snapshot,
      budgetPerformance: budgetPerformance,
      scopedTransactionCount: model.transactionsForScope(scope).length,
      totalTransactionCount: model.transactions.length,
      accountCount: model.accounts.length,
      scopedStatementImportCount: model.statementImportsForScope(scope).length,
      totalStatementImportCount: model.statementImports.length,
      loadIssues: model.loadIssues,
    );
  }

  Future<BudgetPerformanceSnapshot> budgetPerformanceForScope(
    DashboardScope scope,
  ) async {
    final model = await loadFinancialReadModel();
    final reference = _dashboardReferenceFor(model, scope);
    return model.budgetPerformanceForScope(
      scope,
      periodType: BudgetPeriodType.monthly,
      periodKey: _monthKey(reference),
    );
  }

  Future<DashboardTransactionReadData> transactionReadDataForScope(
    DashboardScope scope,
  ) async {
    final model = await loadFinancialReadModel();
    return DashboardTransactionReadData(
      transactions: model.transactionsForScope(scope),
      allTransactions: model.transactions,
      accounts: model.accounts,
    );
  }

  Future<List<BankStatementLine>> refreshedLinesForMonth(
    MonthlyBankGroup group,
  ) async {
    return (await loadFinancialReadModel()).refreshedLinesForMonth(group);
  }

  Future<int> deleteTransactionsForAccountMonth({
    required String accountId,
    required String yearMonth,
  }) async {
    final range = _monthRangeFromKey(yearMonth);
    if (range == null) return 0;
    return bindings.transactionWorkflowService
        .deleteTransactionsForAccountInDateRange(
          accountId: accountId,
          start: range.start,
          endInclusive: range.endInclusive,
        );
  }

  DateTime _dashboardReferenceFor(
    FinancialReadModel model,
    DashboardScope scope,
  ) {
    final reference = model.dashboardReferenceForScope(
      scope,
      requested: bindings.dashboardService.spendReference,
    );
    bindings.dashboardService.spendReference = reference;
    return reference;
  }
}

({DateTime start, DateTime endInclusive})? _monthRangeFromKey(
  String yearMonth,
) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return (
    start: DateTime(year, month),
    endInclusive: DateTime(year, month + 1, 0),
  );
}

final class TransactionUiController extends _UiController {
  TransactionUiController._(super.bindings);

  List<String> get allowedCategoryPickerLabels =>
      bindings.categoryReadModel.allowedCategoryPickerLabels;

  List<String> get customCategories =>
      bindings.categoryReadModel.customCategories;

  Map<String, String> get categoryDisplayRenames =>
      bindings.categoryReadModel.categoryDisplayRenames;

  Set<String> get categoriesHiddenFromPicker =>
      bindings.categoryReadModel.categoriesHiddenFromPicker;

  Map<String, String> get transactionCategoryAssignments => const {};

  Map<String, String> get merchantCategoryMemory => const {};

  Future<MerchantLearningPreview?> previewMerchantLearningImpact(
    Transaction transaction,
  ) {
    return bindings.categoryWorkflowService.previewMerchantLearningImpact(
      transaction,
    );
  }

  Future<CategoryAssignmentResult> setCategoryOverride(
    Transaction transaction,
    String category, {
    bool applyToSimilarMerchants = true,
  }) {
    return bindings.categoryWorkflowService.setCategoryOverride(
      transaction,
      category,
      applyToSimilarMerchants: applyToSimilarMerchants,
    );
  }

  Future<void> bulkSetCategoryOverrides(
    Iterable<Transaction> transactions,
    String category,
  ) {
    final keyToCategory = <String, String>{
      for (final transaction in transactions)
        transactionCategoryKey(transaction): category,
    };
    return bindings.categoryWorkflowService.bulkSetCategoryOverrides(
      keyToCategory,
      availableTransactions: transactions,
    );
  }

  Future<CategoryAssignmentResult> createCategoryAndAssign(
    Transaction transaction,
    String rawName, {
    bool applyToSimilarMerchants = true,
  }) {
    return bindings.categoryWorkflowService.createCategoryAndAssign(
      transaction,
      rawName,
      applyToSimilarMerchants: applyToSimilarMerchants,
    );
  }

  Future<void> deleteCategory(String canonicalLabel) {
    return bindings.categoryWorkflowService.deleteCategory(canonicalLabel);
  }

  Future<void> renameCategory(String oldLabel, String newLabel) {
    return bindings.categoryWorkflowService.renameCategory(oldLabel, newLabel);
  }

  Future<bool> deleteTransaction(Transaction transaction) {
    return bindings.transactionWorkflowService.deleteTransaction(transaction);
  }

  Future<bool> setFinancialRoleOverride(
    Transaction transaction,
    FinancialRole? role,
  ) {
    return bindings.transactionWorkflowService.setFinancialRoleOverride(
      transaction,
      role,
    );
  }
}

final class AccountUiController extends _UiController {
  AccountUiController._(super.bindings);

  Future<List<Account>> get accounts => fetchAccounts();

  Future<List<AccountOverviewItem>> get accountOverviewItems async {
    final model = await loadFinancialReadModel();
    final requested = bindings.dashboardService.spendReference;
    return [
      for (final account in model.accounts)
        () {
          final display = model.accountFinancialDisplay(
            account: account,
            requested: requested,
          );
          return AccountOverviewItem(
            account: account,
            availableThisMonth: display.availableThisMonth,
            incomeThisMonth: display.incomeThisMonth,
            spentThisMonth: display.spentThisMonth,
            statementBalance: display.statementBalance,
            netCashFlow: display.netCashFlow,
          );
        }(),
    ];
  }

  Future<Account?> addAccount(Account account) async {
    return bindings.accountWorkflowService.addAccount(account);
  }

  Future<PlaidConnectionResult> connectBank() {
    return bindings.plaidLinkService.connectBank();
  }

  Future<PlaidItemStatus> plaidItemStatus(String itemId) {
    return bindings.plaidAccountService.fetchItemStatus(itemId);
  }

  Future<PlaidSyncSummary> refreshPlaidItem(String itemId) {
    return bindings.plaidAccountService.syncItem(itemId);
  }

  Future<PlaidDisconnectSummary> disconnectPlaidItem(String itemId) {
    return bindings.plaidAccountService.disconnectItem(itemId);
  }

  Future<AccountDeletionResult> deleteAccount(String accountId) async {
    return bindings.accountWorkflowService.deleteAccount(accountId);
  }

  Future<void> deleteUnusedCustomCategory(String categoryId) async {
    await bindings.accountWorkflowService.deleteUnusedCustomCategory(
      categoryId,
    );
    notifyChanged();
  }

  Future<CsvImportPreview> previewCsvImport(
    String utf8Text, {
    required String accountId,
  }) {
    return bindings.transactionWorkflowService.previewCsvImport(
      utf8Text,
      accountId: accountId,
    );
  }

  Future<void> loadFromCsv(String utf8Text, {required String accountId}) async {
    await bindings.transactionWorkflowService.loadFromCsv(
      utf8Text,
      accountId: accountId,
    );
  }

  void showImportPreparationProgress(String message) {
    bindings.importJobStatusService.applyCsvImportProgress(
      CsvImportProgress(
        stage: CsvImportStage.parsing,
        value: 0.01,
        message: message,
      ),
      notifyStatusChanged: bindings.notifyImportJobStatusChanged,
    );
  }

  void clearImportJobStatus() {
    bindings.importJobStatusService.clear(
      notifyStatusChanged: bindings.notifyImportJobStatusChanged,
    );
  }

  Future<List<CsvImportBatchSummary>> csvImportBatchesForAccount(
    String accountId,
  ) async {
    final id = accountId.trim();
    if (id.isEmpty) return const [];
    final records = await bindings.transactionService.fetchTransactions(
      accountId: id,
    );
    final counts = <String, int>{};
    for (final record in records) {
      final importId = record.importId?.trim();
      if (importId == null || importId.isEmpty) continue;
      counts[importId] = (counts[importId] ?? 0) + 1;
    }
    final summaries = <CsvImportBatchSummary>[
      for (final entry in counts.entries)
        CsvImportBatchSummary(
          importId: entry.key,
          transactionCount: entry.value,
          importedAtUtc: _importedAtFromImportId(entry.key),
        ),
    ];
    summaries.sort((a, b) {
      final ai = a.importedAtUtc?.microsecondsSinceEpoch;
      final bi = b.importedAtUtc?.microsecondsSinceEpoch;
      if (ai != null && bi != null && ai != bi) return bi.compareTo(ai);
      return b.importId.compareTo(a.importId);
    });
    return summaries;
  }

  Future<int> deleteTransactionsForImportBatch({
    required String accountId,
    required String importId,
  }) async {
    return bindings.transactionWorkflowService.deleteTransactionsForImportBatch(
      accountId: accountId,
      importId: importId,
    );
  }
}

final class BudgetUiController extends _UiController {
  BudgetUiController._(super.bindings);

  DateTime get spendReference => bindings.dashboardService.spendReference;

  List<String> get customCategories =>
      bindings.categoryReadModel.customCategories;

  List<String> get allowedCategoryPickerLabels =>
      bindings.categoryReadModel.allowedCategoryPickerLabels;

  Map<String, String> get categoryDisplayRenames =>
      bindings.categoryReadModel.categoryDisplayRenames;

  Set<String> get categoriesHiddenFromPicker =>
      bindings.categoryReadModel.categoriesHiddenFromPicker;

  String budgetWeekStartKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return _dateOnly(monday);
  }

  String ensureCustomBudgetPeriod(DateTime start, DateTime end) {
    return '${_dateOnly(start)}_${_dateOnly(end)}';
  }

  Future<void> setActiveBudgetPeriod({
    required BudgetPeriodType type,
    required String key,
  }) {
    return bindings.budgetWorkflowService.setActiveBudgetPeriod(
      type: type,
      key: key,
    );
  }

  Future<List<BudgetRecord>> fetchBudgets() async {
    return (await loadFinancialReadModel()).budgets;
  }

  Future<bool> commitBudgetDraft(
    BudgetPeriodType periodType,
    String periodKey,
    List<BudgetDraftEntry> drafts,
  ) async {
    return bindings.budgetWorkflowService.commitBudgetDraft(
      periodType,
      periodKey,
      drafts,
    );
  }

  Future<BudgetPerformanceSnapshot> budgetPerformanceForScope(
    DashboardScope scope, {
    BudgetPeriodType? periodType,
    String? periodKey,
  }) async {
    final effectiveType = periodType ?? BudgetPeriodType.monthly;
    final effectiveKey = periodKey ?? _monthKey(spendReference);
    final model = await loadFinancialReadModel();
    return model.budgetPerformanceForScope(
      scope,
      periodType: effectiveType,
      periodKey: effectiveKey,
    );
  }

  Future<List<CategoryRecord>> fetchBudgetCategories() async {
    return (await loadFinancialReadModel()).categories;
  }

  Future<List<FinancialAuditEvent>> fetchRecentFinancialAuditEvents() {
    return bindings.financialAuditService.fetchRecent(limit: 30);
  }

  Future<CategoryRecord> createBudgetCategory(String rawName) async {
    final created = await bindings.categoryReadModel.ensureExpenseCategory(
      rawName,
    );
    notifyChanged();
    return created;
  }

  Future<void> renameBudgetCategory(String oldLabel, String newLabel) async {
    await bindings.categoryWorkflowService.renameCategory(oldLabel, newLabel);
    notifyChanged();
  }

  Future<void> deleteBudgetCategory(String label) async {
    await bindings.categoryWorkflowService.deleteCategory(label);
    notifyChanged();
  }

  Future<void> mergeBudgetCategory({
    required CategoryRecord source,
    required CategoryRecord target,
    required FinancialReadModel model,
  }) async {
    await bindings.categoryWorkflowService.mergeCategory(
      source: source,
      target: target,
      transactionRecords: model.transactionRecords,
      budgets: model.budgets,
    );
    notifyChanged();
  }

  Future<void> setBudgetCategoryHidden(
    CategoryRecord category,
    bool hidden,
  ) async {
    await bindings.categoryWorkflowService.setCategoryHidden(category, hidden);
    notifyChanged();
  }

  Future<void> setMerchantRuleCategory({
    required MerchantCategoryRule rule,
    required CategoryRecord category,
  }) async {
    await bindings.categoryWorkflowService.setMerchantRuleCategory(
      rule: rule,
      category: category,
    );
    notifyChanged();
  }

  Future<void> setMerchantRuleDisabled({
    required MerchantCategoryRule rule,
    required bool disabled,
  }) async {
    await bindings.categoryWorkflowService.setMerchantRuleDisabled(
      rule: rule,
      disabled: disabled,
    );
    notifyChanged();
  }

  Future<void> deleteMerchantRule(MerchantCategoryRule rule) async {
    await bindings.categoryWorkflowService.deleteMerchantRule(rule);
    notifyChanged();
  }

  bool isCustomBudgetCategory(CategoryRecord category) {
    final key = categoryRecordKey(
      name: category.name,
      normalizedName: category.normalizedName,
    );
    final builtIns = {
      for (final label in kSelectableSpendCategories)
        normalizedCategoryKey(label),
    };
    return category.type == 'expense' &&
        !builtIns.contains(key) &&
        !isUnresolvedCategoryLabel(category.name) &&
        !isIgnoredCategoryLabel(category.name) &&
        !isIncomeCategoryLabel(category.name);
  }

  Future<Map<String, double>> spentByDisplayCategoryForScopeInRange(
    DashboardScope scope, {
    required DateTime start,
    required DateTime end,
  }) async {
    return (await loadFinancialReadModel())
        .spentByDisplayCategoryForScopeInRange(scope, start: start, end: end);
  }

  Future<Map<String, double>> spentByBudgetIdentityForScopeInRange(
    DashboardScope scope, {
    required DateTime start,
    required DateTime end,
  }) async {
    return (await loadFinancialReadModel())
        .spentByBudgetIdentityForScopeInRange(scope, start: start, end: end);
  }
}

final class ImportJobStatusController extends _UiController {
  ImportJobStatusController._(super.bindings);

  bool get importRunning => bindings.importJobStatusService.importRunning;

  int get importProgressCompleted =>
      bindings.importJobStatusService.importProgressCompleted;

  int get importProgressTotal =>
      bindings.importJobStatusService.importProgressTotal;

  String get importProgressMessage =>
      bindings.importJobStatusService.importProgressMessage;

  void configureIdleProgressMessage(String message) {
    bindings.importJobStatusService.configureIdleProgressMessage(message);
  }

  String? get persistentImportMessage =>
      bindings.importJobStatusService.persistentImportMessage;

  bool get persistentImportMessageIsError =>
      bindings.importJobStatusService.persistentImportMessageIsError;

  bool get persistentImportMessageHasFallbackCategories => bindings
      .importJobStatusService
      .persistentImportMessageHasFallbackCategories;

  bool get persistentImportMessageCanRetry =>
      bindings.importJobStatusService.persistentImportMessageCanRetry;

  ImportRepairSummary? get persistentImportSummary =>
      bindings.importJobStatusService.persistentImportSummary;

  String? consumeImportSnackMessage() {
    return bindings.importJobStatusService.consumeImportSnackMessage();
  }

  Future<void> retryCategoryAssignment() async {
    final accountId = bindings.importJobStatusService.repairImportAccountId;
    final importId = bindings.importJobStatusService.repairImportId;
    if (accountId == null || importId == null) return;
    await bindings.transactionWorkflowService.retryImportCategoryAssignment(
      accountId: accountId,
      importId: importId,
    );
  }

  void dismissPersistentImportMessage() {
    bindings.importJobStatusService.dismissPersistentImportMessage(
      notifyStatusChanged: notifyChanged,
    );
  }
}

String _monthKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

String _dateOnly(DateTime date) {
  return date.toIso8601String().split('T').first;
}

DateTime? _importedAtFromImportId(String importId) {
  final micros = int.tryParse(importId);
  if (micros == null) return null;
  return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
}
