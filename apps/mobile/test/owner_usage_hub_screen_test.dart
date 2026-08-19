import 'package:clarity/features/owner_debug/presentation/owner_debug_screen.dart';
import 'package:clarity/features/usage_admin/application/owner_usage_controller.dart';
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
      wrapWithL10n(OwnerUsageHubScreen(controller: _StubOwnerUsageController())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usage administration'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text(r'$1.99'), findsWidgets);
    expect(find.text('a***@example.com'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);

    _expectDebugDumpAbsent();
  });

  testWidgets('long-press on usage title opens hidden owner debug screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(OwnerUsageHubScreen(controller: _StubOwnerUsageController())),
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
            controller: _StubOwnerAccessController(),
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

final class _StubOwnerUsageController extends OwnerUsageController {
  @override
  Future<void> load() async {
    isLoading = false;
    loadFailed = false;
    summary = const OwnerPlatformSummary(
      activeUserCount: 1,
      registeredUserCount: 2,
      monthVoiceSeconds: 180,
      monthLlmCalls: 5,
      monthChatLlmCalls: 3,
      monthVoiceLlmCalls: 2,
      monthEstimatedCostCents: 199,
    );
    users = const [
      OwnerUserUsage(
        userId: 'user-1',
        email: 'a***@example.com',
        monthVoiceSeconds: 120,
        monthLlmCalls: 4,
        monthChatLlmCalls: 3,
        monthVoiceLlmCalls: 1,
        monthSttSeconds: 60,
        monthTtsSeconds: 60,
        monthEstimatedCostCents: 199,
      ),
    ];
    notifyListeners();
  }
}

final class _StubOwnerAccessController extends OwnerAccessController {
  @override
  Future<void> load() async {
    isLoading = false;
    isOwner = true;
    notifyListeners();
  }
}
