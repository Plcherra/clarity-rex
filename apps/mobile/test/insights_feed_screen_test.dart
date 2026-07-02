import 'package:clarity/features/insights/data/insights_api.dart';
import 'package:clarity/features/insights/domain/insight_item.dart';
import 'package:clarity/features/insights/presentation/insights_feed_screen.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InsightsFeedScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsApiProvider.overrideWithValue(_FakeInsightsApi()),
          assistantFinancialContextServiceProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InsightsFeedScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved insights yet'), findsOneWidget);
  });

  testWidgets('InsightsFeedScreen degrades when storage unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsApiProvider.overrideWithValue(
            _StorageUnavailableInsightsApi(),
          ),
          assistantFinancialContextServiceProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InsightsFeedScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Supabase memory'), findsNothing);
    expect(find.textContaining('Saved insights are not available yet'), findsOneWidget);
    expect(find.textContaining('No saved insights yet'), findsOneWidget);
  });
}

class _FakeInsightsApi extends InsightsApi {
  @override
  Future<List<InsightItem>> listInsights({int limit = 50}) async => [];

  @override
  Future<InsightSyncResult> syncInsights({
    Map<String, dynamic>? financialContext,
    List<Map<String, dynamic>>? accountabilitySignals,
  }) async {
    return const InsightSyncResult(skipped: true, reason: 'opt_in_required');
  }
}

class _StorageUnavailableInsightsApi extends InsightsApi {
  @override
  Future<List<InsightItem>> listInsights({int limit = 50}) async {
    throw const InsightsApiException(
      'Insights storage is not available yet.',
      errorCode: 'insights_storage_unavailable',
    );
  }

  @override
  Future<InsightSyncResult> syncInsights({
    Map<String, dynamic>? financialContext,
    List<Map<String, dynamic>>? accountabilitySignals,
  }) async {
    return const InsightSyncResult(skipped: false, created: 0);
  }
}
