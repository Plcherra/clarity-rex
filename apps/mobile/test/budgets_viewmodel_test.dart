import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/budgets/presentation/budgets_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hides inactive categories without budget or active spend', () {
    final items = buildBudgetCategoryListItemsForRows(
      rows: const [
        BudgetCategoryRow(
          canonical: 'key:grocery supermarket',
          categoryKey: 'grocery supermarket',
          displayLabel: 'Grocery / Supermarket',
          identityKeys: {'key:grocery supermarket'},
        ),
      ],
      hasSelectedPeriod: true,
      budgets: const [],
      spentByIdentity: const {},
    );

    expect(items, isEmpty);
  });

  test('matches Plaid spend by category key to a saved category-id budget', () {
    final items = buildBudgetCategoryListItemsForRows(
      rows: const [
        BudgetCategoryRow(
          canonical: 'id:cat-grocery',
          categoryId: 'cat-grocery',
          categoryKey: 'grocery supermarket',
          displayLabel: 'Grocery / Supermarket',
          identityKeys: {'id:cat-grocery', 'key:grocery supermarket'},
        ),
      ],
      hasSelectedPeriod: true,
      budgets: [
        _budget(
          id: 'budget-grocery',
          name: 'Grocery / Supermarket',
          categoryId: 'cat-grocery',
          amount: 100,
        ),
      ],
      spentByIdentity: const {'key:grocery supermarket': 42},
    );

    expect(items, hasLength(1));
    expect(items.single.displayLabel, 'Grocery / Supermarket');
    expect(items.single.hasBudget, isTrue);
    expect(items.single.statusText, 'Spent \$42.00 · Left \$58.00');
  });

  test('keeps active Plaid spend visible even when no budget exists yet', () {
    final items = buildBudgetCategoryListItemsForRows(
      rows: const [
        BudgetCategoryRow(
          canonical: 'key:coffee quick food',
          categoryKey: 'coffee quick food',
          displayLabel: 'Coffee / Quick Food',
          identityKeys: {'key:coffee quick food'},
        ),
      ],
      hasSelectedPeriod: true,
      budgets: const [],
      spentByIdentity: const {'key:coffee quick food': 6.25},
    );

    expect(items, hasLength(1));
    expect(items.single.hasBudget, isFalse);
    expect(items.single.statusText, 'Spent \$6.25 · No budget');
  });
}

BudgetRecord _budget({
  required String id,
  required String name,
  required String categoryId,
  required double amount,
}) {
  final now = DateTime.utc(2026, 6, 9);
  return BudgetRecord(
    id: id,
    userId: 'user-1',
    name: name,
    categoryId: categoryId,
    categoryKey: null,
    amount: amount,
    period: 'monthly',
    startDate: DateTime.utc(2026, 6),
    createdAt: now,
    updatedAt: now,
  );
}
