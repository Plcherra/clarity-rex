import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/formatting/formatting.dart';

final localeControllerProvider = Provider<LocaleController>(
  (ref) => throw UnimplementedError('LocaleController not bound'),
);

/// Supported app locales. Add new languages here and in ARB files.
const claritySupportedLocales = <Locale>[
  Locale('en'),
  Locale('es'),
];

final class LocaleController extends ChangeNotifier {
  LocaleController({SharedPreferencesAsync? preferences})
    : _preferencesOverride = preferences;

  static const _preferenceKey = 'clarity.locale';

  final SharedPreferencesAsync? _preferencesOverride;
  Locale _locale = const Locale('en');

  SharedPreferencesAsync get _preferences =>
      _preferencesOverride ?? SharedPreferencesAsync();

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  List<Locale> get supportedLocales => claritySupportedLocales;

  String labelFor(Locale value) {
    return switch (value.languageCode) {
      'es' => 'Español',
      'en' => 'English',
      _ => value.languageCode,
    };
  }

  String get label => labelFor(_locale);

  Future<void> load({Locale? deviceLocale}) async {
    final saved = await _preferences.getString(_preferenceKey);
    if (saved != null && saved.isNotEmpty) {
      _applyLocale(_localeFromTag(saved), notify: false);
    } else if (deviceLocale != null) {
      _applyLocale(_resolveSupported(deviceLocale), notify: false);
    } else {
      _applyLocale(const Locale('en'), notify: false);
    }
    notifyListeners();
  }

  Future<void> applyFromProfile(String? preferredLocale) async {
    if (preferredLocale == null || preferredLocale.trim().isEmpty) {
      return;
    }
    final resolved = _localeFromTag(preferredLocale.trim());
    if (resolved.languageCode == _locale.languageCode) {
      return;
    }
    _applyLocale(resolved);
    await _preferences.setString(_preferenceKey, _localeTag(_locale));
  }

  Future<void> setLocale(Locale locale, {bool persistProfile = true}) async {
    final resolved = _resolveSupported(locale);
    if (resolved.languageCode == _locale.languageCode) {
      return;
    }
    _applyLocale(resolved);
    await _preferences.setString(_preferenceKey, _localeTag(_locale));
    if (persistProfile) {
      await _onLocalePersisted?.call(_localeTag(_locale));
    }
  }

  Future<void> Function(String localeTag)? _onLocalePersisted;

  void bindProfilePersistence(
    Future<void> Function(String localeTag) onLocalePersisted,
  ) {
    _onLocalePersisted = onLocalePersisted;
  }

  void _applyLocale(Locale locale, {bool notify = true}) {
    _locale = _resolveSupported(locale);
    setDefaultFormattingLocale(_locale);
    if (notify) {
      notifyListeners();
    }
  }

  Locale _resolveSupported(Locale locale) {
    for (final supported in claritySupportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
    return const Locale('en');
  }

  Locale _localeFromTag(String tag) {
    final parts = tag.split('-');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }

  String _localeTag(Locale locale) {
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      return '${locale.languageCode}-${locale.countryCode}';
    }
    return locale.languageCode;
  }
}
