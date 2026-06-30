import 'package:flutter/material.dart';

import '../../../core/formatting/formatting.dart';
import '../../../l10n/app_localizations.dart';
import '../../../app/ui_dependencies.dart';
import '../../../core/supabase/supabase_records.dart';
import '../../categories/domain/category_display_labels.dart';
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
    Map<String, String> categoryDisplayRenames = const {},
  }) async {
    if (!hasSelectedPeriod) return const [];
    final allBudgets = await controller.fetchBudgets();
    final budgets = _budgetsForPeriod(allBudgets, periodType, periodKey);
    final categories = await controller.fetchBudgetCategories();
    final selectedRange = _budgetPeriodRangeFor(
      periodType: periodType,
      periodKey: periodKey,
    );
    final historicalSpend = selectedRange == null
        ? const <String, double>{}
        : await controller.spentByDisplayCategoryForScopeInRange(
            const GlobalDashboardScope(),
            start: DateTime(2020, 1, 1),
            end: selectedRange.end,
          );
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
      bool hasSavedBudgetHistory = false,
      bool hasTransactionHistory = false,
    }) {
      final label = displayLabel.trim();
      if (label.isEmpty || isUnresolvedCategoryLabel(label)) return;
      final key = categoryKey?.trim().isNotEmpty == true
          ? categoryKey!.trim()
          : normalizedCategoryKey(label);
      if (key.isEmpty) return;
      final id = categoryId?.trim();
      final canonical = id != null && id.isNotEmpty ? 'id:$id' : 'key:$key';
      final identityKeys = {
        canonical,
        'key:$key',
        if (id != null && id.isNotEmpty) 'id:$id',
      };
      String? existingCanonical;
      for (final entry in rowsByCanonical.entries) {
        if (identityKeys.any(entry.value.matchesIdentity)) {
          existingCanonical = entry.key;
          break;
        }
      }
      if (existingCanonical != null) {
        final existing = rowsByCanonical[existingCanonical]!;
        rowsByCanonical[existingCanonical] = existing.withIdentityKeys(
          identityKeys,
          hasSavedBudgetHistory: hasSavedBudgetHistory,
          hasTransactionHistory: hasTransactionHistory,
        );
        return;
      }
      rowsByCanonical.putIfAbsent(
        canonical,
        () => BudgetCategoryRow(
          canonical: canonical,
          categoryId: id != null && id.isNotEmpty ? id : null,
          categoryKey: key,
          displayLabel: label,
          identityKeys: identityKeys,
          hasSavedBudgetHistory: hasSavedBudgetHistory,
          hasTransactionHistory: hasTransactionHistory,
        ),
      );
    }

    void seedSpendRows(Map<String, double> spendByLabel) {
      for (final entry in spendByLabel.entries) {
        final spendLabel = entry.key.trim();
        if (spendLabel.isEmpty ||
            isUnresolvedCategoryLabel(spendLabel) ||
            entry.value.abs() < 1e-9) {
          continue;
        }
        final canonicalLabel = CategoryLabelResolver.canonicalEnglishLabelFromDisplay(
          displayLabel: spendLabel,
          renamesLowerToDisplay: categoryDisplayRenames,
        );
        final key = normalizedCategoryKey(canonicalLabel);
        if (key.isEmpty) continue;
        final category = categoryByKey[key];
        putRow(
          displayLabel: category?.name ?? canonicalLabel,
          categoryId: category?.id,
          categoryKey: categoryRecordKey(
            name: category?.name ?? canonicalLabel,
            normalizedName: category?.normalizedName,
          ),
          hasTransactionHistory: true,
        );
      }
    }

    seedSpendRows(spentByDisplay);
    seedSpendRows(historicalSpend);

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
        hasSavedBudgetHistory: true,
      );
    }

    for (final budget in allBudgets.where(
      (budget) => budget.period == _periodToDatabaseValue(periodType),
    )) {
      final category = budget.categoryId == null
          ? null
          : categories.where((c) => c.id == budget.categoryId).firstOrNull;
      final label = (category?.name ?? budget.name).trim();
      if (label.isEmpty || isUnresolvedCategoryLabel(label)) continue;
      putRow(
        displayLabel: label,
        categoryId: budget.categoryId ?? category?.id,
        categoryKey: _budgetCategoryKey(budget, category: category),
        hasSavedBudgetHistory: true,
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
    required AppLocalizations l10n,
    required List<BudgetCategoryRow> rows,
    required bool hasSelectedPeriod,
    required BudgetPeriodType periodType,
    required String periodKey,
    required Map<String, double> spentByIdentity,
    Map<String, String> categoryDisplayRenames = const {},
  }) async {
    final budgets = await _fetchBudgetsForPeriod(periodType, periodKey);
    return buildBudgetCategoryListItemsForRows(
      l10n: l10n,
      rows: rows,
      hasSelectedPeriod: hasSelectedPeriod,
      budgets: budgets,
      spentByIdentity: spentByIdentity,
      categoryDisplayRenames: categoryDisplayRenames,
    );
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
      final currentValue = _budgetForBudgetRow(row, budgets);
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
      final budget = _budgetForBudgetRow(row, budgets);
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
    return _budgetsForPeriod(budgets, periodType, periodKey);
  }

  List<BudgetRecord> _budgetsForPeriod(
    List<BudgetRecord> budgets,
    BudgetPeriodType periodType,
    String periodKey,
  ) {
    final period = _periodToDatabaseValue(periodType);
    final start = _periodStartDate(periodType, periodKey);
    return budgets.where((budget) {
      if (budget.period != period) return false;
      if (start == null) return true;
      return _sameDay(budget.startDate, start);
    }).toList();
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

List<BudgetCategoryListItemData> buildBudgetCategoryListItemsForRows({
  required AppLocalizations l10n,
  required List<BudgetCategoryRow> rows,
  required bool hasSelectedPeriod,
  required List<BudgetRecord> budgets,
  required Map<String, double> spentByIdentity,
  Map<String, String> categoryDisplayRenames = const {},
}) {
  final items = <BudgetCategoryListItemData>[];
  for (final row in rows) {
    final spent = _spentForBudgetRow(row, spentByIdentity);
    final budget = hasSelectedPeriod ? _budgetForBudgetRow(row, budgets) : null;
    if (spent.abs() < 1e-9 &&
        budget == null &&
        !row.hasSavedBudgetHistory &&
        !row.hasTransactionHistory) {
      continue;
    }
    final overspent = budget != null && spent > budget;
    final remaining = budget == null ? null : budget - spent;
    final spentLabel = formatMoney(spent);
    final statusText = budget == null
        ? l10n.budgetCategoryRowStatusNoBudget(spentLabel)
        : overspent
        ? l10n.budgetCategoryRowStatusOver(
            spentLabel,
            formatMoney(-remaining!),
          )
        : l10n.budgetCategoryRowStatusLeft(
            spentLabel,
            formatMoney(remaining!),
          );
    items.add(
      BudgetCategoryListItemData(
        canonical: row.canonical,
        displayLabel: applyCategoryDisplayRenames(
          row.displayLabel,
          categoryDisplayRenames,
        ),
        statusText: statusText,
        hasBudget: budget != null,
        isOverspent: overspent,
      ),
    );
  }
  return items;
}

double _spentForBudgetRow(
  BudgetCategoryRow row,
  Map<String, double> spentByIdentity,
) {
  var total = 0.0;
  final seenKeys = <String>{};
  for (final key in {row.canonical, ...row.identityKeys}) {
    if (seenKeys.add(key)) {
      total += spentByIdentity[key] ?? 0;
    }
  }
  return total;
}

double? _budgetForBudgetRow(BudgetCategoryRow row, List<BudgetRecord> budgets) {
  for (final budget in budgets) {
    if (row.matchesIdentity(_budgetCanonical(budget))) return budget.amount;
  }
  return null;
}

String _budgetCanonical(BudgetRecord budget) {
  final id = budget.categoryId?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';
  final key = _budgetCategoryKeyForRecord(budget);
  return key.isEmpty ? '' : 'key:$key';
}

String _budgetCategoryKeyForRecord(BudgetRecord budget) {
  final stored = budget.categoryKey?.trim();
  if (stored != null && stored.isNotEmpty) return stored;
  return normalizedCategoryKey(budget.name);
}
