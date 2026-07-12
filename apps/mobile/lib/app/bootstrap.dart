import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../l10n/app_localizations.dart';
import '../core/l10n/app_l10n.dart';
import '../core/l10n/clarity_material_app.dart';
import '../core/observability/clarity_crash_reporting.dart';
import '../core/rex/rex_config.dart';
import '../core/supabase/supabase_service.dart';
import '../core/l10n/app_locale.dart';
import '../features/profile/application/theme_mode_controller.dart';
import '../screens/splash/clarity_splash_screen.dart';
import '../widgets/clarity_diamond_loader.dart';
import 'app.dart';
import 'app_composition.dart';

Future<void> bootstrap() async {
  await ClarityCrashReporting.run(
    appRunner: () async {
      runApp(const ClarityBootApp());
    },
  );
}

final class ClarityBootApp extends StatefulWidget {
  const ClarityBootApp({super.key});

  @override
  State<ClarityBootApp> createState() => _ClarityBootAppState();
}

final class _ClarityBootAppState extends State<ClarityBootApp> {
  final ThemeModeController _themeModeController = ThemeModeController();
  final LocaleController _localeController = LocaleController();
  Future<AppComposition>? _bootFuture;
  AppComposition? _composition;

  @override
  void initState() {
    super.initState();
    _bootFuture = _boot();
  }

  Future<AppComposition> _boot() async {
    await _themeModeController.load();
    await _localeController.load(deviceLocale: AppLocale.readDeviceLocale());
    // dotenv already loaded in ClarityCrashReporting.run; reload is safe/idempotent.
    await dotenv.load(fileName: '.env', isOptional: true);
    _logReleaseConfig();
    await SupabaseService.initializeFromEnv();

    final composition = AppComposition(
      themeModeController: _themeModeController,
      localeController: _localeController,
    );
    composition.localeController.bindProfilePersistence((localeTag) async {
      if (composition.authService.currentUser == null) return;
      await composition.profileController.updatePreferredLocale(localeTag);
    });
    try {
      await composition.startupService.hydrateForStartup();
      await composition.profileController.hydrateProfileForCurrentUser();
      _composition = composition;
      return composition;
    } on Object {
      composition.dispose();
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _bootFuture = _boot();
    });
  }

  @override
  void dispose() {
    _composition?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppComposition>(
      future: _bootFuture,
      builder: (context, snapshot) {
        final composition = snapshot.data;
        if (snapshot.hasError) {
          return _BootErrorApp(
            error: snapshot.error,
            retry: _retry,
            themeModeController: _themeModeController,
            localeController: _localeController,
          );
        }
        return ClaritySplashScreen(
          isReady: composition != null,
          child: composition != null
              ? ClarityApp(
                  ui: composition.ui,
                  authController: composition.authController,
                  profileController: composition.profileController,
                  themeModeController: composition.themeModeController,
                  localeController: composition.localeController,
                )
              : _BootLoadingApp(
                  themeModeController: _themeModeController,
                  localeController: _localeController,
                ),
        );
      },
    );
  }
}

void _logReleaseConfig() {
  debugPrint(
    '[Clarity][Config] '
    'supabase=${SupabaseService.configSource}; '
    'rex_backend=${RexConfig.backendBaseUrl}; '
    'cloud_voice=${RexConfig.cloudVoiceEnabled}; '
    'streaming_voice=${RexConfig.streamingVoiceEnabled}; '
    'native_ios_voice=${RexConfig.nativeIosVoiceEnabled}; '
    'legacy_native_ios_flag=${RexConfig.legacyNativeIosVoiceFlagRequested}',
  );
}

final class _BootLoadingApp extends StatelessWidget {
  const _BootLoadingApp({
    required this.themeModeController,
    required this.localeController,
  });

  final ThemeModeController themeModeController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ClarityMaterialApp(
      themeModeController: themeModeController,
      localeController: localeController,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ClarityDiamondLoader(
              size: 64,
              label: context.l10n.startingClarity,
            ),
          ),
        ),
      ),
    );
  }
}

final class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({
    required this.error,
    required this.retry,
    required this.themeModeController,
    required this.localeController,
  });

  final Object? error;
  final VoidCallback retry;
  final ThemeModeController themeModeController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ClarityMaterialApp(
      themeModeController: themeModeController,
      localeController: localeController,
      home: Builder(
        builder: (context) {
          final l10n = context.l10n;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 18),
                        Text(
                          l10n.bootErrorTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _bootErrorMessage(l10n, error),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: retry,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.bootErrorTryAgain),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _bootErrorMessage(AppLocalizations l10n, Object? error) {
  final message = error?.toString().trim();
  if (message == null || message.isEmpty) {
    return l10n.bootErrorFallbackMessage;
  }
  return message;
}
