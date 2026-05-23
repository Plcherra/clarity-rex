import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../accounts/data/account_service.dart';
import '../../categories/application/category_read_model.dart';
import '../../categories/data/category_service.dart';
import '../../categories/domain/category_normalization.dart';
import '../../profile/application/profile_service.dart';
import '../data/merchant_category_rule_service.dart';
import '../data/transaction_service.dart';
import '../domain/merchant_normalization.dart';
import '../domain/spend_categories.dart';

class MerchantLearningPreview {
  const MerchantLearningPreview({
    required this.merchantKey,
    required this.merchantDisplay,
    required this.matchingTransactionCount,
  });

  final String merchantKey;
  final String merchantDisplay;
  final int matchingTransactionCount;
}

class CategoryAssignmentResult {
  const CategoryAssignmentResult({
    required this.updatedTransactionCount,
    required this.learnedMerchantRule,
    required this.appliedToSimilarMerchants,
  });

  final int updatedTransactionCount;
  final bool learnedMerchantRule;
  final bool appliedToSimilarMerchants;
}

class CategoryWorkflowService {
  CategoryWorkflowService({
    required this.categoryService,
    required this.categoryReadModel,
    required this.transactionService,
    required this.merchantCategoryRuleService,
    required this.accountService,
    required this.profileService,
    required this.refreshAllState,
    required this.notifyTransactionDataChanged,
  });

  final CategoryService categoryService;
  final CategoryReadModel categoryReadModel;
  final TransactionService transactionService;
  final MerchantCategoryRuleService merchantCategoryRuleService;
  final AccountService accountService;
  final ProfileService profileService;
  final Future<void> Function() refreshAllState;
  final void Function() notifyTransactionDataChanged;

  Future<CategoryAssignmentResult> setCategoryOverride(
    Transaction transaction,
    String category, {
    bool applyToSimilarMerchants = false,
  }) async {
    return _assignCategoryAndLearnMerchantRule(
      transaction: transaction,
      categoryName: category,
      applyToSimilarMerchants: applyToSimilarMerchants,
    );
  }

  Future<void> bulkSetCategoryOverrides(
    Map<String, String> keyToCanonicalCategory, {
    Iterable<Transaction>? availableTransactions,
    bool refreshAfter = true,
  }) async {
    if (keyToCanonicalCategory.isEmpty) return;
    final transactionIdsByKey = <String, String>{};
    if (availableTransactions != null) {
      for (final transaction in availableTransactions) {
        final id = transaction.fingerprint?.trim();
        if (id == null || id.isEmpty) continue;
        transactionIdsByKey[transactionCategoryKey(transaction)] = id;
      }
    } else {
      final records = await transactionService.fetchTransactions();
      for (final record in records) {
        transactionIdsByKey[transactionCategoryKey(
              _transactionFromRecord(record),
            )] =
            record.id;
      }
    }

    final categoryByName = <String, CategoryRecord>{};
    for (final categoryName in keyToCanonicalCategory.values) {
      final name = categoryName.trim();
      final normalized = normalizeCategoryName(name);
      if (normalized == null ||
          categoryByName.containsKey(normalized.normalizedName)) {
        continue;
      }
      categoryByName[normalized.normalizedName] = await categoryReadModel
          .ensureExpenseCategory(normalized.displayName);
    }

    final transactionIdsByCategoryId = <String, List<String>>{};
    for (final entry in keyToCanonicalCategory.entries) {
      final categoryName = entry.value.trim();
      if (categoryName.isEmpty) continue;
      final transactionId = transactionIdsByKey[entry.key];
      if (transactionId == null) continue;
      final normalized = normalizeCategoryName(categoryName);
      if (normalized == null) continue;
      final categoryRecord = categoryByName[normalized.normalizedName];
      if (categoryRecord == null) continue;
      transactionIdsByCategoryId
          .putIfAbsent(categoryRecord.id, () => <String>[])
          .add(transactionId);
    }

    for (final entry in transactionIdsByCategoryId.entries) {
      await transactionService.updateTransactionsCategory(
        ids: entry.value,
        categoryId: entry.key,
      );
    }
    if (refreshAfter) {
      await refreshAllState();
      notifyTransactionDataChanged();
    }
  }

  Future<CategoryAssignmentResult> createCategoryAndAssign(
    Transaction transaction,
    String rawName, {
    bool applyToSimilarMerchants = false,
  }) async {
    final name = rawName.trim();
    if (name.isEmpty || name.toLowerCase() == 'uncategorized') {
      return const CategoryAssignmentResult(
        updatedTransactionCount: 0,
        learnedMerchantRule: false,
        appliedToSimilarMerchants: false,
      );
    }
    return _assignCategoryAndLearnMerchantRule(
      transaction: transaction,
      categoryName: name,
      applyToSimilarMerchants: applyToSimilarMerchants,
    );
  }

