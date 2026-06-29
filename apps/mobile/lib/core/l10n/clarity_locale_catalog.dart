import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Metadata for one Clarity app locale.
final class ClarityLocaleSpec {
  const ClarityLocaleSpec({
    required this.locale,
    required this.nativeLabel,
    this.enabled = false,
    this.arbFile,
  });

  final Locale locale;
  final String nativeLabel;
  final bool enabled;
  final String? arbFile;
}

/// Single source of truth for supported locale metadata.
abstract final class ClarityLocaleCatalog {
  static const List<ClarityLocaleSpec> specs = <ClarityLocaleSpec>[
    ClarityLocaleSpec(
      locale: Locale('en'),
      nativeLabel: 'English',
      enabled: true,
      arbFile: 'app_en.arb',
    ),
    ClarityLocaleSpec(
      locale: Locale('es'),
      nativeLabel: 'Español',
      arbFile: 'app_es.arb',
    ),
    ClarityLocaleSpec(
      locale: Locale('pt', 'BR'),
      nativeLabel: 'Português (Brasil)',
    ),
    ClarityLocaleSpec(
      locale: Locale('pt', 'PT'),
      nativeLabel: 'Português (Portugal)',
    ),
    ClarityLocaleSpec(
      locale: Locale('fr'),
      nativeLabel: 'Français',
    ),
  ];

  static const Locale fallbackLocale = Locale('en');

  /// Locales the user can select in Profile → Language.
  static List<Locale> get enabledLocales => specs
      .where((spec) => spec.enabled)
      .map((spec) => spec.locale)
      .toList(growable: false);

  /// Locales registered with gen-l10n delegates.
  static List<Locale> get materialAppSupportedLocales =>
      AppLocalizations.supportedLocales;

  static String localeTagFor(Locale locale) {
    final countryCode = locale.countryCode?.trim();
    if (countryCode != null && countryCode.isNotEmpty) {
      return '${locale.languageCode}-$countryCode';
    }
    return locale.languageCode;
  }

  static String labelFor(Locale locale) {
    final spec = specFor(locale, enabledOnly: false);
    return spec?.nativeLabel ?? locale.languageCode;
  }

  static bool isEnabled(Locale locale) {
    final spec = specFor(locale, enabledOnly: false);
    return spec?.enabled ?? false;
  }

  /// Resolves [input] to a catalog locale for active app use.
  ///
  /// Fallback chain: exact tag → language-only match → [fallbackLocale].
  /// When [enabledOnly] is true, only enabled specs are considered.
  static Locale resolveLocale(Locale input, {bool enabledOnly = true}) {
    final candidates = _candidateSpecs(enabledOnly: enabledOnly);

    for (final spec in candidates) {
      if (_sameLocale(spec.locale, input)) {
        return spec.locale;
      }
    }

    for (final spec in candidates) {
      if (spec.locale.languageCode == input.languageCode &&
          _isLanguageOnlyLocale(spec.locale)) {
        return spec.locale;
      }
    }

    for (final spec in candidates) {
      if (spec.locale.languageCode == input.languageCode) {
        return spec.locale;
      }
    }

    return fallbackLocale;
  }

  static Locale resolveLocaleTag(String tag, {bool enabledOnly = true}) {
    return resolveLocale(_localeFromTag(tag), enabledOnly: enabledOnly);
  }

  static ClarityLocaleSpec? specFor(
    Locale locale, {
    required bool enabledOnly,
  }) {
    for (final spec in _candidateSpecs(enabledOnly: enabledOnly)) {
      if (_sameLocale(spec.locale, locale)) {
        return spec;
      }
    }
    return null;
  }

  static List<ClarityLocaleSpec> _candidateSpecs({required bool enabledOnly}) {
    if (!enabledOnly) {
      return specs;
    }
    return specs.where((spec) => spec.enabled).toList(growable: false);
  }

  static bool _sameLocale(Locale a, Locale b) {
    final aCountry = a.countryCode?.trim();
    final bCountry = b.countryCode?.trim();
    if (aCountry != null &&
        aCountry.isNotEmpty &&
        bCountry != null &&
        bCountry.isNotEmpty) {
      return a.languageCode == b.languageCode && aCountry == bCountry;
    }
    if ((aCountry == null || aCountry.isEmpty) &&
        (bCountry == null || bCountry.isEmpty)) {
      return a.languageCode == b.languageCode;
    }
    return false;
  }

  static bool _isLanguageOnlyLocale(Locale locale) {
    final countryCode = locale.countryCode?.trim();
    return countryCode == null || countryCode.isEmpty;
  }

  static Locale _localeFromTag(String tag) {
    final parts = tag.split('-');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}

/// Back-compat alias for code that referenced the old constant list.
List<Locale> get claritySupportedLocales =>
    ClarityLocaleCatalog.materialAppSupportedLocales;
