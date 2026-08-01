@TestOn('browser')
library;

import 'package:clarity/app/app.dart';
import 'package:clarity/app/app_composition.dart';
import 'package:clarity/core/supabase/supabase_records.dart';
import 'package:clarity/features/shell/presentation/home_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
  });

  testWidgets('authenticated home shell boots on web without provider errors', (
    tester,
  ) async {
    expect(kIsWeb, isTrue, reason: 'This test must run on the browser platform');

    final app = AppComposition(initialAuthenticated: true);
    addTearDown(app.dispose);
    app.profileController.profile = ProfileRecord(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      avatarUrl: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final capturedErrors = <Object>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      capturedErrors.add(details.exception);
      previousHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = previousHandler;
    });

    await tester.pumpWidget(
      ClarityApp(
        ui: app.ui,
        authController: app.authController,
        profileController: app.profileController,
        themeModeController: app.themeModeController,
        localeController: app.localeController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(
      capturedErrors,
      isEmpty,
      reason: capturedErrors.map((error) => error.toString()).join('\n'),
    );
  });
}
