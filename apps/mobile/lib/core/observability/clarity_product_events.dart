import 'package:flutter/foundation.dart';

import 'clarity_crash_reporting.dart';

/// Minimal product telemetry. Never log transcripts, message bodies, or PII.
abstract final class ClarityProductEvents {
  static void emit(
    String name, {
    Map<String, Object?> data = const {},
  }) {
    final safe = <String, Object?>{
      'event': name,
      for (final entry in data.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    debugPrint('[Clarity][ProductEvent] $safe');
    ClarityCrashReporting.addBreadcrumb(
      message: name,
      category: 'product',
      data: safe,
    );
  }

  static void writeConfirmationResult({
    required String result,
    required String actionType,
  }) {
    emit(
      'write_confirmation_result',
      data: {
        'result': result,
        'action_type': actionType,
      },
    );
  }

  static void voiceStreamError({
    required String code,
    int? statusCode,
  }) {
    emit(
      'voice_stream_error',
      data: {
        'code': code,
        'status_code': ?statusCode,
      },
    );
  }

  static void api5xx({
    required int statusCode,
    required String path,
  }) {
    emit(
      'api_5xx',
      data: {
        'status_code': statusCode,
        'path': path,
      },
    );
  }
}
