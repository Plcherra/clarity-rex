import 'dart:async';
import 'dart:typed_data';

/// Non-web stub. Voice capture on web uses [WebPcmMicrophoneEngine].
class WebPcmMicrophoneEngine {
  WebPcmMicrophoneEngine._();

  static final WebPcmMicrophoneEngine instance = WebPcmMicrophoneEngine._();

  Future<WebPcmCaptureSession> startCapture({
    int sampleRate = 16000,
    int numChannels = 1,
    int streamBufferSize = 2048,
  }) {
    throw UnsupportedError('Web PCM capture is only available on Flutter web.');
  }

  Future<void> stopCapture() async {}
}

final class WebPcmCaptureSession {
  WebPcmCaptureSession({required Stream<Uint8List> stream}) : stream = stream;

  final Stream<Uint8List> stream;
}
