import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../supabase/supabase_realtime_errors.dart';

/// Env-based Sentry wiring for Flutter. DSN comes from `--dart-define` or `.env`.
/// Never hardcode secrets; omit DSN in local/dev to disable reporting.
abstract final class ClarityCrashReporting {
  static const String _dsnDefine = String.fromEnvironment('SENTRY_DSN');
  static const String _environmentDefine = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
  );

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static String? resolveDsn() {
    final fromDefine = _dsnDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    try {
      final fromEnv = dotenv.env['SENTRY_DSN']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }
    } on Object {
      // dotenv may not be loaded yet in tests.
    }
    return null;
  }

  static String resolveEnvironment() {
    final fromDefine = _environmentDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    try {
      final fromEnv = dotenv.env['SENTRY_ENVIRONMENT']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }
    } on Object {
      // ignore
    }
    return kReleaseMode ? 'production' : 'development';
  }

  /// Loads optional `.env`, then starts Sentry when a DSN is present.
  static Future<void> run({required Future<void> Function() appRunner}) async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env', isOptional: true);

    final dsn = resolveDsn();
    if (dsn == null) {
      _installLocalHandlers();
      await appRunner();
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.environment = resolveEnvironment();
      options.sendDefaultPii = false;
      options.attachStacktrace = true;
      // Keep launch noise low; crashes still send at 100%.
      options.tracesSampleRate = kReleaseMode ? 0.1 : 0.0;
      options.beforeSend = _scrubEvent;
    }, appRunner: () async {
      _initialized = true;
      _installSentryHandlers();
      await appRunner();
    });
  }

  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? hint,
  }) async {
    if (isRecoverableSupabaseRealtimeError(error)) {
      debugPrint('[Clarity][Realtime] $error');
      return;
    }
    if (!_initialized) {
      debugPrint('[Clarity][Crash] $error');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint == null ? null : Hint.withMap({'context': hint}),
    );
  }

  static void addBreadcrumb({
    required String message,
    String? category,
    Map<String, Object?>? data,
  }) {
    if (!_initialized) {
      return;
    }
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data == null
            ? null
            : {
                for (final entry in data.entries)
                  if (entry.value != null) entry.key: entry.value!,
              },
        level: SentryLevel.info,
      ),
    );
  }

  static SentryEvent? _scrubEvent(SentryEvent event, Hint hint) {
    if (_eventIsRecoverableRealtime(event)) {
      return null;
    }
    // Defense in depth: never attach request bodies / user PII by default.
    event.user = null;
    return event;
  }

  static bool _eventIsRecoverableRealtime(SentryEvent event) {
    for (final exception in event.exceptions ?? const <SentryException>[]) {
      final blob = '${exception.type ?? ''} ${exception.value ?? ''}';
      if (isRecoverableSupabaseRealtimeError(blob)) {
        return true;
      }
    }
    return false;
  }

  static void _installLocalHandlers() {
    FlutterError.onError = (details) {
      if (isRecoverableSupabaseRealtimeError(details.exception)) {
        debugPrint('[Clarity][Realtime] ${details.exceptionAsString()}');
        return;
      }
      FlutterError.presentError(details);
      debugPrint('[Clarity][FlutterError] ${details.exceptionAsString()}');
      if (details.stack != null) {
        debugPrintStack(stackTrace: details.stack);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (isRecoverableSupabaseRealtimeError(error)) {
        debugPrint('[Clarity][Realtime] $error');
        return true;
      }
      debugPrint('[Clarity][ZoneError] $error');
      debugPrintStack(stackTrace: stack);
      return true;
    };
  }

  static void _installSentryHandlers() {
    FlutterError.onError = (details) {
      if (isRecoverableSupabaseRealtimeError(details.exception)) {
        debugPrint('[Clarity][Realtime] ${details.exceptionAsString()}');
        return;
      }
      FlutterError.presentError(details);
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (isRecoverableSupabaseRealtimeError(error)) {
        debugPrint('[Clarity][Realtime] $error');
        return true;
      }
      Sentry.captureException(error, stackTrace: stack);
      return true;
    };
  }
}
