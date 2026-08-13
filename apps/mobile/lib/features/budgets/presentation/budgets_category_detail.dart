import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../dashboard/domain/dashboard_transaction_groups.dart';
import '../../dashboard/presentation/category_detail_screen.dart';
import '../../transactions/domain/spend_categories.dart';
import '../domain/budget_models.dart';

/// Category-detail screens are month-scoped, so only monthly budgets drill in.
DateTime? budgetsCategoryDetailMonth({
  required BudgetPeriodType periodType,
  required String periodKey,
}) {
  if (periodType != BudgetPeriodType.monthly) return null;
  final parts = periodKey.split('-');
  if (parts.length < 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

void openBudgetsCategoryDetail({
  required BuildContext context,
  required DashboardUiController dashboardController,
  required TransactionUiController transactionController,
  required BudgetPerformanceSnapshot performance,
  required DateTime referenceMonth,
  required String category,
}) {
  final detailCategory = isUnresolvedCategoryLabel(category)
      ? kNeedsCategoryGroupKey
      : category;
  final normalized = detailCategory.trim().toLowerCase();
  BudgetCategoryPerformance? budget;
  for (final entry in performance.categories) {
    if (entry.displayLabel.trim().toLowerCase() == normalized) {
      budget = entry;
      break;
    }
  }
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => CategoryDetailScreen(
        controller: dashboardController,
        transactionController: transactionController,
        scope: const GlobalDashboardScope(),
        category: detailCategory,
        referenceMonth: referenceMonth,
        budget: budget,
      ),
    ),
  );
}
