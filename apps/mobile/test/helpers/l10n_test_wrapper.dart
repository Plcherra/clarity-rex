/// Widget-test helpers for Clarity localization.
///
/// Test conventions:
/// - Wrap widgets under test with [wrapWithL10n] so gen-l10n delegates are loaded.
/// - Default to `Locale('en')` unless explicitly testing another locale.
/// - Prefer `find.byKey` / semantic labels over `find.text('English copy')`.
/// - Do not mass-rewrite existing tests; wrap new tests and failing suites only.
library;

import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget wrapWithL10n(
  Widget child, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
