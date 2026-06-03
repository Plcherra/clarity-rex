import 'package:flutter/material.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../categories/domain/category_normalization.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../transactions/domain/spend_categories.dart';
import '../domain/budget_models.dart';

part 'budgets_viewmodel_models.dart';
part 'budgets_viewmodel_periods.dart';

class BudgetsViewModel with BudgetsViewModelPeriods {
  BudgetsViewModel({required this.controller});

  @override
  final BudgetUiController controller;
  final ValueNotifier<bool> hasUnsavedChanges = ValueNotifier<bool>(false);

  Future<List<BudgetCategoryRow>> activityDrivenRows({
    required bool hasSelectedPeriod,
    required BudgetPeriodType periodType,
    required String periodKey,
    required Map<String, double> spentByDisplay,
  }) async {
    if (!hasSelectedPeriod) return const [];
    final budgets = await _fetchBudgetsForPeriod(periodType, periodKey);
    final categories = await controller.fetchBudgetCategories();
    final categoryByKey = {
      for (final category in categories)
        categoryRecordKey(
          name: category.name,
          normalizedName: category.normalizedName,
        ): category,
    };
    final rowsByCanonical = <String, BudgetCategoryRow>{};

    void putRow({
      required String displayLabel,
      String? categoryId,
      String? categoryKey,
    }) {
      final label = displayLabel.trim();
      if (label.isEmpty || isUnresolvedCategoryLabel(label)) return;
      final key = categoryKey?.trim().isNotEmpty == true
          ? categoryKey!.trim()
          : normalizedCategoryKey(label);
      if (key.isEmpty) return;
      final id = categoryId?.trim();
      final canonical = id != null && id.isNotEmpty ? 'id:$id' : 'key:$key';
      rowsByCanonical.putIfAbsent(
        canonical,
        () => BudgetCategoryRow(
          canonical: canonical,
          categoryId: id != null && id.isNotEmpty ? id : null,
          categoryKey: key,
          displayLabel: label,
        ),
      );
    }

    for (final label in controller.allowedCategoryPickerLabels) {
      final trimmed = label.trim();
      if (trimmed.isEmpty || isUnresolvedCategoryLabel(trimmed)) continue;
      final key = normalizedCategoryKey(trimmed);
      if (key.isEmpty) continue;
      final category = categoryByKey[key];
      putRow(
        displayLabel: category?.name ?? trimmed,
        categoryId: category?.id,
        categoryKey: categoryRecordKey(
          name: category?.name ?? trimmed,
          normalizedName: category?.normalizedName,
        ),
      );
    }

    for (final entry in spentByDisplay.entries) {
      final label = entry.key.trim();
      if (label.isEmpty ||
          isUnresolvedCategoryLabel(label) ||
          entry.value.abs() < 1e-9) {
        continue;
      }
      final key = normalizedCategoryKey(label);
      if (key.isEmpty) continue;
      final category = categoryByKey[key];
      putRow(
        displayLabel: category?.name ?? label,
        categoryId: category?.id,
        categoryKey: categoryRecordKey(
          name: category?.name ?? label,
          normalizedName: category?.normalizedName,
        ),
      );
    }

    for (final budget in budgets) {
      final category = budget.categoryId == null
          ? null
          : categories.where((c) => c.id == budget.categoryId).firstOrNull;
      final label = (category?.name ?? budget.name).trim();
      if (label.isEmpty || isUnresolvedCategoryLabel(label)) continue;
      putRow(
        displayLabel: label,
        categoryId: budget.categoryId ?? category?.id,
        categoryKey: _budgetCategoryKey(budget, category: category),
      );
    }

    final rows = rowsByCanonical.values.toList();
    rows.sort(
      (a, b) =>
          a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()),
    );
    return rows;
  }

  Future<BudgetsPresentationMetrics> buildPresentationMetrics({
    required bool hasSelectedPeriod,
    required BudgetPeriodType periodType,
    required String periodKey,
  }) async {
    final selectedRange = hasSelectedPeriod
        ? _budgetPeriodRangeFor(periodType: periodType, periodKey: periodKey)
        : null;
    final spentByDisplay = selectedRange == null
        ? const <String, double>{}
        : await controller.spentByDisplayCategoryForScopeInRange(
            const GlobalDashboardScope(),
            start: selectedRange.start,
            end: selectedRange.end,
          );
    final spentByIdentity = selectedRange == null
        ? const <String, double>{}
        : await controller.spentByBudgetIdentityForScopeInRange(
            const GlobalDashboardScope(),
            start: selectedRange.start,
            end: selectedRange.end,
          );

    final performance = hasSelectedPeriod
        ? await controller.budgetPerformanceForScope(
            const GlobalDashboardScope(),
            periodType: periodType,
            periodKey: periodKey,
          )
        : BudgetPerformanceSnapshot(
            periodType: periodType,
            periodKey: '',
            periodLabel: '',
            totalBudgeted: 0,
            totalSpent: 0,
            budgetedCategoryCount: 0,
            onTrackCategoryCount: 0,
            totalOverspent: 0,
            topOverspendingCategories: const [],
          );

    final totalRemaining = performance.totalBudgeted - performance.totalSpent;
    final totalOver = totalRemaining < 0 ? -totalRemaining : 0.0;
    return BudgetsPresentationMetrics(
      spentByDisplay: spentByDisplay,
      spentByIdentity: spentByIdentity,
      performance: performance,
      totalRemaining: totalRemaining,
      totalOver: totalOver,
    );
  }

  Future<List<BudgetCategoryListItemData>> buildCategoryListItems({
    required List<BudgetCategoryRow> rows,
    required bool hasSelectedPeriod,
    required BudgetPeriodType periodType,
    required String periodKey,
    required Map<String, double> spentByIdentity,
  }) async {
    final budgets = await _fetchBudgetsForPeriod(periodType, periodKey);
    final items = <BudgetCategoryListItemData>[];
    for (final row in rows) {
      final spent = spentByIdentity[row.canonical] ?? 0;
      final budget = hasSelectedPeriod
          ? _budgetForCanonical(row.canonical, budgets)
          : null;
      final overspent = budget != null && spent > budget;
      final remaining = budget == null ? null : budget - spent;
      final statusText = budget == null
          ? 'Spent ${formatMoney(spent)} · No budget'
          : overspent
          ? 'Spent ${formatMoney(spent)} · Over ${formatMoney(-remaining!)}'
          : 'Spent ${formatMoney(spent)} · Left ${formatMoney(remaining!)}';
      items.add(
        BudgetCategoryListItemData(
          canonical: row.canonical,
          displayLabel: row.displayLabel,
          statusText: statusText,
          hasBudget: budget != null,
          isOverspent: overspent,
        ),
      );
    }
    return items;
  }

  Future<void> updateUnsavedChanges({
    required List<BudgetCategoryRow> rows,
    required Map<String, TextEditingController> controllers,
    required BudgetPeriodType periodType,
    required String periodKey,
  }) async {
    hasUnsavedChanges.value = await _computeUnsavedChanges(
      rows: rows,
      controllers: controllers,
      periodType: periodType,
      periodKey: periodKey,
    );
  }

  Future<bool> _computeUnsavedChanges({
    required List<BudgetCategoryRow> rows,
    required Map<String, TextEditingController> controllers,
    required BudgetPeriodType periodType,
    required String periodKey,
  }) async {
    if (periodKey.trim().isEmpty) return false;
    final budgets = await _fetchBudgetsForPeriod(periodType, periodKey);
    for (final row in rows) {
      final raw = controllers[row.canonical]?.text.trim() ?? '';
      final draftValue = _parseBudgetRaw(raw);
      final currentValue = _budgetForCanonical(row.canonical, budgets);
      if (!_sameNullableDouble(draftValue, currentValue)) {
        return true;
      }
    }
    return false;
  }

  void clearUnsavedChanges() {
    hasUnsavedChanges.value = false;
  }

  Future<void> syncControllersFromState({
    required List<BudgetCategoryRow> rows,
    required BudgetPeriodType periodType,
    required String periodKey,
    required Map<String, TextEditingController> controllers,
    required Map<String, FocusNode> focusNodes,
  }) async {
    final budgets = await _fetchBudgetsForPeriod(periodType, periodKey);
    for (final row in rows) {
      final focus = focusNodes[row.canonical];
      final controller = controllers[row.canonical];
      if (focus == null || controller == null || focus.hasFocus) continue;
      final budget = _budgetForCanonical(row.canonical, budgets);
      final nextText = budget == null ? '' : formatBudgetSeed(budget);
      if (controller.text != nextText) {
        controller.text = nextText;
      }
    }
  }

  void ensureControllers({
    required Iterable<String> canonicalKeys,
    required Map<String, TextEditingController> controllers,
    required Map<String, FocusNode> focusNodes,
  }) {
    final keySet = canonicalKeys.toSet();
    for (final key in keySet) {
      controllers.putIfAbsent(key, TextEditingController.new);
      focusNodes.putIfAbsent(key, FocusNode.new);
    }
  }

  List<BudgetDraftEntry> buildDraft({
    required List<BudgetCategoryRow> rows,
    required Map<String, TextEditingController> controllers,
  }) {
    return [
      for (final row in rows)
        BudgetDraftEntry(
          displayLabel: row.displayLabel,
          categoryId: row.categoryId,
          categoryKey: row.categoryKey,
          amount: _parseBudgetRaw(
            controllers[row.canonical]?.text.trim() ?? '',
          ),
        ),
    ];
  }

  double? _parseBudgetRaw(String raw) {
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
  }

  bool _sameNullableDouble(double? a, double? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a - b).abs() < 1e-9;
  }

  Future<List<BudgetRecord>> _fetchBudgetsForPeriod(
    BudgetPeriodType periodType,
    String periodKey,
  ) async {
    final budgets = await controller.fetchBudgets();
    final period = _periodToDatabaseValue(periodType);
    final start = _periodStartDate(periodType, periodKey);
    return budgets.where((budget) {
      if (budget.period != period) return false;
      if (start == null) return true;
      return _sameDay(budget.startDate, start);
    }).toList();
  }

  double? _budgetForCanonical(String canonical, List<BudgetRecord> budgets) {
    for (final budget in budgets) {
      if (_budgetCanonical(budget) == canonical) return budget.amount;
    }
    return null;
  }

  String _budgetCanonical(BudgetRecord budget) {
    final id = budget.categoryId?.trim();
    if (id != null && id.isNotEmpty) return 'id:$id';
    final key = _budgetCategoryKey(budget);
    return key.isEmpty ? '' : 'key:$key';
  }

  String _budgetCategoryKey(BudgetRecord budget, {CategoryRecord? category}) {
    if (category != null) {
      return categoryRecordKey(
        name: category.name,
        normalizedName: category.normalizedName,
      );
    }
    final stored = budget.categoryKey?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return normalizedCategoryKey(budget.name);
  }

  void dispose() {
    hasUnsavedChanges.dispose();
  }
}
