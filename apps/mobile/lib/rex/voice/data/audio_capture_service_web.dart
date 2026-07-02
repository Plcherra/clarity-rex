import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:record/record.dart';

import 'package:clarity/rex/voice/data/audio_capture_service.dart';
import 'package:clarity/rex/voice/data/voice_pcm16.dart';
import 'package:clarity/rex/voice/data/web_pcm_microphone_engine.dart';

/// Browser REST fallback capture using the shared web PCM engine.
class WebStreamBackedAudioCaptureService implements AudioCaptureService {
  WebStreamBackedAudioCaptureService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  StreamSubscription<Uint8List>? _streamSubscription;
  Completer<RecordedVoiceAudio?>? _captureCompleter;
  Timer? _noSpeechTimer;
  Timer? _maxDurationTimer;
  final List<Uint8List> _chunks = [];

  @override
  Future<RecordedVoiceAudio?> captureUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
  }) async {
    await cancel();
    _chunks.clear();
    _captureCompleter = Completer<RecordedVoiceAudio?>();

    final detector = VoiceEndpointDetector(config: config, startedAt: _now());
    final session = await WebPcmMicrophoneEngine.instance.startCapture(
      sampleRate: 16000,
      numChannels: 1,
    );
    onReady();

    _streamSubscription = session.stream.listen(
      (chunk) {
        if (chunk.isNotEmpty) {
          _chunks.add(Uint8List.fromList(chunk));
        }
        final update = detector.addAmplitude(
          currentDb: pcm16Decibels(chunk),
          now: _now(),
        );
        if (update.speechStarted) {
          onSpeechStart();
        }
        if (update.endpointReached || update.maxDurationReached) {
          unawaited(_completeCapture(keepRecording: detector.hasSpeech));
        } else if (update.noSpeechTimedOut) {
          unawaited(_completeCapture(keepRecording: false));
        }
      },
      onError: (_) {
        unawaited(_completeCapture(keepRecording: false));
      },
      cancelOnError: true,
    );

    _maxDurationTimer = Timer(config.maxUtteranceDuration, () {
      unawaited(_completeCapture(keepRecording: detector.hasSpeech));
    });
    _noSpeechTimer = Timer(config.noSpeechTimeout, () {
      if (!detector.hasSpeech) {
        unawaited(_completeCapture(keepRecording: false));
      }
    });

    return _captureCompleter!.future;
  }

  @override
  Future<void> cancel() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _noSpeechTimer?.cancel();
    _noSpeechTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _chunks.clear();
    if (_captureCompleter != null && !_captureCompleter!.isCompleted) {
      _captureCompleter!.complete(null);
    }
    _captureCompleter = null;
    await WebPcmMicrophoneEngine.instance.stopCapture();
  }

  Future<void> _completeCapture({required bool keepRecording}) async {
    final completer = _captureCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _noSpeechTimer?.cancel();
    _noSpeechTimer = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await WebPcmMicrophoneEngine.instance.stopCapture();

    if (!keepRecording) {
      _chunks.clear();
      completer.complete(null);
      return;
    }

    final pcmBytes = mergePcm16Chunks(_chunks);
    _chunks.clear();
    if (pcmBytes.isEmpty) {
      completer.complete(null);
      return;
    }

    completer.complete(
      RecordedVoiceAudio(
        file: XFile.fromData(
          pcmBytes,
          name: 'rex-voice-call.pcm',
          mimeType: 'audio/pcm',
        ),
        inputMimeType: 'audio/linear16',
      ),
    );
  }
}

AudioCaptureService createPackageAudioCaptureService({
  AudioRecorder? recorder,
  DateTime Function()? now,
}) {
  return WebStreamBackedAudioCaptureService(now: now);
}
