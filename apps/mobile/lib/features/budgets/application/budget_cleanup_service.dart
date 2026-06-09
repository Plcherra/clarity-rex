import '../../../core/supabase/supabase_records.dart';
import '../../categories/data/category_service.dart';
import '../../categories/domain/category_normalization.dart';
import '../../transactions/data/transaction_service.dart';
import '../../transactions/domain/spend_categories.dart';
import '../data/budget_service.dart';

final class BudgetCleanupCategoryCandidate {
  const BudgetCleanupCategoryCandidate({
    required this.categoryId,
    required this.name,
    required this.budgetCount,
  });

  final String categoryId;
  final String name;
  final int budgetCount;
}

final class BudgetCleanupPlan {
  const BudgetCleanupPlan({
    required this.budgetsToDelete,
    required this.customCategoryCandidates,
  });

  final List<BudgetRecord> budgetsToDelete;
  final List<BudgetCleanupCategoryCandidate> customCategoryCandidates;
}

final class BudgetCleanupResult {
  const BudgetCleanupResult({
    required this.deletedBudgetCount,
    required this.customCategoryCandidates,
  });

  final int deletedBudgetCount;
  final List<BudgetCleanupCategoryCandidate> customCategoryCandidates;
}

final class OrphanBudgetCleanupPlan {
  const OrphanBudgetCleanupPlan({required this.budgetsToDelete});

  final List<BudgetRecord> budgetsToDelete;
}

final class BudgetCleanupService {
  BudgetCleanupService({
    required BudgetService budgetService,
    required CategoryService categoryService,
    required TransactionService transactionService,
  }) : _budgetService = budgetService,
       _categoryService = categoryService,
       _transactionService = transactionService;

  final BudgetService _budgetService;
  final CategoryService _categoryService;
  final TransactionService _transactionService;

  Future<BudgetCleanupResult> cleanupAfterTransactionsRemoved(
    List<TransactionRecord> removedTransactions,
  ) async {
    if (removedTransactions.isEmpty) {
      return const BudgetCleanupResult(
        deletedBudgetCount: 0,
        customCategoryCandidates: [],
      );
    }

    final budgets = await _budgetService.fetchBudgets();
    final categories = await _categoryService.fetchCategories();
    final remainingTransactions = await _transactionService.fetchTransactions();
    final plan = planBudgetCleanupAfterTransactionsRemoved(
      budgets: budgets,
      categories: categories,
      removedTransactions: removedTransactions,
      remainingTransactions: remainingTransactions,
    );

    for (final budget in plan.budgetsToDelete) {
      await _budgetService.deleteBudget(budget.id);
    }

    return BudgetCleanupResult(
      deletedBudgetCount: plan.budgetsToDelete.length,
      customCategoryCandidates: plan.customCategoryCandidates,
    );
  }

  Future<void> deleteCustomCategory(String categoryId) {
    return _categoryService.deleteCategory(categoryId);
  }

  Future<int> cleanupAllOrphanedBudgets() async {
    final budgets = await _budgetService.fetchBudgets();
    final categories = await _categoryService.fetchCategories();
    final remainingTransactions = await _transactionService.fetchTransactions();
    final plan = planOrphanBudgetCleanup(
      budgets: budgets,
      categories: categories,
      remainingTransactions: remainingTransactions,
    );

    for (final budget in plan.budgetsToDelete) {
      await _budgetService.deleteBudget(budget.id);
    }

    return plan.budgetsToDelete.length;
  }
}

