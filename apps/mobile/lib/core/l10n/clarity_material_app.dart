import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../../features/profile/application/locale_controller.dart';
import '../../features/profile/application/theme_mode_controller.dart';
import '../../theme/clarity_theme.dart';

/// Shared [MaterialApp] configuration for boot screens and the main app.
class ClarityMaterialApp extends StatelessWidget {
  const ClarityMaterialApp({
    super.key,
    required this.themeModeController,
    required this.localeController,
    required this.home,
  });

  final ThemeModeController themeModeController;
  final LocaleController localeController;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeModeController, localeController]),
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) =>
              AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          locale: localeController.locale,
          supportedLocales: localeController.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ClarityTheme.light(),
          darkTheme: ClarityTheme.dark(),
          themeMode: themeModeController.themeMode,
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: ClarityTheme.systemUiOverlayStyle(
                Theme.of(context).brightness,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: home,
        );
      },
    );
  }
}
