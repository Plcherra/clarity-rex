import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCapabilities.forPlatform', () {
    test('web disables native-only features', () {
      final caps = AppCapabilities.forPlatform(
        isWeb: true,
        platform: TargetPlatform.windows,
      );

      expect(caps.isWeb, isTrue);
      expect(caps.supportsNativePlaidLink, isFalse);
      expect(caps.supportsWebPlaidLink, isTrue);
      expect(caps.supportsStreamingVoice, isFalse);
      expect(caps.supportsBackgroundVoice, isFalse);
      expect(caps.supportsNativeVoiceBridge, isFalse);
      expect(caps.supportsCsvImport, isFalse);
      expect(caps.supportsAnyPlaidLink, isTrue);
      expect(caps.supportsAnyVoice, isFalse);
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
    });
  });
}
