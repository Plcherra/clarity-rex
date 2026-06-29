import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'clarity_locale_catalog.dart';

/// Resolves [locale] through the Clarity catalog, then loads gen-l10n strings.
///
/// Use this from provider overrides and services — not `lookupAppLocalizations`
/// with a raw device locale or hardcoded `Locale('en')`.
///
/// Catalog locales without an ARB file yet (e.g. `pt-BR`) fall back to the
/// nearest supported gen-l10n locale, then English.
AppLocalizations lookupForLocale(Locale locale) {
  final resolved = ClarityLocaleCatalog.resolveLocale(
    locale,
    enabledOnly: false,
  );
  return lookupAppLocalizations(_nearestSupportedLocale(resolved));
}

/// Loads l10n for a persisted or API BCP-47 tag (e.g. `pt-BR`, `en`).
AppLocalizations lookupForLocaleTag(String tag) {
  return lookupForLocale(
    ClarityLocaleCatalog.resolveLocaleTag(tag, enabledOnly: false),
  );
}

/// Explicit English lookup for unit/widget tests only.
AppLocalizations lookupEnglishLocalizationsForTests() {
  return lookupForLocale(const Locale('en'));
}

Locale _nearestSupportedLocale(Locale resolved) {
  final supported = AppLocalizations.supportedLocales;
  for (final candidate in supported) {
    if (_sameLocale(candidate, resolved)) {
      return candidate;
    }
  }
  for (final candidate in supported) {
    if (candidate.languageCode == resolved.languageCode) {
      return candidate;
    }
  }
  return ClarityLocaleCatalog.fallbackLocale;
}

bool _sameLocale(Locale a, Locale b) {
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
