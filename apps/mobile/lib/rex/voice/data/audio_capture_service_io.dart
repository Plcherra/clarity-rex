import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:record/record.dart';

import 'package:clarity/rex/voice/data/audio_capture_service.dart';

class PackageAudioCaptureService implements AudioCaptureService {
  PackageAudioCaptureService({
    AudioRecorder? recorder,
    DateTime Function()? now,
  }) : _recorder = recorder ?? AudioRecorder(),
       _now = now ?? DateTime.now;

  final AudioRecorder _recorder;
  final DateTime Function() _now;
  String? _recordingPath;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _maxDurationTimer;
  Timer? _noSpeechTimer;
  Completer<RecordedVoiceAudio?>? _captureCompleter;

  @override
  Future<RecordedVoiceAudio?> captureUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
  }) async {
    await cancel();

    final tempDirectory = await Directory.systemTemp.createTemp(
      'rex_voice_call_',
    );
    final path =
        '${tempDirectory.path}/call-${DateTime.now().microsecondsSinceEpoch}.m4a';
    _recordingPath = path;
    _captureCompleter = Completer<RecordedVoiceAudio?>();

    final detector = VoiceEndpointDetector(config: config, startedAt: _now());
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
      ),
      path: path,
    );
    onReady();

    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(config.amplitudeInterval)
        .listen((amplitude) {
          final update = detector.addAmplitude(
            currentDb: amplitude.current,
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
        });

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
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    if (_captureCompleter != null && !_captureCompleter!.isCompleted) {
      _captureCompleter!.complete(null);
    }
    _captureCompleter = null;
    _recordingPath = null;
    try {
      await _recorder.cancel();
    } on Object {
      // The recorder may not have an active native session yet.
    }
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
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (!keepRecording) {
      _recordingPath = null;
      try {
        await _recorder.cancel();
      } on Object {
        // Treat native cancel failures as an empty capture.
      }
      completer.complete(null);
      return;
    }

    final path = await _recorder.stop() ?? _recordingPath;
    _recordingPath = null;
    if (path == null || path.trim().isEmpty) {
      completer.complete(null);
      return;
    }

    completer.complete(
      RecordedVoiceAudio(
        file: XFile(path, name: 'rex-voice-call.m4a', mimeType: 'audio/mp4'),
        inputMimeType: 'audio/mp4',
      ),
    );
  }
}

AudioCaptureService createPackageAudioCaptureService({
  AudioRecorder? recorder,
  DateTime Function()? now,
}) {
  return PackageAudioCaptureService(recorder: recorder, now: now);
}
