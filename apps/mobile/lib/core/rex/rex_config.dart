import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class RexConfig {
  static const String _backendBaseUrlOverride = String.fromEnvironment(
    'REX_BACKEND_URL',
  );

  static const String _cloudVoiceEnabledOverride = String.fromEnvironment(
    'REX_CLOUD_VOICE_ENABLED',
  );

  static const String _streamingVoiceEnabledOverride = String.fromEnvironment(
    'REX_STREAMING_VOICE_ENABLED',
  );

  static const String _experimentalNativeIosVoiceEnabledOverride =
      String.fromEnvironment('REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED');

  static const String _legacyNativeIosVoiceEnabledOverride =
      String.fromEnvironment('REX_NATIVE_IOS_VOICE_ENABLED');

  static String get backendBaseUrl {
    return _stringConfig(
      dartDefineValue: _backendBaseUrlOverride,
      envKey: 'REX_BACKEND_URL',
      fallback: 'http://localhost:8000',
    );
  }

  static bool get cloudVoiceEnabled {
    return _boolConfig(
      dartDefineValue: _cloudVoiceEnabledOverride,
      envKey: 'REX_CLOUD_VOICE_ENABLED',
      fallback: true,
    );
  }

  static bool get streamingVoiceEnabled {
    return _boolConfig(
      dartDefineValue: _streamingVoiceEnabledOverride,
      envKey: 'REX_STREAMING_VOICE_ENABLED',
      fallback: false,
    );
  }

  static bool get nativeIosVoiceEnabled {
    return _boolConfig(
      dartDefineValue: _experimentalNativeIosVoiceEnabledOverride,
      envKey: 'REX_EXPERIMENTAL_NATIVE_IOS_VOICE_ENABLED',
      fallback: false,
    );
  }

  static bool get legacyNativeIosVoiceFlagRequested {
    return _boolConfig(
      dartDefineValue: _legacyNativeIosVoiceEnabledOverride,
      envKey: 'REX_NATIVE_IOS_VOICE_ENABLED',
      fallback: false,
    );
  }

  static String _stringConfig({
    required String dartDefineValue,
    required String envKey,
    required String fallback,
  }) {
    final override = dartDefineValue.trim();
    if (override.isNotEmpty) {
      return override;
    }
    String? envValue;
    try {
      envValue = dotenv.env[envKey]?.trim();
    } on Object {
      envValue = null;
    }
    return envValue == null || envValue.isEmpty ? fallback : envValue;
  }

  static bool _boolConfig({
    required String dartDefineValue,
    required String envKey,
    required bool fallback,
  }) {
    final value = _stringConfig(
      dartDefineValue: dartDefineValue,
      envKey: envKey,
      fallback: fallback.toString(),
    ).toLowerCase();
    return {'1', 'true', 'yes', 'on'}.contains(value);
  }
}
