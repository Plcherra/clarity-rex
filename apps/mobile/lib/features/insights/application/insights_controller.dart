import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_locale.dart';
import 'package:clarity/rex/accountability/data/accountability_api.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_service.dart';
import '../data/insights_api.dart';
import '../domain/accountability_insight_sync.dart';
import '../domain/insight_item.dart';

class InsightsState {
  const InsightsState({
    this.items = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.errorMessage,
    this.syncSkipped = false,
    this.syncReason,
    this.storageUnavailable = false,
  });

  final List<InsightItem> items;
  final bool isLoading;
  final bool isSyncing;
  final String? errorMessage;
  final bool syncSkipped;
  final String? syncReason;
  final bool storageUnavailable;

  InsightsState copyWith({
    List<InsightItem>? items,
    bool? isLoading,
    bool? isSyncing,
    String? errorMessage,
    bool clearError = false,
    bool? syncSkipped,
    String? syncReason,
    bool clearSyncReason = false,
    bool? storageUnavailable,
    bool clearStorageUnavailable = false,
  }) {
    return InsightsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      syncSkipped: syncSkipped ?? this.syncSkipped,
      syncReason: clearSyncReason
          ? null
          : (syncReason ?? this.syncReason),
      storageUnavailable: clearStorageUnavailable
          ? false
          : (storageUnavailable ?? this.storageUnavailable),
    );
  }
}

final insightsProvider = NotifierProvider<InsightsController, InsightsState>(
  InsightsController.new,
);

class InsightsController extends Notifier<InsightsState> {
  @override
  InsightsState build() => const InsightsState();

  Future<void> load({bool syncFirst = false}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearStorageUnavailable: true,
    );
    try {
      if (syncFirst) {
        await syncFromReadModel();
      }
      if (state.syncSkipped && state.syncReason == 'opt_in_required') {
        state = state.copyWith(
          items: const [],
          isLoading: false,
          clearError: true,
        );
        return;
      }
      final items = await ref.read(insightsApiProvider).listInsights();
      state = state.copyWith(
        items: items,
        isLoading: false,
        clearError: true,
        clearStorageUnavailable: true,
      );
    } on InsightsApiException catch (error) {
      if (error.isStorageUnavailable) {
        state = state.copyWith(
          items: const [],
          isLoading: false,
          storageUnavailable: true,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: _localizedInsightsError(ref, error));
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> syncFromReadModel() async {
    state = state.copyWith(
      isSyncing: true,
      clearError: true,
      clearSyncReason: true,
    );
    try {
      final financialService = ref.read(assistantFinancialContextServiceProvider);
      Map<String, dynamic>? financialContext;
      if (financialService != null) {
        financialContext = await financialService.buildSummary();
      }
      List<Map<String, dynamic>>? accountabilitySignals;
      try {
        final overview = await ref.read(accountabilityApiProvider).getOverview();
        accountabilitySignals = accountabilitySignalsForInsightSync(overview);
      } on Object {
        accountabilitySignals = null;
      }
      final result = await ref.read(insightsApiProvider).syncInsights(
        financialContext: financialContext,
        accountabilitySignals: accountabilitySignals,
      );
      state = state.copyWith(
        isSyncing: false,
        syncSkipped: result.skipped,
        syncReason: result.reason,
        clearError: true,
      );
    } on InsightsApiException catch (error) {
      if (error.isStorageUnavailable) {
        state = state.copyWith(
          isSyncing: false,
          syncSkipped: true,
          syncReason: 'storage_unavailable',
          storageUnavailable: true,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(isSyncing: false, errorMessage: _localizedInsightsError(ref, error));
    } on Object catch (error) {
      state = state.copyWith(isSyncing: false, errorMessage: error.toString());
    }
  }

  Future<void> markRead(InsightItem item) async {
    final id = item.id;
    if (id == null || !item.isUnread) return;
    try {
      final updated = await ref.read(insightsApiProvider).markRead(id);
      state = state.copyWith(
        items: [
          for (final current in state.items)
            if (current.id == updated.id) updated else current,
        ],
        clearError: true,
      );
    } on InsightsApiException catch (error) {
      state = state.copyWith(errorMessage: _localizedInsightsError(ref, error));
    } on Object catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }
}

String _localizedInsightsError(Ref ref, InsightsApiException error) {
  final key = error.messageKey;
  if (key == null) {
    return error.message;
  }
  final l10n = lookupForLocale(ref.read(localeControllerProvider).locale);
  return switch (key) {
    'insightsApiUnreadableError' => l10n.insightsApiUnreadableError,
    'insightsApiGenericError' => l10n.insightsApiGenericError,
    'insightsApiInvalidListResponse' => l10n.insightsApiInvalidListResponse,
    'insightsApiInvalidListPayload' => l10n.insightsApiInvalidListPayload,
    'insightsApiInvalidSyncResponse' => l10n.insightsApiInvalidSyncResponse,
    'insightsApiInvalidMarkReadResponse' => l10n.insightsApiInvalidMarkReadResponse,
    _ => error.message,
  };
}
