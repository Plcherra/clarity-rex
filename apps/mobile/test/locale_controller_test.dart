import 'package:clarity/core/l10n/clarity_locale_catalog.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

SharedPreferencesAsync _preferences({Map<String, Object> initial = const {}}) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(initial);
  return SharedPreferencesAsync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClarityLocaleCatalog', () {
    test('resolveLocale distinguishes pt-BR and pt-PT when enabledOnly is false',
        () {
      expect(
        ClarityLocaleCatalog.resolveLocale(
          const Locale('pt', 'BR'),
          enabledOnly: false,
        ),
        const Locale('pt', 'BR'),
      );
      expect(
        ClarityLocaleCatalog.resolveLocale(
          const Locale('pt', 'PT'),
          enabledOnly: false,
        ),
        const Locale('pt', 'PT'),
      );
    });

    test('resolveLocale falls back to en for disabled es when enabledOnly is true',
        () {
      expect(
        ClarityLocaleCatalog.resolveLocale(const Locale('es')),
        const Locale('en'),
      );
      expect(
        ClarityLocaleCatalog.resolveLocale(const Locale('es', 'MX')),
        const Locale('en'),
      );
    });

    test('localeTagFor preserves region', () {
      expect(
        ClarityLocaleCatalog.localeTagFor(const Locale('pt', 'BR')),
        'pt-BR',
      );
      expect(ClarityLocaleCatalog.localeTagFor(const Locale('en')), 'en');
    });

    test('enabledLocales contains English only', () {
      expect(ClarityLocaleCatalog.enabledLocales, [const Locale('en')]);
    });
  });

  group('LocaleController', () {
    test('load uses English when device locale is disabled', () async {
      final controller = LocaleController(preferences: _preferences());

      await controller.load(deviceLocale: const Locale('es', 'MX'));

      expect(controller.languageCode, 'en');
      expect(controller.localeTag, 'en');
      expect(controller.usedDeviceDefaultOnLoad, isTrue);
    });

    test('load prefers saved preference over device locale', () async {
      final controller = LocaleController(
        preferences: _preferences(initial: {'clarity.locale': 'en'}),
      );

      await controller.load(deviceLocale: const Locale('es'));

      expect(controller.languageCode, 'en');
      expect(controller.usedDeviceDefaultOnLoad, isFalse);
    });

    test('load applies saved enabled locale tag', () async {
      final controller = LocaleController(
        preferences: _preferences(initial: {'clarity.locale': 'en'}),
      );

      await controller.load(deviceLocale: const Locale('es'));

      expect(controller.localeTag, 'en');
    });

    test(
      'resolveAfterProfileHydrate applies enabled profile locale over local state',
      () async {
        final prefs = _preferences(initial: {'clarity.locale': 'en'});
        final controller = LocaleController(preferences: prefs);
        await controller.load(deviceLocale: const Locale('en'));

        await controller.resolveAfterProfileHydrate(
          profilePreferredLocale: 'en',
        );

        expect(controller.localeTag, 'en');
      },
    );

    test('resolveAfterProfileHydrate ignores disabled profile locale', () async {
      final prefs = _preferences(initial: {'clarity.locale': 'en'});
      final controller = LocaleController(preferences: prefs);
      await controller.load(deviceLocale: const Locale('en'));

      await controller.resolveAfterProfileHydrate(profilePreferredLocale: 'es');

      expect(controller.localeTag, 'en');
      expect(await prefs.getString('clarity.locale'), 'en');
    });

    test('resolveAfterProfileHydrate seeds profile when unset', () async {
      final controller = LocaleController(preferences: _preferences());
      await controller.load(deviceLocale: const Locale('es'));
      var seededTag = '';

      await controller.resolveAfterProfileHydrate(
        seedProfileIfMissing: (tag) async {
          seededTag = tag;
        },
      );

      expect(seededTag, 'en');
    });

    test('setLocale persists tag and notifies profile persistence', () async {
      final prefs = _preferences(initial: {'clarity.locale': 'en'});
      final controller = LocaleController(preferences: prefs);
      await controller.load(deviceLocale: const Locale('en'));
      var persistedTag = '';
      controller.bindProfilePersistence((tag) async {
        persistedTag = tag;
      });

      await controller.setLocale(const Locale('en'));

      expect(controller.localeTag, 'en');
      expect(await prefs.getString('clarity.locale'), 'en');
      expect(persistedTag, isEmpty);
    });

    test('setLocale ignores disabled locales', () async {
      final prefs = _preferences(initial: {'clarity.locale': 'en'});
      final controller = LocaleController(preferences: prefs);
      await controller.load(deviceLocale: const Locale('en'));

      await controller.setLocale(const Locale('es'));

      expect(controller.localeTag, 'en');
      expect(await prefs.getString('clarity.locale'), 'en');
    });
  });
}
