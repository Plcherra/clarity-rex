import 'package:clarity/app/app_composition.dart';
import 'package:clarity/features/profile/application/profile_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Lightweight app shell for assistant widget tests.
final class AssistantTestHarness {
  AssistantTestHarness() {
    ensureInitialized();
    _app = AppComposition();
  }

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) {
      return;
    }
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    _initialized = true;
  }

  late final AppComposition _app;

  ProfileController get profileController => _app.profileController;

  void dispose() => _app.dispose();
}
