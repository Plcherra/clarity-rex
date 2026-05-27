import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/rex/rex_config.dart';
import '../core/supabase/supabase_service.dart';
import 'app.dart';
import 'app_composition.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[Clarity][FlutterError] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  runApp(const ClarityBootApp());
}

final class ClarityBootApp extends StatefulWidget {
  const ClarityBootApp({super.key});

  @override
  State<ClarityBootApp> createState() => _ClarityBootAppState();
}

final class _ClarityBootAppState extends State<ClarityBootApp> {
  Future<AppComposition>? _bootFuture;
  AppComposition? _composition;

  @override
  void initState() {
    super.initState();
    _bootFuture = _boot();
  }

  Future<AppComposition> _boot() async {
    await dotenv.load(fileName: '.env', isOptional: true);
    _logReleaseConfig();
    await SupabaseService.initializeFromEnv();

    final composition = AppComposition();
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
        if (composition != null) {
          return ClarityApp(
            ui: composition.ui,
            authController: composition.authController,
            profileController: composition.profileController,
          );
        }
        if (snapshot.hasError) {
          return _BootErrorApp(error: snapshot.error, retry: _retry);
        }
        return const _BootLoadingApp();
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
  const _BootLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clarity',
      debugShowCheckedModeBanner: false,
      theme: ClarityApp.buildTheme(),
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

final class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.error, required this.retry});

  final Object? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clarity',
      debugShowCheckedModeBanner: false,
      theme: ClarityApp.buildTheme(),
      home: Scaffold(
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
                      'Clarity could not start',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _bootErrorMessage(error),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _bootErrorMessage(Object? error) {
  final message = error?.toString().trim();
  if (message == null || message.isEmpty) {
    return 'Check your connection and try again.';
  }
  return message;
}
