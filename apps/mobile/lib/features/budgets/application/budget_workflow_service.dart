import '../../../core/supabase/supabase_records.dart';
import '../../categories/application/category_read_model.dart';
import '../domain/budget_models.dart';
import '../data/budget_service.dart';
import '../../categories/domain/category_normalization.dart';

class BudgetWorkflowService {
  BudgetWorkflowService({
    required this.budgetService,
    required this.categoryReadModel,
    required this.notifyDashboardAndBudgetsChanged,
    required this.refreshAllState,
  });

  final BudgetService budgetService;
  final CategoryReadModel categoryReadModel;
  final void Function() notifyDashboardAndBudgetsChanged;
  final Future<void> Function() refreshAllState;

  Future<void> setActiveBudgetPeriod({
    required BudgetPeriodType type,
    required String key,
  }) async {
    notifyDashboardAndBudgetsChanged();
  }

  Future<bool> commitBudgetDraft(
    BudgetPeriodType periodType,
    String periodKey,
    List<BudgetDraftEntry> drafts,
  ) async {
    var changed = false;
    final existing = await budgetService.fetchBudgets();
    for (final draft in drafts) {
      final name = draft.displayLabel.trim();
      if (name.isEmpty) continue;
      final categoryRecord = draft.categoryId == null
          ? categoryReadModel.categoryByName(name)
          : categoryReadModel.categoryById(draft.categoryId);
      final categoryId = draft.categoryId ?? categoryRecord?.id;
      final categoryKey = draft.categoryKey.trim().isNotEmpty
          ? draft.categoryKey.trim()
          : categoryRecordKey(
              name: name,
              normalizedName: categoryRecord?.normalizedName,
            );
      if (categoryKey.isEmpty) continue;

      final existingBudget = existing.where((budget) {
        return _budgetMatchesCategory(
              budget,
              categoryId: categoryId,
              categoryKey: categoryKey,
            ) &&
            budget.period == _periodToDatabaseValue(periodType) &&
            _sameDate(budget.startDate, _startDateFor(periodType, periodKey));
      }).firstOrNull;

      final amount = draft.amount;
      if (amount == null) {
        if (existingBudget != null) {
          await budgetService.deleteBudget(existingBudget.id);
          changed = true;
        }
        continue;
      }

      if (existingBudget == null) {
        await budgetService.createBudget(
          name: name,
          categoryId: categoryId,
          categoryKey: categoryKey,
          amount: amount,
          period: _periodToDatabaseValue(periodType),
          startDate: _startDateFor(periodType, periodKey),
        );
      } else {
        await budgetService.updateBudget(
          existingBudget.id,
          name: name,
          categoryId: categoryId,
          categoryKey: categoryKey,
          amount: amount,
        );
      }
      changed = true;
    }

    if (changed) {
      await refreshAllState();
      notifyDashboardAndBudgetsChanged();
    }
    return changed;
  }
}

bool _budgetMatchesCategory(
  BudgetRecord budget, {
  required String? categoryId,
  required String categoryKey,
}) {
  final storedId = budget.categoryId?.trim();
  if (categoryId != null &&
      categoryId.trim().isNotEmpty &&
      storedId != null &&
      storedId.isNotEmpty) {
    return storedId == categoryId.trim();
  }
  return _budgetCategoryKey(budget) == categoryKey;
}

String _budgetCategoryKey(BudgetRecord budget) {
  final stored = budget.categoryKey?.trim();
  if (stored != null && stored.isNotEmpty) return stored;
  return normalizedCategoryKey(budget.name);
}

String _periodToDatabaseValue(BudgetPeriodType periodType) {
  return switch (periodType) {
    BudgetPeriodType.monthly => 'monthly',
    BudgetPeriodType.weekly => 'weekly',
    BudgetPeriodType.custom => 'custom',
  };
}

DateTime? _startDateFor(BudgetPeriodType periodType, String periodKey) {
  if (periodType == BudgetPeriodType.monthly) {
    final parts = periodKey.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return null;
    return DateTime(year, month);
  }
  final parts = periodKey.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

bool _sameDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
