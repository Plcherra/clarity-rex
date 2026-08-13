import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/budgets/presentation/budgets_category_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly period keys resolve to a category-detail month', () {
    expect(
      budgetsCategoryDetailMonth(
        periodType: BudgetPeriodType.monthly,
        periodKey: '2026-03',
      ),
      DateTime(2026, 3),
    );
  });

  test('weekly and custom periods do not drill into month detail', () {
    expect(
      budgetsCategoryDetailMonth(
        periodType: BudgetPeriodType.weekly,
        periodKey: '2026-03-02',
      ),
      isNull,
    );
    expect(
      budgetsCategoryDetailMonth(
        periodType: BudgetPeriodType.custom,
        periodKey: '2026-03-01_2026-03-15',
      ),
      isNull,
    );
  });
}