  Future<MerchantLearningPreview?> previewMerchantLearningImpact(
    Transaction transaction,
  ) async {
    final transactionRecord = await _findRecordForTransaction(transaction);
    if (transactionRecord == null) return null;

    final merchantDisplay =
        transactionRecord.description ?? transaction.description;
    final merchantKey = merchantKeyLowerFromDescription(merchantDisplay);
    if (merchantKey.isEmpty) return null;

    final matchingIds = matchingMerchantTransactionIds(
      merchantKey: merchantKey,
      records: await transactionService.fetchTransactions(),
    );
    if (!matchingIds.contains(transactionRecord.id)) {
      matchingIds.add(transactionRecord.id);
    }
    return MerchantLearningPreview(
      merchantKey: merchantKey,
      merchantDisplay: merchantDisplay,
      matchingTransactionCount: matchingIds.length,
    );
  }

  Future<CategoryAssignmentResult> _assignCategoryAndLearnMerchantRule({
    required Transaction transaction,
    required String categoryName,
    required bool applyToSimilarMerchants,
  }) async {
    final categoryRecord = await categoryReadModel.ensureExpenseCategory(
      categoryName,
    );
    final transactionRecord = await _findRecordForTransaction(transaction);
    if (transactionRecord == null) {
      return const CategoryAssignmentResult(
        updatedTransactionCount: 0,
        learnedMerchantRule: false,
        appliedToSimilarMerchants: false,
      );
    }

    final merchantKey = merchantKeyLowerFromDescription(
      transactionRecord.description ?? transaction.description,
    );
    final matchingIds = !applyToSimilarMerchants || merchantKey.isEmpty
        ? <String>[transactionRecord.id]
        : matchingMerchantTransactionIds(
            merchantKey: merchantKey,
            records: await transactionService.fetchTransactions(),
          );
    if (!matchingIds.contains(transactionRecord.id)) {
      matchingIds.add(transactionRecord.id);
    }

    var learnedMerchantRule = false;
    if (applyToSimilarMerchants && merchantKey.isNotEmpty) {
      await merchantCategoryRuleService.upsertRule(
        merchantKey: merchantKey,
        merchantDisplay:
            transactionRecord.description ?? transaction.description,
        categoryId: categoryRecord.id,
      );
      learnedMerchantRule = true;
    }

    await transactionService.updateTransactionsCategory(
      ids: matchingIds,
      categoryId: categoryRecord.id,
    );
    await refreshAllState();
    notifyTransactionDataChanged();
    return CategoryAssignmentResult(
      updatedTransactionCount: matchingIds.length,
      learnedMerchantRule: learnedMerchantRule,
      appliedToSimilarMerchants:
          applyToSimilarMerchants && matchingIds.length > 1,
    );
  }

  Future<void> deleteCategory(String canonicalLabel) async {
    final key = canonicalLabel.trim().toLowerCase();
    if (key.isEmpty) return;
    final categoryRecord = categoryReadModel.categoryByName(canonicalLabel);
    if (categoryRecord == null) return;
    await categoryService.deleteCategory(categoryRecord.id);
    await categoryReadModel.refresh();
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> renameCategory(String oldLabel, String newLabel) async {
    final oldKey = oldLabel.trim().toLowerCase();
    final next = newLabel.trim();
    if (oldKey.isEmpty || next.isEmpty) return;
    final categoryRecord = categoryReadModel.categoryByName(oldLabel);
    if (categoryRecord == null) return;
    await categoryService.updateCategory(categoryRecord.id, name: next);
    await categoryReadModel.refresh();
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<TransactionRecord?> _findRecordForTransaction(
    Transaction transaction,
  ) async {
    final id = transaction.fingerprint?.trim();
    if (id != null && id.isNotEmpty) {
      final records = await transactionService.fetchTransactions(
        accountId: transaction.accountId,
      );
      for (final record in records) {
        if (record.id == id) return record;
      }
    }

    final records = await transactionService.fetchTransactions(
      accountId: transaction.accountId,
    );
    final targetKey = transactionCategoryKey(transaction);
    for (final record in records) {
      if (transactionCategoryKey(_transactionFromRecord(record)) == targetKey) {
        return record;
      }
    }
    return null;
  }
}

List<String> matchingMerchantTransactionIds({
  required String merchantKey,
  required Iterable<TransactionRecord> records,
}) {
  final key = merchantKey.trim().toLowerCase();
  if (key.isEmpty) return <String>[];

  final ids = <String>[];
  for (final record in records) {
    final recordKey = merchantKeyLowerFromDescription(
      record.description ?? record.merchant ?? '',
    );
    if (recordKey == key) ids.add(record.id);
  }
  return ids;
}

Transaction _transactionFromRecord(TransactionRecord record) {
  final amount = switch (record.type.trim().toLowerCase()) {
    'expense' => -record.amount.abs(),
    'income' => record.amount.abs(),
    _ => record.amount,
  };
  return Transaction(
    date: record.date,
    description: record.description ?? record.merchant ?? '',
    amount: amount,
    accountId: record.accountId,
    categoryId: record.categoryId,
    importId: record.importId ?? (record.importedFromCsv ? 'csv' : null),
    fingerprint: record.id,
    financialRole: record.type.trim().toLowerCase() == 'income'
        ? FinancialRole.income
        : FinancialRole.expense,
  );
}
