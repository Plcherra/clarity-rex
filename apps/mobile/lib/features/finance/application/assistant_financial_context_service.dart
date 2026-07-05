import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/features/budgets/domain/budget_models.dart';
import 'package:clarity/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_builder.dart';
import 'package:clarity/features/finance/application/financial_read_model_service.dart';

export 'assistant_financial_context_intent.dart';
export 'assistant_financial_context_builder.dart';

final assistantFinancialContextServiceProvider =
    Provider<AssistantFinancialContextService?>((ref) => null);

final class AssistantFinancialContextService {
  const AssistantFinancialContextService({
    required Future<FinancialReadModel> Function() loadFinancialReadModel,
    required DateTime Function() spendReference,
    required void Function() notifyDataChanged,
    String Function()? localeTag,
  }) : _loadFinancialReadModel = loadFinancialReadModel,
       _spendReference = spendReference,
       _notifyDataChanged = notifyDataChanged,
       _localeTag = localeTag;

  final Future<FinancialReadModel> Function() _loadFinancialReadModel;
  final DateTime Function() _spendReference;
  final void Function() _notifyDataChanged;
  final String Function()? _localeTag;

  void notifyDataChanged() {
    _notifyDataChanged();
  }

  Future<Map<String, dynamic>?> budgetPerformanceSummary() async {
    try {
      const scope = GlobalDashboardScope();
      final model = await _safeFinancialReadModel();
      final reference = model.dashboardReferenceForScope(
        scope,
        requested: _spendReference(),
      );
      final budgetPerformance = model.budgetPerformanceForScope(
        scope,
        periodType: BudgetPeriodType.monthly,
        periodKey: AssistantFinancialContextBuilder.monthKey(reference),
      );
      if (budgetPerformance.budgetedCategoryCount == 0) {
        return null;
      }
      return AssistantFinancialContextBuilder.budgetSummary(budgetPerformance);
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> unavailableSummary({
    required String source,
    required String message,
  }) {
    return AssistantFinancialContextBuilder.unavailableSummary(
      source: source,
      message: message,
    );
  }

  static Map<String, dynamic> degradedSummary({
    required String source,
    required Object error,
  }) {
    return unavailableSummary(source: source, message: error.toString());
  }

  Future<Map<String, dynamic>> buildSummary() async {
    return AssistantFinancialContextBuilder(
      loadFinancialReadModel: _loadFinancialReadModel,
      spendReference: _spendReference,
      localeTag: _localeTag,
    ).buildSummary();
  }

  Future<FinancialReadModel> _safeFinancialReadModel() async {
    try {
      return await _loadFinancialReadModel();
    } on Object catch (error) {
      return FinancialReadModel.empty(
        loadIssues: [
          FinancialReadModelLoadIssue(
            source: 'financial_read_model',
            message: error.toString(),
          ),
        ],
      );
    }
  }
}
