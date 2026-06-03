part of 'budgets_viewmodel.dart';

class BudgetCategoryRow {
  const BudgetCategoryRow({
    required this.canonical,
    required this.categoryKey,
    required this.displayLabel,
    this.categoryId,
  });

  final String canonical;
  final String categoryKey;
  final String displayLabel;
  final String? categoryId;
}

class BudgetPeriodChange {
  const BudgetPeriodChange({
    required this.periodKey,
    required this.customStart,
    required this.customEnd,
  });

  final String periodKey;
  final DateTime? customStart;
  final DateTime? customEnd;
}

class BudgetsPresentationMetrics {
  const BudgetsPresentationMetrics({
    required this.spentByDisplay,
    required this.spentByIdentity,
    required this.performance,
    required this.totalRemaining,
    required this.totalOver,
  });

  final Map<String, double> spentByDisplay;
  final Map<String, double> spentByIdentity;
  final BudgetPerformanceSnapshot performance;
  final double totalRemaining;
  final double totalOver;
}

class BudgetCategoryListItemData {
  const BudgetCategoryListItemData({
    required this.canonical,
    required this.displayLabel,
    required this.statusText,
    required this.hasBudget,
    required this.isOverspent,
  });

  final String canonical;
  final String displayLabel;
  final String statusText;
  final bool hasBudget;
  final bool isOverspent;
}
