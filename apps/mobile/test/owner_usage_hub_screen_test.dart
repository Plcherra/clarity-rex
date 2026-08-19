import 'package:clarity/features/owner_debug/presentation/owner_debug_screen.dart';
import 'package:clarity/features/usage_admin/application/owner_usage_controller.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_api.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_filter.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_breakdown.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';
import 'package:clarity/features/usage_admin/presentation/owner_usage_hub_screen.dart';
import 'package:clarity/features/usage_admin/presentation/owner_usage_profile_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Clarity',
      packageName: 'app.clarity.rex',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('usage administration shows cost insights without debug dump', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        OwnerUsageHubScreen(
          controller: OwnerUsageController(api: _FakeUsageAdminApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usage administration'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text(r'$1.99'), findsWidgets);
    expect(find.text('Spend mix'), findsOneWidget);
    expect(find.text('Google TTS'), findsOneWidget);
    expect(find.textContaining('Largest cost: Google TTS'), findsWidgets);
    expect(find.text('Pricing from COGS'), findsOneWidget);
    expect(find.textContaining('Cost per active user'), findsOneWidget);
    expect(find.textContaining('2× COGS'), findsOneWidget);
    expect(find.textContaining('Plaid not metered yet'), findsOneWidget);
    expect(find.text('Users', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('a***@example.com', skipOffstage: false),
      240,
    );
    await tester.pumpAndSettle();
    expect(find.text('a***@example.com'), findsOneWidget);

    _expectDebugDumpAbsent();
  });

  testWidgets('expanding a user shows function-level cost and Plaid links', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        OwnerUsageHubScreen(
          controller: OwnerUsageController(api: _FakeUsageAdminApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('owner_user_tile_user-1'), skipOffstage: false),
      240,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('owner_user_tile_user-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cost by function', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Grok chat', skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('Plaid not metered yet · 1 linked items', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('voice LLM', skipOffstage: false), findsOneWidget);
    _expectDebugDumpAbsent();
  });

  testWidgets('long-press on usage title opens hidden owner debug screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        OwnerUsageHubScreen(
          controller: OwnerUsageController(api: _FakeUsageAdminApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('owner_usage_admin_title')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner_debug_screen')), findsOneWidget);
    expect(find.text(OwnerDebugScreen.title), findsOneWidget);
    expect(find.text('Build provenance'), findsOneWidget);
    expect(find.text('Copy VAD telemetry'), findsOneWidget);
    expect(find.text('Copy voice trace'), findsOneWidget);
    expect(find.textContaining('REX_STREAMING_VOICE_ENABLED'), findsOneWidget);
  });

  testWidgets('owner profile long-press opens hidden debug, not the cost tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: OwnerUsageProfileEntry(
            controller: OwnerAccessController(api: _FakeUsageAdminApi()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usage administration'), findsOneWidget);
    _expectDebugDumpAbsent();

    await tester.longPress(find.byKey(const Key('owner_usage_admin_entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('owner_debug_screen')), findsOneWidget);
    expect(find.text('Build provenance'), findsOneWidget);
    expect(find.text('Period'), findsNothing);
  });
}

void _expectDebugDumpAbsent() {
  expect(find.text('Build provenance'), findsNothing);
  expect(find.text('Voice transport'), findsNothing);
  expect(find.text('VAD telemetry (no audio)'), findsNothing);
  expect(find.text('Copy VAD telemetry'), findsNothing);
  expect(find.text('Copy voice trace'), findsNothing);
  expect(find.text('Copy transport'), findsNothing);
  expect(find.text('Clear trace'), findsNothing);
  expect(find.textContaining('REX_STREAMING_VOICE_ENABLED'), findsNothing);
  expect(find.textContaining('REX_CLOUD_VOICE_ENABLED'), findsNothing);
  expect(find.textContaining('websocket_state'), findsNothing);
  expect(find.text('Git SHA'), findsNothing);
}

class _FakeUsageAdminApi extends UsageAdminApi {
  _FakeUsageAdminApi() : super(baseUrl: 'http://localhost');

  @override
  Future<bool> fetchOwnerAccess() async => true;

  @override
  Future<OwnerPlatformSummary> fetchPlatformSummary(
    UsageAdminFilter filter,
  ) async {
    return const OwnerPlatformSummary(
      activeUserCount: 1,
      registeredUserCount: 2,
      monthVoiceSeconds: 180,
      monthLlmCalls: 5,
      monthChatLlmCalls: 3,
      monthVoiceLlmCalls: 2,
      monthEstimatedCostCents: 199,
      costMix: [
        UsageCostSlice(
          id: 'google_tts:text_to_speech:voice:tts',
          labelKey: 'google_tts',
          provider: 'google_tts',
          feature: 'text_to_speech',
          channel: 'voice',
          eventType: 'tts',
          eventCount: 8,
          unitCount: 10,
          durationMs: 1000,
          estimatedCostCents: 140,
          share: 0.7,
          metered: true,
        ),
        UsageCostSlice(
          id: 'grok:assistant_response:chat:llm',
          labelKey: 'grok_chat',
          provider: 'grok',
          feature: 'assistant_response',
          channel: 'chat',
          eventType: 'llm',
          eventCount: 3,
          unitCount: 20,
          durationMs: 0,
          estimatedCostCents: 59,
          share: 0.3,
          metered: true,
        ),
      ],
      largestCostDriver: UsageCostDriver(
        labelKey: 'google_tts',
        estimatedCostCents: 140,
        share: 0.7,
      ),
      pricing: UsagePricingHelper(
        cogsCents: 199,
        activeUserCount: 1,
        voiceMinutes: 3,
        costPerActiveUserCents: 199,
        costPerVoiceMinuteCents: 40,
        priceFloor2xCents: 398,
        priceFloor3xCents: 597,
        pricePerUser2xCents: 398,
        pricePerUser3xCents: 597,
        plaidIncluded: false,
      ),
      plaid: UsagePlaidLinks(
        metered: false,
        userCount: 1,
        itemCount: 2,
        accountCount: 3,
      ),
    );
  }

  @override
  Future<List<OwnerUserUsage>> fetchAllUsers(UsageAdminFilter filter) async {
    return [
      const OwnerUserUsage(
        userId: 'user-1',
        email: 'a***@example.com',
        monthVoiceSeconds: 120,
        monthLlmCalls: 4,
        monthChatLlmCalls: 3,
        monthVoiceLlmCalls: 1,
        monthSttSeconds: 60,
        monthTtsSeconds: 60,
        monthEstimatedCostCents: 199,
        largestCostDriver: UsageCostDriver(
          labelKey: 'google_tts',
          estimatedCostCents: 140,
          share: 0.7,
        ),
        plaidItemCount: 1,
        plaidAccountCount: 2,
        costBreakdown: [
          UsageCostSlice(
            id: 'google_tts:text_to_speech:voice:tts',
            labelKey: 'google_tts',
            provider: 'google_tts',
            feature: 'text_to_speech',
            channel: 'voice',
            eventType: 'tts',
            eventCount: 8,
            unitCount: 10,
            durationMs: 1000,
            estimatedCostCents: 140,
            share: 0.7,
            metered: true,
          ),
          UsageCostSlice(
            id: 'grok:assistant_response:chat:llm',
            labelKey: 'grok_chat',
            provider: 'grok',
            feature: 'assistant_response',
            channel: 'chat',
            eventType: 'llm',
            eventCount: 3,
            unitCount: 20,
            durationMs: 0,
            estimatedCostCents: 59,
            share: 0.3,
            metered: true,
          ),
        ],
      ),
    ];
  }
}
