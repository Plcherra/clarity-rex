export 'package:clarity/rex/voice/data/recorded_voice_audio.dart';
export 'package:clarity/rex/voice/data/voice_capture_config.dart';

import 'package:clarity/rex/voice/data/recorded_voice_audio.dart';
import 'package:clarity/rex/voice/data/voice_capture_config.dart';

abstract class AudioCaptureService {
  Future<RecordedVoiceAudio?> captureUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
  });

  Future<void> cancel();
}
