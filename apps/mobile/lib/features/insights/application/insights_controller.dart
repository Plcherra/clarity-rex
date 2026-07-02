import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/rex/data/financial_context_service.dart';
import '../data/insights_api.dart';
import '../domain/insight_item.dart';

class InsightsState {
  const InsightsState({
    this.items = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.errorMessage,
    this.syncSkipped = false,
    this.syncReason,
  });

  final List<InsightItem> items;
  final bool isLoading;
  final bool isSyncing;
  final String? errorMessage;
  final bool syncSkipped;
  final String? syncReason;

  InsightsState copyWith({
    List<InsightItem>? items,
    bool? isLoading,
    bool? isSyncing,
    String? errorMessage,
    bool clearError = false,
    bool? syncSkipped,
    String? syncReason,
    bool clearSyncReason = false,
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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (syncFirst) {
        await syncFromReadModel();
      }
      final items = await ref.read(insightsApiProvider).listInsights();
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } on InsightsApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on Object catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> syncFromReadModel() async {
    state = state.copyWith(isSyncing: true, clearError: true, clearSyncReason: true);
    try {
      final financialService = ref.read(assistantFinancialContextServiceProvider);
      Map<String, dynamic>? financialContext;
      if (financialService != null) {
        financialContext = await financialService.buildSummary();
      }
      final result = await ref.read(insightsApiProvider).syncInsights(
        financialContext: financialContext,
      );
      state = state.copyWith(
        isSyncing: false,
        syncSkipped: result.skipped,
        syncReason: result.reason,
        clearError: true,
      );
    } on InsightsApiException catch (error) {
      state = state.copyWith(isSyncing: false, errorMessage: error.message);
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
      state = state.copyWith(errorMessage: error.message);
    } on Object catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }
}
