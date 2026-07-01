import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/rex/voice/data/streaming_voice_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCapabilities.forPlatform', () {
    test('web enables streaming voice and disables native-only bridges', () {
      final caps = AppCapabilities.forPlatform(
        isWeb: true,
        platform: TargetPlatform.windows,
      );

      expect(caps.isWeb, isTrue);
      expect(caps.supportsNativePlaidLink, isFalse);
      expect(caps.supportsWebPlaidLink, isTrue);
      expect(caps.supportsStreamingVoice, isTrue);
      expect(caps.supportsBackgroundVoice, isFalse);
      expect(caps.supportsNativeVoiceBridge, isFalse);
      expect(caps.supportsCsvImport, isFalse);
      expect(caps.supportsAnyPlaidLink, isTrue);
      expect(caps.supportsAnyVoice, isTrue);
    });

    test('iOS enables native mobile features except web Plaid', () {
      final caps = AppCapabilities.forPlatform(
        isWeb: false,
        platform: TargetPlatform.iOS,
      );

      expect(caps.supportsNativePlaidLink, isTrue);
      expect(caps.supportsWebPlaidLink, isFalse);
      expect(caps.supportsStreamingVoice, isTrue);
      expect(caps.supportsBackgroundVoice, isTrue);
      expect(caps.supportsNativeVoiceBridge, isTrue);
      expect(caps.supportsCsvImport, isTrue);
      expect(caps.supportsAnyPlaidLink, isTrue);
      expect(caps.supportsAnyVoice, isTrue);
    });

    test('Android enables native mobile features without iOS voice bridge', () {
      final caps = AppCapabilities.forPlatform(
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(caps.supportsNativePlaidLink, isTrue);
      expect(caps.supportsStreamingVoice, isTrue);
      expect(caps.supportsBackgroundVoice, isTrue);
      expect(caps.supportsNativeVoiceBridge, isFalse);
      expect(caps.supportsCsvImport, isTrue);
    });

    test('desktop native targets disable mobile-only bridges', () {
      final caps = AppCapabilities.forPlatform(
        isWeb: false,
        platform: TargetPlatform.macOS,
      );

      expect(caps.supportsNativePlaidLink, isFalse);
      expect(caps.supportsStreamingVoice, isFalse);
      expect(caps.supportsBackgroundVoice, isFalse);
      expect(caps.supportsNativeVoiceBridge, isFalse);
      expect(caps.supportsCsvImport, isTrue);
      expect(caps.supportsAnyVoice, isFalse);
    });

    test('web and mobile both use streaming voice client tags', () {
      expect(
        streamingVoiceClientTag(isWeb: true),
        'flutter_streaming_web',
      );
      expect(
        streamingVoiceClientTag(isWeb: false),
        'flutter_streaming',
      );
    });
  });
}
