import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/rex/accountability/data/accountability_api.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:clarity/rex/data/financial_context_service.dart';

final accountabilityProvider =
    NotifierProvider<AccountabilityController, AccountabilityState>(
      AccountabilityController.new,
    );

class AccountabilityState {
  const AccountabilityState({
    this.overview,
    this.isLoading = false,
    this.errorMessage,
  });

  final AccountabilityOverview? overview;
  final bool isLoading;
  final String? errorMessage;

  AccountabilityState copyWith({
    AccountabilityOverview? overview,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountabilityState(
      overview: overview ?? this.overview,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AccountabilityController extends Notifier<AccountabilityState> {
  @override
  AccountabilityState build() => const AccountabilityState();

  Future<void> loadOverview() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final financialService = ref.read(assistantFinancialContextServiceProvider);
      final budgetPerformance = financialService == null
          ? null
          : await financialService.budgetPerformanceSummary();
      final overview = await ref
          .read(accountabilityApiProvider)
          .getOverview(budgetPerformance: budgetPerformance);
      state = state.copyWith(
        overview: overview,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<bool> createPlan({required String title, String? description}) {
    return _runMutation(
      () => ref
          .read(accountabilityApiProvider)
          .createPlan(title: title, description: description),
    );
  }

  Future<bool> updatePlan(
    String planId, {
    String? title,
    String? description,
    int? priority,
    String? status,
    String? targetDateIso,
  }) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).updatePlan(
        planId,
        title: title,
        description: description,
        priority: priority,
        status: status,
        targetDateIso: targetDateIso,
      ),
    );
  }

  Future<bool> archivePlan(String planId) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).archivePlan(planId),
    );
  }

  Future<bool> createOpenThread({
    required String title,
    String? summary,
  }) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).createOpenThread(
        title: title,
        summary: summary,
      ),
    );
  }

  Future<bool> updateOpenThread(
    String threadId, {
    String? title,
    String? summary,
    String? status,
  }) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).updateOpenThread(
        threadId,
        title: title,
        summary: summary,
        status: status,
      ),
    );
  }

  Future<bool> closeOpenThread(String threadId) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).closeOpenThread(threadId),
    );
  }

  Future<bool> pauseOpenThread(String threadId) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).pauseOpenThread(threadId),
    );
  }

  Future<bool> _runMutation(Future<Object?> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      final financialService = ref.read(assistantFinancialContextServiceProvider);
      final budgetPerformance = financialService == null
          ? null
          : await financialService.budgetPerformanceSummary();
      final overview = await ref
          .read(accountabilityApiProvider)
          .getOverview(budgetPerformance: budgetPerformance);
      state = state.copyWith(
        overview: overview,
        isLoading: false,
        clearError: true,
      );
      return true;
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return false;
    }
  }
}
