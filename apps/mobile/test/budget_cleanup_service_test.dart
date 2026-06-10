import 'package:clarity/features/budgets/application/budget_cleanup_service.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes orphan budgets after account deletion', () {
    final now = DateTime.utc(2026, 6, 8);
    final groceries = _category(
      id: 'cat-grocery',
      name: 'Grocery / Supermarket',
    );
    final dining = _category(id: 'cat-dining', name: 'Dinner Out');
    final budgets = [
      _budget(id: 'budget-grocery', name: groceries.name, category: groceries),
      _budget(id: 'budget-dining', name: dining.name, category: dining),
    ];
    final removedTransactions = [
      _transaction(
        id: 'removed-grocery',
        accountId: 'deleted-account',
        categoryId: groceries.id,
        createdAt: now,
      ),
      _transaction(
        id: 'removed-dining',
        accountId: 'deleted-account',
        categoryId: dining.id,
        createdAt: now,
      ),
    ];
    final remainingTransactions = [
      _transaction(
        id: 'active-grocery',
        accountId: 'other-account',
        categoryId: groceries.id,
        createdAt: now,
      ),
    ];

    final plan = planBudgetCleanupAfterTransactionsRemoved(
      budgets: budgets,
      categories: [groceries, dining],
      removedTransactions: removedTransactions,
      remainingTransactions: remainingTransactions,
    );

    expect(plan.budgetsToDelete.map((budget) => budget.id), ['budget-dining']);
    expect(plan.customCategoryCandidates, hasLength(1));
    expect(plan.customCategoryCandidates.single.categoryId, dining.id);
  });

  test('ignores removed Plaid history when checking active transactions', () {
    final now = DateTime.utc(2026, 6, 8);
    final category = _category(id: 'cat-custom', name: 'Weekend Plans');
    final budget = _budget(
      id: 'budget-custom',
      name: category.name,
      category: category,
    );

    final plan = planBudgetCleanupAfterTransactionsRemoved(
      budgets: [budget],
      categories: [category],
      removedTransactions: [
        _transaction(
          id: 'deleted-account-row',
          accountId: 'deleted-account',
          categoryId: category.id,
          createdAt: now,
        ),
      ],
      remainingTransactions: [
        _transaction(
          id: 'removed-plaid-row',
          accountId: 'plaid-account',
          categoryId: category.id,
          createdAt: now,
          removedAt: now,
        ),
      ],
    );

    expect(plan.budgetsToDelete.single.id, budget.id);
    expect(plan.customCategoryCandidates.single.name, category.name);
  });

  test('plans one-time deletion for all orphan budgets', () {
    final now = DateTime.utc(2026, 6, 8);
    final groceries = _category(
      id: 'cat-grocery',
      name: 'Grocery / Supermarket',
    );
    final dining = _category(id: 'cat-dining', name: 'Dinner Out');
    final budgets = [
      _budget(id: 'budget-grocery', name: groceries.name, category: groceries),
      _budget(id: 'budget-dining', name: dining.name, category: dining),
    ];

    final plan = planOrphanBudgetCleanup(
      budgets: budgets,
      categories: [groceries, dining],
      remainingTransactions: [
        _transaction(
          id: 'active-grocery',
          accountId: 'connected-account',
          categoryId: groceries.id,
          createdAt: now,
        ),
        _transaction(
          id: 'removed-dining',
          accountId: 'old-plaid-account',
          categoryId: dining.id,
          createdAt: now,
          removedAt: now,
        ),
      ],
    );

    expect(plan.budgetsToDelete.map((budget) => budget.id), ['budget-dining']);
  });

  test('custom category deletion excludes built-in and hidden categories', () {
    expect(
      isManualCustomCategory(
        _category(id: 'cat-grocery', name: 'Grocery / Supermarket'),
      ),
      isFalse,
    );
    expect(
      isManualCustomCategory(
        _category(id: 'cat-hidden', name: 'Weekend Plans', hidden: true),
      ),
      isFalse,
    );
    expect(
      isManualCustomCategory(
        _category(id: 'cat-custom', name: 'Weekend Plans'),
      ),
      isTrue,
    );
  });
}

CategoryRecord _category({
  required String id,
  required String name,
  bool hidden = false,
}) {
  final now = DateTime.utc(2026, 6, 8);
  return CategoryRecord(
    id: id,
    userId: 'user-1',
    name: name,
    normalizedName: null,
    type: 'expense',
    hidden: hidden,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetRecord _budget({
  required String id,
  required String name,
  required CategoryRecord category,
}) {
  final now = DateTime.utc(2026, 6, 8);
  return BudgetRecord(
    id: id,
    userId: 'user-1',
    name: name,
    categoryId: category.id,
    categoryKey: null,
    amount: 100,
    period: 'monthly',
    startDate: DateTime.utc(2026, 6),
    createdAt: now,
    updatedAt: now,
  );
}

TransactionRecord _transaction({
  required String id,
  required String accountId,
  required String categoryId,
  required DateTime createdAt,
  DateTime? removedAt,
}) {
  return TransactionRecord(
    id: id,
    userId: 'user-1',
    accountId: accountId,
    categoryId: categoryId,
    amount: 10,
    type: 'expense',
    description: 'Test',
    date: DateTime.utc(2026, 6, 8),
    importedFromCsv: false,
    source: 'manual',
    removedAt: removedAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
