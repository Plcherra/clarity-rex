import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/clarity_locale_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lookupForLocale returns Spanish for es locale', () {
    final l10n = lookupForLocale(const Locale('es'));
    expect(l10n.profileLanguage, 'Idioma');
  });

  test('lookupForLocaleTag falls back pt-BR to English gen-l10n', () {
    final l10n = lookupForLocaleTag('pt-BR');
    expect(l10n.profileLanguage, 'Language');
  });

  test('lookupForLocale uses enabled locale when available', () {
    final l10n = lookupForLocale(ClarityLocaleCatalog.fallbackLocale);
    expect(l10n.navDashboard, 'Dashboard');
  });

  test('lookupEnglishLocalizationsForTests returns English strings', () {
    final l10n = lookupEnglishLocalizationsForTests();
    expect(l10n.importUploadingTransactions, 'Uploading transactions...');
  });
}
