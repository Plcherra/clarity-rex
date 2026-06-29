import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/clarity_locale_catalog.dart';

export '../../../core/l10n/clarity_locale_catalog.dart' show claritySupportedLocales;

final localeControllerProvider = Provider<LocaleController>(
  (ref) => throw UnimplementedError('LocaleController not bound'),
);

final class LocaleController extends ChangeNotifier {
  LocaleController({SharedPreferencesAsync? preferences})
    : _preferencesOverride = preferences;

  static const _preferenceKey = 'clarity.locale';

  final SharedPreferencesAsync? _preferencesOverride;
  Locale _locale = ClarityLocaleCatalog.fallbackLocale;
  bool _usedDeviceDefaultOnLoad = false;

  SharedPreferencesAsync get _preferences =>
      _preferencesOverride ?? SharedPreferencesAsync();

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  /// BCP-47-ish tag persisted to profile and sent to Rex APIs.
  String get localeTag => ClarityLocaleCatalog.localeTagFor(_locale);

  /// Locales shown in Profile → Language (enabled catalog entries only).
  List<Locale> get enabledLocales => ClarityLocaleCatalog.enabledLocales;

  /// Locales registered with MaterialApp / gen-l10n delegates.
  List<Locale> get supportedLocales =>
      ClarityLocaleCatalog.materialAppSupportedLocales;

  bool get usedDeviceDefaultOnLoad => _usedDeviceDefaultOnLoad;

  String labelFor(Locale value) => ClarityLocaleCatalog.labelFor(value);

  String get label => labelFor(_locale);

  /// Device locale from the platform (equivalent to `Platform.localeName`).
  static Locale readDeviceLocale() {
    return WidgetsBinding.instance.platformDispatcher.locale;
  }

  /// Boot-time load: SharedPreferences → device locale → English.
  Future<void> load({Locale? deviceLocale}) async {
    final saved = await _preferences.getString(_preferenceKey);
    if (saved != null && saved.isNotEmpty) {
      _applyLocale(
        ClarityLocaleCatalog.resolveLocaleTag(saved),
        notify: false,
      );
      _usedDeviceDefaultOnLoad = false;
    } else {
      final resolvedDevice = ClarityLocaleCatalog.resolveLocale(
        deviceLocale ?? readDeviceLocale(),
      );
      _applyLocale(resolvedDevice, notify: false);
      _usedDeviceDefaultOnLoad = true;
    }
    notifyListeners();
  }

  /// After profile hydrate: profile DB wins; seed profile when unset.
  Future<void> resolveAfterProfileHydrate({
    String? profilePreferredLocale,
    Future<void> Function(String localeTag)? seedProfileIfMissing,
  }) async {
    final profileLocale = profilePreferredLocale?.trim();
    if (profileLocale != null && profileLocale.isNotEmpty) {
      final resolved = ClarityLocaleCatalog.resolveLocaleTag(profileLocale);
      if (ClarityLocaleCatalog.localeTagFor(resolved) != localeTag) {
        _applyLocale(resolved);
        await _preferences.setString(_preferenceKey, localeTag);
      }
      _usedDeviceDefaultOnLoad = false;
      return;
    }

    if (seedProfileIfMissing != null) {
      await seedProfileIfMissing(localeTag);
    }
  }

  Future<void> applyFromProfile(String? preferredLocale) async {
    await resolveAfterProfileHydrate(profilePreferredLocale: preferredLocale);
  }

  Future<void> setLocale(Locale locale, {bool persistProfile = true}) async {
    if (!ClarityLocaleCatalog.isEnabled(locale)) {
      return;
    }
    final resolved = ClarityLocaleCatalog.resolveLocale(locale);
    if (ClarityLocaleCatalog.localeTagFor(resolved) == localeTag) {
      return;
    }
    _applyLocale(resolved);
    _usedDeviceDefaultOnLoad = false;
    await _preferences.setString(_preferenceKey, localeTag);
    if (persistProfile) {
      await _onLocalePersisted?.call(localeTag);
    }
  }

  Future<void> Function(String localeTag)? _onLocalePersisted;

  void bindProfilePersistence(
    Future<void> Function(String localeTag) onLocalePersisted,
  ) {
    _onLocalePersisted = onLocalePersisted;
  }

  void _applyLocale(Locale locale, {bool notify = true}) {
    _locale = ClarityLocaleCatalog.resolveLocale(locale);
    setDefaultFormattingLocale(_locale);
    if (notify) {
      notifyListeners();
    }
  }
}
