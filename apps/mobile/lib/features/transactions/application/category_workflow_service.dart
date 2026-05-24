import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../accounts/data/account_service.dart';
import '../../budgets/data/budget_service.dart';
import '../../categories/application/category_read_model.dart';
import '../../categories/data/category_service.dart';
import '../../categories/domain/category_normalization.dart';
import '../../finance/data/financial_audit_service.dart';
import '../../profile/application/profile_service.dart';
import '../data/merchant_category_rule_service.dart';
import '../data/transaction_service.dart';
import '../domain/merchant_normalization.dart';
import '../domain/spend_categories.dart';
import 'transaction_record_mapper.dart';

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
    required this.budgetService,
    required this.merchantCategoryRuleService,
    required this.financialAuditService,
    required this.accountService,
    required this.profileService,
    required this.refreshAllState,
    required this.notifyTransactionDataChanged,
  });

  final CategoryService categoryService;
  final CategoryReadModel categoryReadModel;
  final TransactionService transactionService;
  final BudgetService budgetService;
  final MerchantCategoryRuleService merchantCategoryRuleService;
  final FinancialAuditService financialAuditService;
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
              transactionFromRecord(
                record,
                categoryNameForId: categoryReadModel.categoryNameForId,
              ),
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
      await _recordAuditEvent(
        FinancialAuditEventInput(
          eventType: 'transaction_category_bulk_updated',
          entityType: 'transaction_batch',
          entityId: entry.key,
          source: 'manual_bulk',
          newValue: {'category_id': entry.key},
          metadata: {
            'transaction_count': entry.value.length,
            'transaction_ids': entry.value,
          },
        ),
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
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: matchingIds.length > 1
            ? 'transaction_category_bulk_updated'
            : 'transaction_category_updated',
        entityType: matchingIds.length > 1
            ? 'transaction_batch'
            : 'transaction',
        entityId: matchingIds.length > 1 ? merchantKey : transactionRecord.id,
        source: learnedMerchantRule ? 'manual_merchant_rule' : 'manual',
        previousValue: {
          'category_id': transactionRecord.categoryId,
          'category_name': categoryReadModel.categoryNameForId(
            transactionRecord.categoryId,
          ),
        },
        newValue: {
          'category_id': categoryRecord.id,
          'category_name': categoryRecord.name,
        },
        metadata: {
          'transaction_count': matchingIds.length,
          'transaction_ids': matchingIds,
          if (merchantKey.isNotEmpty) 'merchant_key': merchantKey,
          'applied_to_similar_merchants': applyToSimilarMerchants,
          'learned_merchant_rule': learnedMerchantRule,
        },
      ),
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
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'category_deleted',
        entityType: 'category',
        entityId: categoryRecord.id,
        source: 'manual',
        previousValue: _categoryAuditValue(categoryRecord),
      ),
    );
    await categoryReadModel.refresh();
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> mergeCategory({
    required CategoryRecord source,
    required CategoryRecord target,
    required Iterable<TransactionRecord> transactionRecords,
    required Iterable<BudgetRecord> budgets,
  }) async {
    if (source.id == target.id) return;
    final targetKey = categoryRecordKey(
      name: target.name,
      normalizedName: target.normalizedName,
    );
    if (targetKey.isEmpty) return;

    final transactionIds = <String>[];
    for (final transaction in transactionRecords) {
      if (transaction.categoryId == source.id) {
        transactionIds.add(transaction.id);
      }
    }

    final sourceKey = categoryRecordKey(
      name: source.name,
      normalizedName: source.normalizedName,
    );
    final budgetIds = <String>[];
    for (final budget in budgets) {
      if (budget.categoryId == source.id ||
          (budget.categoryId == null && budget.categoryKey == sourceKey)) {
        budgetIds.add(budget.id);
      }
    }

    await transactionService.updateTransactionsCategory(
      ids: transactionIds,
      categoryId: target.id,
    );
    await budgetService.updateBudgetsCategoryIdentity(
      ids: budgetIds,
      categoryId: target.id,
      categoryKey: targetKey,
      name: target.name,
    );
    await merchantCategoryRuleService.updateRulesCategory(
      fromCategoryId: source.id,
      toCategoryId: target.id,
    );
    await categoryService.deleteCategory(source.id);
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'category_merged',
        entityType: 'category',
        entityId: source.id,
        source: 'manual',
        previousValue: _categoryAuditValue(source),
        newValue: _categoryAuditValue(target),
        metadata: {
          'target_category_id': target.id,
          'transaction_count': transactionIds.length,
          'transaction_ids': transactionIds,
          'budget_count': budgetIds.length,
          'budget_ids': budgetIds,
        },
      ),
    );
    await categoryReadModel.refresh();
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> setCategoryHidden(CategoryRecord category, bool hidden) async {
    final updated = await categoryService.updateCategory(
      category.id,
      hidden: hidden,
    );
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'category_visibility_updated',
        entityType: 'category',
        entityId: category.id,
        source: 'manual',
        previousValue: _categoryAuditValue(category),
        newValue: _categoryAuditValue(updated),
      ),
    );
    await categoryReadModel.refresh();
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> setMerchantRuleCategory({
    required MerchantCategoryRule rule,
    required CategoryRecord category,
  }) async {
    final updated = await merchantCategoryRuleService.updateRule(
      rule.id,
      categoryId: category.id,
    );
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'merchant_rule_category_updated',
        entityType: 'merchant_category_rule',
        entityId: rule.id,
        source: 'manual',
        previousValue: _merchantRuleAuditValue(rule),
        newValue: _merchantRuleAuditValue(updated),
      ),
    );
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> setMerchantRuleDisabled({
    required MerchantCategoryRule rule,
    required bool disabled,
  }) async {
    final updated = await merchantCategoryRuleService.updateRule(
      rule.id,
      disabled: disabled,
    );
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'merchant_rule_disabled_updated',
        entityType: 'merchant_category_rule',
        entityId: rule.id,
        source: 'manual',
        previousValue: _merchantRuleAuditValue(rule),
        newValue: _merchantRuleAuditValue(updated),
      ),
    );
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> deleteMerchantRule(MerchantCategoryRule rule) async {
    await merchantCategoryRuleService.deleteRule(rule.id);
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'merchant_rule_deleted',
        entityType: 'merchant_category_rule',
        entityId: rule.id,
        source: 'manual',
        previousValue: _merchantRuleAuditValue(rule),
      ),
    );
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> renameCategory(String oldLabel, String newLabel) async {
    final oldKey = oldLabel.trim().toLowerCase();
    final next = newLabel.trim();
    if (oldKey.isEmpty || next.isEmpty) return;
    final categoryRecord = categoryReadModel.categoryByName(oldLabel);
    if (categoryRecord == null) return;
    final updated = await categoryService.updateCategory(
      categoryRecord.id,
      name: next,
    );
    await _recordAuditEvent(
      FinancialAuditEventInput(
        eventType: 'category_renamed',
        entityType: 'category',
        entityId: categoryRecord.id,
        source: 'manual',
        previousValue: _categoryAuditValue(categoryRecord),
        newValue: _categoryAuditValue(updated),
      ),
    );
    await categoryReadModel.refresh();
    await refreshAllState();
    notifyTransactionDataChanged();
  }

  Future<void> _recordAuditEvent(FinancialAuditEventInput input) async {
    try {
      await financialAuditService.recordEvent(input);
    } on Object {
      // Audit is accountability metadata; the user-facing edit has already
      // succeeded, so a missing migration or transient write failure should not
      // make the financial mutation appear failed.
    }
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
      if (transactionCategoryKey(
            transactionFromRecord(
              record,
              categoryNameForId: categoryReadModel.categoryNameForId,
            ),
          ) ==
          targetKey) {
        return record;
      }
    }
    return null;
  }
}

Map<String, dynamic> _categoryAuditValue(CategoryRecord category) => {
  'id': category.id,
  'name': category.name,
  'normalized_name': category.normalizedName,
  'type': category.type,
  'hidden': category.hidden,
};

Map<String, dynamic> _merchantRuleAuditValue(MerchantCategoryRule rule) => {
  'id': rule.id,
  'merchant_key': rule.merchantKey,
  'merchant_display': rule.merchantDisplay,
  'aliases': rule.aliases,
  'category_id': rule.categoryId,
  'match_type': rule.matchType,
  'confidence': rule.confidence,
  'disabled': rule.disabled,
};

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
