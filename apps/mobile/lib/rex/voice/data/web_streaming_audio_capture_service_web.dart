import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:clarity/rex/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/rex/voice/data/voice_capture_config.dart';
import 'package:clarity/rex/voice/data/voice_pcm16.dart';
import 'package:clarity/rex/voice/data/web_pcm_microphone_engine.dart';

StreamingAudioCaptureService createPlatformStreamingAudioCaptureService() {
  return WebStreamingAudioCaptureService();
}

class WebStreamingAudioCaptureService implements StreamingAudioCaptureService {
  static const _maximumStreamingSilenceAfterSpeech = Duration(
    milliseconds: 6000,
  );
  static const _minimumStreamingSpeechDuration = Duration(milliseconds: 260);
  static const _streamingSpeechStartThresholdDb = -68.0;
  static const _streamingSilenceThresholdDb = -74.0;

  WebStreamingAudioCaptureService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  StreamSubscription<Uint8List>? _streamSubscription;
  Completer<bool>? _captureCompleter;
  Timer? _noSpeechTimer;
  Timer? _maxDurationTimer;

  @override
  Future<bool> streamUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  }) async {
    await cancel();
    final endpointConfig = _streamingEndpointConfig(config);
    final detector = VoiceEndpointDetector(
      config: endpointConfig,
      startedAt: _now(),
    );
    _captureCompleter = Completer<bool>();
    var speechEndedNotified = false;

    final session = await WebPcmMicrophoneEngine.instance.startCapture(
      sampleRate: 16000,
      numChannels: 1,
    );
    final completer = _captureCompleter;
    if (completer == null || completer.isCompleted) {
      await WebPcmMicrophoneEngine.instance.stopCapture();
      return false;
    }
    onReady();

    _streamSubscription = session.stream.listen(
      (chunk) {
        unawaited(onAudioChunk(chunk));
        final update = detector.addAmplitude(
          currentDb: pcm16Decibels(chunk),
          now: _now(),
        );
        if (update.speechStarted) {
          onSpeechStart();
        }
        if (update.endpointReached && !speechEndedNotified) {
          speechEndedNotified = true;
          onSpeechEnded();
        }
        if (update.endpointReached || update.maxDurationReached) {
          unawaited(_complete(keepAudio: detector.hasSpeech));
        } else if (update.noSpeechTimedOut) {
          unawaited(_complete(keepAudio: false));
        }
      },
      onError: (_) {
        unawaited(_complete(keepAudio: false));
      },
      cancelOnError: true,
    );

    _noSpeechTimer = Timer(endpointConfig.noSpeechTimeout, () {
      if (!detector.hasSpeech) {
        unawaited(_complete(keepAudio: false));
      }
    });
    _maxDurationTimer = Timer(endpointConfig.maxUtteranceDuration, () {
      unawaited(_complete(keepAudio: detector.hasSpeech));
    });

    return _captureCompleter!.future;
  }

  @override
  Future<void> cancel() async {
    _noSpeechTimer?.cancel();
    _noSpeechTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_captureCompleter != null && !_captureCompleter!.isCompleted) {
      _captureCompleter!.complete(false);
    }
    _captureCompleter = null;
    await WebPcmMicrophoneEngine.instance.stopCapture();
  }

  Future<void> _complete({required bool keepAudio}) async {
    final completer = _captureCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    _noSpeechTimer?.cancel();
    _noSpeechTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await WebPcmMicrophoneEngine.instance.stopCapture();
    completer.complete(keepAudio);
  }

  VoiceCaptureConfig _streamingEndpointConfig(VoiceCaptureConfig config) {
    return VoiceCaptureConfig(
      amplitudeInterval: config.amplitudeInterval,
      speechStartThresholdDb: min(
        config.speechStartThresholdDb,
        _streamingSpeechStartThresholdDb,
      ),
      silenceThresholdDb: min(
        config.silenceThresholdDb,
        _streamingSilenceThresholdDb,
      ),
      silenceAfterSpeech: _shorterDuration(
        config.silenceAfterSpeech,
        _maximumStreamingSilenceAfterSpeech,
      ),
      noSpeechTimeout: config.noSpeechTimeout,
      maxUtteranceDuration: config.maxUtteranceDuration,
      minSpeechDuration: _longerDuration(
        config.minSpeechDuration,
        _minimumStreamingSpeechDuration,
      ),
    );
  }

  Duration _longerDuration(Duration value, Duration minimum) {
    return value.compareTo(minimum) >= 0 ? value : minimum;
  }

  Duration _shorterDuration(Duration value, Duration maximum) {
    return value.compareTo(maximum) <= 0 ? value : maximum;
  }
}
