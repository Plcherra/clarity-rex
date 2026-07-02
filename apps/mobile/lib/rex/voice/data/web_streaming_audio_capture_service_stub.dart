import 'package:clarity/rex/voice/data/streaming_audio_capture_service.dart';

StreamingAudioCaptureService createPlatformStreamingAudioCaptureService() {
  return PackageStreamingAudioCaptureService();
}
