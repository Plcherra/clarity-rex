typedef SpeechStartCallback = void Function();
typedef CaptureReadyCallback = void Function();

class VoiceCaptureConfig {
  const VoiceCaptureConfig({
    this.amplitudeInterval = const Duration(milliseconds: 80),
    this.speechStartThresholdDb = -50,
    this.silenceThresholdDb = -58,
    this.silenceAfterSpeech = const Duration(milliseconds: 3200),
    this.noSpeechTimeout = const Duration(seconds: 12),
    this.maxUtteranceDuration = const Duration(seconds: 120),
    this.minSpeechDuration = const Duration(milliseconds: 220),
  });

  final Duration amplitudeInterval;
  final double speechStartThresholdDb;
  final double silenceThresholdDb;
  final Duration silenceAfterSpeech;
  final Duration noSpeechTimeout;
  final Duration maxUtteranceDuration;
  final Duration minSpeechDuration;
}

class VoiceEndpointUpdate {
  const VoiceEndpointUpdate({
    required this.speechStarted,
    required this.endpointReached,
    required this.noSpeechTimedOut,
    required this.maxDurationReached,
  });

  final bool speechStarted;
  final bool endpointReached;
  final bool noSpeechTimedOut;
  final bool maxDurationReached;
}

class VoiceEndpointDetector {
  VoiceEndpointDetector({required this.config, required DateTime startedAt})
    : _startedAt = startedAt;

  final VoiceCaptureConfig config;
  final DateTime _startedAt;
  DateTime? _speechStartedAt;
  DateTime? _lastSpeechAt;
  var _hasSpeech = false;

  bool get hasSpeech => _hasSpeech;

  VoiceEndpointUpdate addAmplitude({
    required double currentDb,
    required DateTime now,
  }) {
    var speechStartedNow = false;
    // Only loud-enough samples count as speech. Avoid treating ambient noise
    // in the hysteresis band as ongoing speech, which delays endpoint detection.
    if (currentDb >= config.speechStartThresholdDb) {
      if (!_hasSpeech) {
        speechStartedNow = true;
        _speechStartedAt = now;
      }
      _hasSpeech = true;
      _lastSpeechAt = now;
    }

    final noSpeechTimedOut =
        !_hasSpeech && now.difference(_startedAt) >= config.noSpeechTimeout;
    final maxDurationReached =
        now.difference(_startedAt) >= config.maxUtteranceDuration;

    var endpointReached = false;
    final speechStartedAt = _speechStartedAt;
    final lastSpeechAt = _lastSpeechAt;
    if (_hasSpeech && speechStartedAt != null && lastSpeechAt != null) {
      final speechDuration = now.difference(speechStartedAt);
      final silenceDuration = now.difference(lastSpeechAt);
      endpointReached =
          speechDuration >= config.minSpeechDuration &&
          silenceDuration >= config.silenceAfterSpeech;
    }

    return VoiceEndpointUpdate(
      speechStarted: speechStartedNow,
      endpointReached: endpointReached,
      noSpeechTimedOut: noSpeechTimedOut,
      maxDurationReached: maxDurationReached,
    );
  }
}