BudgetCleanupPlan planBudgetCleanupAfterTransactionsRemoved({
  required List<BudgetRecord> budgets,
  required List<CategoryRecord> categories,
  required List<TransactionRecord> removedTransactions,
  required List<TransactionRecord> remainingTransactions,
}) {
  final categoryById = {
    for (final category in categories) category.id: category,
  };
  final categoryByKey = {
    for (final category in categories) _categoryKey(category): category,
  };
  final affectedCategoryIds = _categoryIdsFor(removedTransactions);
  if (affectedCategoryIds.isEmpty) {
    return const BudgetCleanupPlan(
      budgetsToDelete: [],
      customCategoryCandidates: [],
    );
  }

  final affectedCategoryKeys = {
    for (final id in affectedCategoryIds)
      if (categoryById[id] case final category?) _categoryKey(category),
  }..removeWhere((key) => key.isEmpty);
  final activeCategoryIds = _categoryIdsFor(
    remainingTransactions.where((record) => record.removedAt == null),
  );
  final activeCategoryKeys = {
    for (final id in activeCategoryIds)
      if (categoryById[id] case final category?) _categoryKey(category),
  }..removeWhere((key) => key.isEmpty);

  final budgetsToDelete = <BudgetRecord>[];
  final customBudgetCountByCategoryId = <String, int>{};
  for (final budget in budgets) {
    final category = _categoryForBudget(
      budget,
      categoryById: categoryById,
      categoryByKey: categoryByKey,
    );
    if (!_budgetWasAffected(
      budget,
      category: category,
      affectedCategoryIds: affectedCategoryIds,
      affectedCategoryKeys: affectedCategoryKeys,
    )) {
      continue;
    }
    if (_budgetStillHasActiveTransactions(
      budget,
      category: category,
      activeCategoryIds: activeCategoryIds,
      activeCategoryKeys: activeCategoryKeys,
    )) {
      continue;
    }
    budgetsToDelete.add(budget);
    if (category != null && isManualCustomCategory(category)) {
      customBudgetCountByCategoryId.update(
        category.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  final candidates = [
    for (final entry in customBudgetCountByCategoryId.entries)
      if (categoryById[entry.key] case final category?)
        BudgetCleanupCategoryCandidate(
          categoryId: category.id,
          name: category.name,
          budgetCount: entry.value,
        ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return BudgetCleanupPlan(
    budgetsToDelete: budgetsToDelete,
    customCategoryCandidates: candidates,
  );
}

OrphanBudgetCleanupPlan planOrphanBudgetCleanup({
  required List<BudgetRecord> budgets,
  required List<CategoryRecord> categories,
  required List<TransactionRecord> remainingTransactions,
}) {
  final categoryById = {
    for (final category in categories) category.id: category,
  };
  final categoryByKey = {
    for (final category in categories) _categoryKey(category): category,
  };
  final activeCategoryIds = _categoryIdsFor(
    remainingTransactions.where((record) => record.removedAt == null),
  );
  final activeCategoryKeys = {
    for (final id in activeCategoryIds)
      if (categoryById[id] case final category?) _categoryKey(category),
  }..removeWhere((key) => key.isEmpty);

  return OrphanBudgetCleanupPlan(
    budgetsToDelete: [
      for (final budget in budgets)
        if (!_budgetStillHasActiveTransactions(
          budget,
          category: _categoryForBudget(
            budget,
            categoryById: categoryById,
            categoryByKey: categoryByKey,
          ),
          activeCategoryIds: activeCategoryIds,
          activeCategoryKeys: activeCategoryKeys,
        ))
          budget,
    ],
  );
}

bool isManualCustomCategory(CategoryRecord category) {
  final key = _categoryKey(category);
  if (key.isEmpty) return false;
  if (category.hidden) return false;
  if (isUnresolvedCategoryLabel(category.name)) return false;
  final builtIns = {
    for (final category in kSelectableSpendCategories)
      normalizedCategoryKey(category),
  };
  return !builtIns.contains(key);
}

Set<String> _categoryIdsFor(Iterable<TransactionRecord> records) {
  return {
    for (final record in records)
      if (record.categoryId?.trim() case final id? when id.isNotEmpty) id,
  };
}

CategoryRecord? _categoryForBudget(
  BudgetRecord budget, {
  required Map<String, CategoryRecord> categoryById,
  required Map<String, CategoryRecord> categoryByKey,
}) {
  final id = budget.categoryId?.trim();
  if (id != null && id.isNotEmpty) return categoryById[id];
  final key = budget.categoryKey?.trim();
  if (key != null && key.isNotEmpty) return categoryByKey[key];
  return categoryByKey[normalizedCategoryKey(budget.name)];
}

bool _budgetWasAffected(
  BudgetRecord budget, {
  required CategoryRecord? category,
  required Set<String> affectedCategoryIds,
  required Set<String> affectedCategoryKeys,
}) {
  final budgetCategoryId = budget.categoryId?.trim();
  if (budgetCategoryId != null &&
      budgetCategoryId.isNotEmpty &&
      affectedCategoryIds.contains(budgetCategoryId)) {
    return true;
  }
  final categoryId = category?.id;
  if (categoryId != null && affectedCategoryIds.contains(categoryId)) {
    return true;
  }
  return affectedCategoryKeys.contains(_budgetCategoryKey(budget, category));
}

bool _budgetStillHasActiveTransactions(
  BudgetRecord budget, {
  required CategoryRecord? category,
  required Set<String> activeCategoryIds,
  required Set<String> activeCategoryKeys,
}) {
  final budgetCategoryId = budget.categoryId?.trim();
  if (budgetCategoryId != null &&
      budgetCategoryId.isNotEmpty &&
      activeCategoryIds.contains(budgetCategoryId)) {
    return true;
  }
  final categoryId = category?.id;
  if (categoryId != null && activeCategoryIds.contains(categoryId)) {
    return true;
  }
  return activeCategoryKeys.contains(_budgetCategoryKey(budget, category));
}

String _budgetCategoryKey(BudgetRecord budget, CategoryRecord? category) {
  final stored = budget.categoryKey?.trim();
  if (stored != null && stored.isNotEmpty) return stored;
  if (category != null) return _categoryKey(category);
  return normalizedCategoryKey(budget.name);
}

String _categoryKey(CategoryRecord category) {
  return categoryRecordKey(
    name: category.name,
    normalizedName: category.normalizedName,
  );
}
