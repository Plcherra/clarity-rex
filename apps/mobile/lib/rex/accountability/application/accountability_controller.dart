import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/formatting/formatting.dart';
import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/friendly_service_error.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/rex/accountability/data/accountability_api.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';

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

  String _localizedError(Object error) {
    try {
      return friendlyServiceError(
        lookupForLocale(ref.read(localeControllerProvider).locale),
        error,
      );
    } on Object {
      return friendlyServiceError(lookupEnglishLocalizationsForTests(), error);
    }
  }

  Future<void> loadOverview() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Goals tab is plans + open threads only. Budget/rule/pattern insights
      // belong on a future Overview surface — do not attach budget_performance.
      final overview = await ref.read(accountabilityApiProvider).getOverview();
      state = state.copyWith(
        overview: overview,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _localizedError(error),
      );
    }
  }

  Future<bool> createPlan({
    required String title,
    String? description,
    DateTime? targetDate,
    double targetAmount = 0,
  }) {
    return _runMutation(
      () => ref
          .read(accountabilityApiProvider)
          .createPlan(
            title: title,
            description: description,
            targetDateIso: targetDate == null ? null : dateOnlyIso(targetDate),
            targetAmount: targetAmount,
          ),
    );
  }

  Future<bool> updatePlan(
    String planId, {
    String? title,
    String? description,
    int? priority,
    String? status,
    String? targetDateIso,
    double? targetAmount,
  }) {
    return _runMutation(
      () => ref
          .read(accountabilityApiProvider)
          .updatePlan(
            planId,
            title: title,
            description: description,
            priority: priority,
            status: status,
            targetDateIso: targetDateIso,
            targetAmount: targetAmount,
          ),
    );
  }

  /// Finishing a goal is a status change, not a delete — it moves to Achieved.
  Future<bool> markPlanAchieved(String planId) {
    return updatePlan(planId, status: 'completed');
  }

  Future<bool> reopenPlan(String planId) {
    return updatePlan(planId, status: 'active');
  }

  Future<bool> archivePlan(String planId) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).archivePlan(planId),
    );
  }

  Future<PlanMilestone?> addMilestone({
    required String planId,
    required String title,
  }) {
    return _runMutationFor(
      () => ref
          .read(accountabilityApiProvider)
          .createMilestone(planId: planId, title: title),
    );
  }

  Future<bool> setMilestoneDone(String milestoneId, {required bool done}) {
    return _runMutation(
      () => ref
          .read(accountabilityApiProvider)
          .updateMilestone(milestoneId, status: done ? 'completed' : 'open'),
    );
  }

  Future<bool> deleteMilestone(String milestoneId) {
    return _runMutation(
      () => ref.read(accountabilityApiProvider).deleteMilestone(milestoneId),
    );
  }

  Future<bool> createOpenThread({required String title, String? summary}) {
    final overview = state.overview;
    if (overview != null && overview.isAtOpenThreadLimit) {
      final l10n = lookupForLocale(ref.read(localeControllerProvider).locale);
      state = state.copyWith(
        isLoading: false,
        errorMessage: l10n.accountabilityOpenThreadMaxActive(
          AccountabilityOverview.maxActiveOpenThreads,
        ),
      );
      return Future.value(false);
    }
    return _runMutation(
      () => ref
          .read(accountabilityApiProvider)
          .createOpenThread(title: title, summary: summary),
    );
  }

  Future<bool> updateOpenThread(
    String threadId, {
    String? title,
    String? summary,
    String? status,
  }) {
    return _runMutation(
      () => ref
          .read(accountabilityApiProvider)
          .updateOpenThread(
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
    return (await _write(action)).$1;
  }

  /// For callers that need the saved record itself — a new step cannot be
  /// ticked off until its id comes back.
  Future<T?> _runMutationFor<T>(Future<T> Function() action) async {
    return (await _write(action)).$2;
  }

  Future<(bool, T?)> _write<T>(Future<T> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final saved = await action();
      final overview = await ref.read(accountabilityApiProvider).getOverview();
      state = state.copyWith(
        overview: overview,
        isLoading: false,
        clearError: true,
      );
      return (true, saved);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _localizedError(error),
      );
      return (false, null);
    }
  }
}
