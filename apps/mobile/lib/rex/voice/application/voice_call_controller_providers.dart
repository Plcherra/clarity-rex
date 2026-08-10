import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/core/rex/rex_config.dart';
import 'package:clarity/rex/voice/data/audio_capture_service.dart';
import 'package:clarity/rex/voice/data/audio_capture_service_io.dart'
    if (dart.library.html) 'package:clarity/rex/voice/data/audio_capture_service_web.dart'
    as audio_capture_platform;
import 'package:clarity/rex/voice/data/audio_playback_service.dart';
import 'package:clarity/rex/voice/data/audio_session_service.dart';
import 'package:clarity/rex/voice/data/background_voice_service.dart';
import 'package:clarity/rex/voice/data/cloud_voice_api.dart';
import 'package:clarity/rex/voice/data/native_voice_session_service.dart';
import 'package:clarity/rex/voice/data/speech_to_text_service.dart';
import 'package:clarity/rex/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/rex/voice/data/web_streaming_audio_capture_service.dart'
    as streaming_capture_platform;
import 'package:clarity/rex/voice/data/streaming_audio_playback_queue.dart';
import 'package:clarity/rex/voice/data/streaming_voice_client.dart';
import 'package:clarity/rex/voice/data/streaming_voice_api.dart';
import 'package:clarity/rex/voice/data/web_voice_service_stubs.dart';
import 'package:clarity/rex/voice/application/voice_permission_service.dart';

final appCapabilitiesProvider = Provider<AppCapabilities>(
  (ref) => AppCapabilities.instance,
);

final microphonePermissionProvider = Provider<MicrophonePermissionService>(
  (ref) => RecordMicrophonePermissionService(),
);

final speechToTextServiceProvider = Provider<SpeechToTextService>(
  (ref) => PackageSpeechToTextService(),
);

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>(
  (ref) => PackageAudioPlaybackService(),
);

final voiceAudioSessionServiceProvider = Provider<VoiceAudioSessionService>(
  (ref) {
    final caps = ref.watch(appCapabilitiesProvider);
    if (caps.supportsBackgroundVoice) {
      return PackageVoiceAudioSessionService();
    }
    return const NoOpVoiceAudioSessionService();
  },
);

final backgroundVoiceServiceProvider = Provider<BackgroundVoiceService>(
  (ref) {
    final caps = ref.watch(appCapabilitiesProvider);
    if (caps.supportsBackgroundVoice) {
      return MethodChannelBackgroundVoiceService();
    }
    return const NoOpBackgroundVoiceService();
  },
);

final nativeVoiceSessionServiceProvider = Provider<NativeVoiceSessionService>(
  (ref) {
    final caps = ref.watch(appCapabilitiesProvider);
    if (caps.supportsNativeVoiceBridge) {
      return MethodChannelNativeVoiceSessionService();
    }
    return const NoOpNativeVoiceSessionService();
  },
);

final cloudVoiceApiProvider = Provider<CloudVoiceApi>((ref) => CloudVoiceApi());

final cloudVoiceEnabledProvider = Provider<bool>(
  (ref) => RexConfig.cloudVoiceEnabled,
);

final audioCaptureServiceProvider = Provider<AudioCaptureService>(
  (ref) => audio_capture_platform.createPackageAudioCaptureService(),
);

final streamingAudioCaptureServiceProvider =
    Provider<StreamingAudioCaptureService>(
      (ref) => streaming_capture_platform
          .createPlatformStreamingAudioCaptureService(),
    );

final bargeInDetectionServiceProvider = Provider<BargeInDetectionService>(
  (ref) => PackageBargeInDetectionService(),
);

final voiceCallBargeInEnabledProvider = Provider<bool>((ref) => false);

final streamingVoiceClientProvider = Provider<String>(
  (ref) => streamingVoiceClientTag(isWeb: ref.watch(appCapabilitiesProvider).isWeb),
);

final streamingVoiceApiProvider = Provider<StreamingVoiceApi>(
  (ref) => StreamingVoiceApi(),
);

final streamingAudioPlaybackQueueProvider =
    Provider<StreamingAudioPlaybackQueue>(
      (ref) =>
          StreamingAudioPlaybackQueue(ref.read(audioPlaybackServiceProvider)),
    );

final streamingVoiceEnabledProvider = Provider<bool>(
  (ref) => RexConfig.streamingVoiceEnabled,
);

final nativeIosVoiceEnabledProvider = Provider<bool>(
  (ref) => RexConfig.nativeIosVoiceEnabled,
);

final legacyNativeIosVoiceFlagRequestedProvider = Provider<bool>(
  (ref) => RexConfig.legacyNativeIosVoiceFlagRequested,
);

final voiceCallPlatformProvider = Provider<TargetPlatform>(
  (ref) => defaultTargetPlatform,
);

final voiceCaptureConfigProvider = Provider<VoiceCaptureConfig>(
  (ref) => kIsWeb
      ? const VoiceCaptureConfig(
          speechStartThresholdDb: -68,
          silenceThresholdDb: -74,
          silenceAfterSpeech: Duration(milliseconds: 4000),
          noSpeechTimeout: Duration(seconds: 18),
        )
      // Walking / breath pauses: end only after sustained true silence, not a
      // short inhale. Soft floor keeps quiet syllables from looking like silence.
      : const VoiceCaptureConfig(
          speechStartThresholdDb: -55,
          silenceThresholdDb: -72,
          silenceAfterSpeech: Duration(milliseconds: 8000),
          maxUtteranceDuration: Duration(seconds: 180),
        ),
);

typedef VoiceCallNow = DateTime Function();

final voiceCallNowProvider = Provider<VoiceCallNow>((ref) => DateTime.now);

final voiceCallThinkingTimeoutProvider = Provider<Duration>(
  // UX recovery for stuck thinking — not a race patch. Raised for slow Grok
  // turns; confirm-active path still gates recovery (see timers A25).
  (ref) => const Duration(seconds: 90),
);

final voiceCallTranscriptIdleTimeoutProvider = Provider<Duration>(
  // STT transcript-stability endpoint for flutter_streaming (re-armed on each
  // transcript update). Match mobile VAD silence so a quiet STT gap mid-sentence
  // does not cut the turn while the mic is still open.
  (ref) => const Duration(milliseconds: 8000),
);

final voiceCallSpeechStartTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 90),
);

final voiceCallNoSpeechTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 24),
);
