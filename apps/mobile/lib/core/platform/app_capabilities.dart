import 'package:flutter/foundation.dart';

/// Honest feature gates for Clarity across mobile, web, and desktop targets.
///
/// UI and services should consult these flags before invoking native plugins,
/// Plaid Link, voice bridges, or file-based CSV import.
final class AppCapabilities {
  const AppCapabilities({
    required this.isWeb,
    required this.platform,
    required this.supportsNativePlaidLink,
    required this.supportsWebPlaidLink,
    required this.supportsStreamingVoice,
    required this.supportsBackgroundVoice,
    required this.supportsNativeVoiceBridge,
    required this.supportsCsvImport,
  });

  /// Resolves capabilities for the running app using [kIsWeb] and
  /// [defaultTargetPlatform].
  factory AppCapabilities.current() {
    return AppCapabilities.forPlatform(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }

  /// Test helper to assert platform gates without relying on the host OS.
  @visibleForTesting
  factory AppCapabilities.forPlatform({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    final nativeMobile = !isWeb &&
        (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android);

    return AppCapabilities(
      isWeb: isWeb,
      platform: platform,
      supportsNativePlaidLink: nativeMobile,
      supportsWebPlaidLink: isWeb,
      supportsStreamingVoice: isWeb || nativeMobile,
      supportsBackgroundVoice: nativeMobile,
      supportsNativeVoiceBridge: !isWeb && platform == TargetPlatform.iOS,
      supportsCsvImport: !isWeb,
    );
  }

  static final AppCapabilities instance = AppCapabilities.current();

  final bool isWeb;
  final TargetPlatform platform;

  /// Native Plaid Link via platform MethodChannel (iOS/Android).
  final bool supportsNativePlaidLink;

  /// Plaid Link in the browser (Flutter web).
  final bool supportsWebPlaidLink;

  /// Streaming voice WebSocket pipeline (mobile + Flutter web).
  final bool supportsStreamingVoice;

  /// Native background audio session for voice calls.
  final bool supportsBackgroundVoice;

  /// iOS native voice bridge (MethodChannel + EventChannel).
  final bool supportsNativeVoiceBridge;

  /// CSV statement import via local temp files (`dart:io`).
  final bool supportsCsvImport;

  /// Any Plaid bank-connect path available on this platform.
  bool get supportsAnyPlaidLink =>
      supportsNativePlaidLink || supportsWebPlaidLink;

  /// Any voice interaction path available on this platform.
  bool get supportsAnyVoice =>
      supportsStreamingVoice || supportsNativeVoiceBridge;

  /// Profile voice usage charts and Supabase `user_voice_summaries` reads.
  /// Same on web and mobile when the user is signed in.
  bool get supportsVoiceUsageSummary => true;

  @override
  bool operator ==(Object other) {
    return other is AppCapabilities &&
        other.isWeb == isWeb &&
        other.platform == platform &&
        other.supportsNativePlaidLink == supportsNativePlaidLink &&
        other.supportsWebPlaidLink == supportsWebPlaidLink &&
        other.supportsStreamingVoice == supportsStreamingVoice &&
        other.supportsBackgroundVoice == supportsBackgroundVoice &&
        other.supportsNativeVoiceBridge == supportsNativeVoiceBridge &&
        other.supportsCsvImport == supportsCsvImport;
  }

  @override
  int get hashCode => Object.hash(
    isWeb,
    platform,
    supportsNativePlaidLink,
    supportsWebPlaidLink,
    supportsStreamingVoice,
    supportsBackgroundVoice,
    supportsNativeVoiceBridge,
    supportsCsvImport,
  );

  @override
  String toString() {
    return 'AppCapabilities('
        'isWeb: $isWeb, '
        'platform: $platform, '
        'nativePlaid: $supportsNativePlaidLink, '
        'webPlaid: $supportsWebPlaidLink, '
        'streamingVoice: $supportsStreamingVoice, '
        'backgroundVoice: $supportsBackgroundVoice, '
        'nativeVoiceBridge: $supportsNativeVoiceBridge, '
        'csvImport: $supportsCsvImport)';
  }
}
