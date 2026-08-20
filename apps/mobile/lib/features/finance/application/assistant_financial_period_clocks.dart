import 'package:clarity/features/finance/application/assistant_financial_context_records.dart';
import 'package:clarity/features/transactions/domain/transaction_resolution.dart';

/// Grocery, coffee, and Food & Drink — what people mean by "food spending".
bool isFoodSpendCategoryLabel(String label) {
  final normalized = label.trim().toLowerCase();
  return normalized.contains('grocery') ||
      normalized.contains('supermarket') ||
      normalized.contains('food') ||
      normalized.contains('coffee') ||
      normalized.contains('restaurant');
}

/// This-month / this-week / food clocks Rex must use instead of summing rows.
Map<String, dynamic> buildAssistantPeriodClocks({
  required List<ResolvedTransaction> resolved,
  required DateTime reference,
}) {
  final weekStart = startOfIsoWeek(reference);
  final weekEnd = weekStart.add(const Duration(days: 7));
  var spentThisWeek = 0.0;
  var foodThisMonth = 0.0;
  final foodCategories = <String>{};

  for (final row in resolved) {
    if (!row.countsAsSpend) {
      continue;
    }
    final date = row.transaction.date;
    final inWeek = !date.isBefore(weekStart) && date.isBefore(weekEnd);
    if (inWeek) {
      spentThisWeek += row.transaction.amount.abs();
    }
    if (date.year == reference.year &&
        date.month == reference.month &&
        isFoodSpendCategoryLabel(row.displayCategory)) {
      foodThisMonth += row.transaction.amount.abs();
      foodCategories.add(row.displayCategory.trim());
    }
  }

  return {
    'spent_this_week': money(spentThisWeek),
    'food_spend_this_month': money(foodThisMonth),
    'food_categories_this_month': foodCategories.toList()..sort(),
    'week_start': dateOnly(weekStart),
    'week_end': dateOnly(weekEnd.subtract(const Duration(days: 1))),
    'answer_clocks':
        'For this month use cash_flow.spent_this_month. '
        'For this week use spent_this_week. '
        'For food this month use food_spend_this_month. '
        'Do not sum transactions or transaction_slices for those totals.',
  };
}

DateTime startOfIsoWeek(DateTime reference) {
  final day = DateTime(reference.year, reference.month, reference.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
