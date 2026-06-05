import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/rex/rex_config.dart';
import 'package:clarity/features/assistant/voice/data/audio_capture_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_playback_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_session_service.dart';
import 'package:clarity/features/assistant/voice/data/background_voice_service.dart';
import 'package:clarity/features/assistant/voice/data/cloud_voice_api.dart';
import 'package:clarity/features/assistant/voice/data/native_voice_session_service.dart';
import 'package:clarity/features/assistant/voice/data/speech_to_text_service.dart';
import 'package:clarity/features/assistant/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/features/assistant/voice/data/streaming_audio_playback_queue.dart';
import 'package:clarity/features/assistant/voice/data/streaming_voice_api.dart';
import 'package:clarity/features/assistant/voice/application/voice_permission_service.dart';

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
  (ref) => PackageVoiceAudioSessionService(),
);

final backgroundVoiceServiceProvider = Provider<BackgroundVoiceService>(
  (ref) => MethodChannelBackgroundVoiceService(),
);

final nativeVoiceSessionServiceProvider = Provider<NativeVoiceSessionService>(
  (ref) => MethodChannelNativeVoiceSessionService(),
);

final cloudVoiceApiProvider = Provider<CloudVoiceApi>((ref) => CloudVoiceApi());

final cloudVoiceEnabledProvider = Provider<bool>(
  (ref) => RexConfig.cloudVoiceEnabled,
);

final audioCaptureServiceProvider = Provider<AudioCaptureService>(
  (ref) => PackageAudioCaptureService(),
);

final streamingAudioCaptureServiceProvider =
    Provider<StreamingAudioCaptureService>(
      (ref) => PackageStreamingAudioCaptureService(),
    );

final bargeInDetectionServiceProvider = Provider<BargeInDetectionService>(
  (ref) => PackageBargeInDetectionService(),
);

final voiceCallBargeInEnabledProvider = Provider<bool>((ref) => false);

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
  (ref) => const VoiceCaptureConfig(),
);

typedef VoiceCallNow = DateTime Function();

final voiceCallNowProvider = Provider<VoiceCallNow>((ref) => DateTime.now);

final voiceCallThinkingTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 45),
);

final voiceCallTranscriptIdleTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 4),
);

final voiceCallSpeechStartTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 90),
);

final voiceCallNoSpeechTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);
