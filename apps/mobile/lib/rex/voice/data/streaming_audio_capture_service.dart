import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'package:clarity/rex/voice/data/voice_capture_config.dart';
import 'package:clarity/rex/voice/data/voice_pcm16.dart';

typedef AudioChunkCallback = Future<void> Function(Uint8List chunk);
typedef SpeechEndCallback = void Function();
typedef BargeInCallback = void Function(List<Uint8List> audioChunks);

abstract class StreamingAudioCaptureService {
  Future<bool> streamUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  });

  Future<void> cancel();
}

abstract class BargeInDetectionService {
  Future<void> start({
    required VoiceCaptureConfig config,
    required BargeInCallback onBargeIn,
  });

  Future<void> stop();
}

class PackageBargeInDetectionService implements BargeInDetectionService {
  static const _bargeInGracePeriod = Duration(milliseconds: 1600);
  static const _bargeInMinimumSpeechDuration = Duration(milliseconds: 650);
  static const _bargeInSpeechThresholdDb = -24.0;
  static const _bargeInPreRollBytes = 16000;

  PackageBargeInDetectionService({
    AudioRecorder? recorder,
    DateTime Function()? now,
  }) : _recorder = recorder ?? AudioRecorder(),
       _now = now ?? DateTime.now;

  final AudioRecorder _recorder;
  final DateTime Function() _now;
  StreamSubscription<Uint8List>? _streamSubscription;
  final Queue<Uint8List> _preRollChunks = Queue<Uint8List>();
  DateTime? _startedAt;
  DateTime? _speechStartedAt;
  var _notified = false;

  @override
  Future<void> start({
    required VoiceCaptureConfig config,
    required BargeInCallback onBargeIn,
  }) async {
    await stop();
    _startedAt = _now();
    _speechStartedAt = null;
    _notified = false;
    _preRollChunks.clear();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _streamSubscription = stream.listen(
      (chunk) {
        if (_notified) {
          return;
        }

        final startedAt = _startedAt;
        final now = _now();
        if (startedAt == null ||
            now.difference(startedAt) < _bargeInGracePeriod) {
          _preRollChunks.clear();
          return;
        }

        final currentDb = pcm16Decibels(chunk);
        if (currentDb < _bargeInSpeechThresholdDb) {
          _speechStartedAt = null;
          _preRollChunks.clear();
          return;
        }

        _speechStartedAt ??= now;
        _rememberPreRollChunk(chunk);
        if (now.difference(_speechStartedAt!) >=
            _bargeInMinimumSpeechDuration) {
          _notified = true;
          onBargeIn(_preRollSnapshot());
          unawaited(stop());
        }
      },
      onError: (_) {
        unawaited(stop());
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> stop() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _startedAt = null;
    _speechStartedAt = null;
    _notified = false;
    _preRollChunks.clear();
    try {
      await _recorder.cancel();
    } on Object {
      // The recorder may already be stopped.
    }
  }

  void _rememberPreRollChunk(Uint8List chunk) {
    if (chunk.isEmpty) {
      return;
    }
    _preRollChunks.add(Uint8List.fromList(chunk));
    var totalBytes = _preRollChunks.fold<int>(
      0,
      (total, item) => total + item.length,
    );
    while (totalBytes > _bargeInPreRollBytes && _preRollChunks.isNotEmpty) {
      totalBytes -= _preRollChunks.removeFirst().length;
    }
  }

  List<Uint8List> _preRollSnapshot() {
    return _preRollChunks
        .map((chunk) => Uint8List.fromList(chunk))
        .toList(growable: false);
  }
}

class PackageStreamingAudioCaptureService
    implements StreamingAudioCaptureService {
  static const _maximumStreamingSilenceAfterSpeech = Duration(
    milliseconds: 950,
  );
  static const _minimumStreamingSpeechDuration = Duration(milliseconds: 260);
  static const _streamingSpeechStartThresholdDb = -50.0;
  static const _streamingSilenceThresholdDb = -58.0;

  PackageStreamingAudioCaptureService({
    AudioRecorder? recorder,
    DateTime Function()? now,
  }) : _recorder = recorder ?? AudioRecorder(),
       _now = now ?? DateTime.now;

  final AudioRecorder _recorder;
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

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    onReady();

    _streamSubscription = stream.listen(
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
    try {
      await _recorder.cancel();
    } on Object {
      // The recorder may already be stopped.
    }
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
    try {
      await _recorder.stop();
    } on Object {
      // Treat native stop failures as an empty capture.
    }
    completer.complete(keepAudio);
  }

  VoiceCaptureConfig _streamingEndpointConfig(VoiceCaptureConfig config) {
    // Live PCM chunks are bursty on mobile, but calls should feel responsive.
    // Cap endpoint silence so voice mode can hand off to STT quickly.
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
