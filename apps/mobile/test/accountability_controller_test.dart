import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/friendly_service_error.dart';
import 'package:clarity/features/finance/application/assistant_financial_context_service.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/rex/accountability/application/accountability_controller.dart';
import 'package:clarity/rex/accountability/data/accountability_api.dart';
import 'package:clarity/rex/accountability/data/accountability_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AccountabilityOverview overviewWithThreads(List<OpenThread> threads) {
    return AccountabilityOverview(
      signals: const [],
      ruleRisks: const [],
      planRisks: const [],
      recentPatterns: const [],
      activeRules: const [],
      openThreads: threads,
      activePlans: const [],
      openMilestones: const [],
      completedMilestones: const [],
      planHierarchy: const [],
      duplicateWarnings: const [],
      metadata: const {},
    );
  }

  OpenThread activeThread(String id) {
    return OpenThread(
      id: id,
      title: 'Thread $id',
      summary: null,
      status: 'active',
      source: 'user_created',
      lastMentionedAt: null,
      lastFollowUpAt: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  Future<LocaleController> loadLocaleController() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final localeController = LocaleController(
      preferences: SharedPreferencesAsync(),
    );
    await localeController.load();
    return localeController;
  }

  test('createOpenThread blocks at max active without calling API', () async {
    final localeController = await loadLocaleController();
    final api = _FakeAccountabilityApi(
      overview: overviewWithThreads([
        for (var i = 0; i < AccountabilityOverview.maxActiveOpenThreads; i++)
          activeThread('thread-$i'),
      ]),
    );
    final container = ProviderContainer(
      overrides: [
        accountabilityApiProvider.overrideWithValue(api),
        assistantFinancialContextServiceProvider.overrideWithValue(null),
        localeControllerProvider.overrideWithValue(localeController),
      ],
    );
    addTearDown(container.dispose);

    await container.read(accountabilityProvider.notifier).loadOverview();
    final saved = await container
        .read(accountabilityProvider.notifier)
        .createOpenThread(title: 'One more');

    final state = container.read(accountabilityProvider);
    final l10n = lookupEnglishLocalizationsForTests();
    expect(saved, isFalse);
    expect(api.createOpenThreadCalls, 0);
    expect(
      state.errorMessage,
      l10n.accountabilityOpenThreadMaxActive(
        AccountabilityOverview.maxActiveOpenThreads,
      ),
    );
  });

  test('createOpenThread allows create when under the active limit', () async {
    final localeController = await loadLocaleController();
    final api = _FakeAccountabilityApi(
      overview: overviewWithThreads([activeThread('thread-1')]),
    );
    final container = ProviderContainer(
      overrides: [
        accountabilityApiProvider.overrideWithValue(api),
        assistantFinancialContextServiceProvider.overrideWithValue(null),
        localeControllerProvider.overrideWithValue(localeController),
      ],
    );
    addTearDown(container.dispose);

    await container.read(accountabilityProvider.notifier).loadOverview();
    final saved = await container
        .read(accountabilityProvider.notifier)
        .createOpenThread(title: 'Morning routine');

    expect(saved, isTrue);
    expect(api.createOpenThreadCalls, 1);
    expect(container.read(accountabilityProvider).errorMessage, isNull);
  });

  test('friendlyAccountabilityApiError maps open-thread cap message', () {
    final l10n = lookupEnglishLocalizationsForTests();
    final mapped = friendlyAccountabilityApiError(
      l10n,
      const AccountabilityApiException(
        'You can have at most 5 active open threads.',
      ),
    );
    expect(
      mapped,
      l10n.accountabilityOpenThreadMaxActive(
        AccountabilityOverview.maxActiveOpenThreads,
      ),
    );
  });

  test('loadOverview maps AccountabilityApiException via friendly error', () async {
    final localeController = await loadLocaleController();
    final api = _FakeAccountabilityApi(
      overview: overviewWithThreads(const []),
      overviewError: const AccountabilityApiException(
        'You can have at most 5 active open threads.',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        accountabilityApiProvider.overrideWithValue(api),
        assistantFinancialContextServiceProvider.overrideWithValue(null),
        localeControllerProvider.overrideWithValue(localeController),
      ],
    );
    addTearDown(container.dispose);

    await container.read(accountabilityProvider.notifier).loadOverview();

    final l10n = lookupEnglishLocalizationsForTests();
    expect(
      container.read(accountabilityProvider).errorMessage,
      l10n.accountabilityOpenThreadMaxActive(
        AccountabilityOverview.maxActiveOpenThreads,
      ),
    );
  });
}

class _FakeAccountabilityApi extends AccountabilityApi {
  _FakeAccountabilityApi({
    required this.overview,
    this.overviewError,
  });

  AccountabilityOverview overview;
  final AccountabilityApiException? overviewError;
  int createOpenThreadCalls = 0;

  @override
  Future<AccountabilityOverview> getOverview({
    int limit = 25,
    Map<String, dynamic>? budgetPerformance,
  }) async {
    final error = overviewError;
    if (error != null) {
      throw error;
    }
    return overview;
  }

  @override
  Future<OpenThread> createOpenThread({
    required String title,
    String? summary,
  }) async {
    createOpenThreadCalls += 1;
    final created = OpenThread(
      id: 'created-$createOpenThreadCalls',
      title: title,
      summary: summary,
      status: 'active',
      source: 'user_created',
      lastMentionedAt: null,
      lastFollowUpAt: null,
      createdAt: null,
      updatedAt: null,
    );
    overview = AccountabilityOverview(
      signals: overview.signals,
      ruleRisks: overview.ruleRisks,
      planRisks: overview.planRisks,
      recentPatterns: overview.recentPatterns,
      activeRules: overview.activeRules,
      openThreads: [...overview.openThreads, created],
      activePlans: overview.activePlans,
      openMilestones: overview.openMilestones,
      completedMilestones: overview.completedMilestones,
      planHierarchy: overview.planHierarchy,
      duplicateWarnings: overview.duplicateWarnings,
      metadata: overview.metadata,
    );
    return created;
  }
}
