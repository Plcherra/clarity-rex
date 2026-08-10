typedef SpeechStartCallback = void Function();
typedef CaptureReadyCallback = void Function();

class VoiceCaptureConfig {
  const VoiceCaptureConfig({
    this.amplitudeInterval = const Duration(milliseconds: 80),
    this.speechStartThresholdDb = -50,
    this.silenceThresholdDb = -58,
    this.silenceAfterSpeech = const Duration(milliseconds: 4000),
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
    required this.lastSpeechRefreshed,
    required this.silenceMs,
  });

  final bool speechStarted;
  final bool endpointReached;
  final bool noSpeechTimedOut;
  final bool maxDurationReached;

  /// True when this chunk refreshed [_VoiceEndpointDetector._lastSpeechAt].
  final bool lastSpeechRefreshed;

  /// Milliseconds since last speech energy, or null before speech starts.
  final int? silenceMs;
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

  DateTime? get lastSpeechAt => _lastSpeechAt;

  VoiceEndpointUpdate addAmplitude({
    required double currentDb,
    required DateTime now,
  }) {
    var speechStartedNow = false;
    var lastSpeechRefreshed = false;
    // Hysteresis: start speech only above the start threshold, but keep the
    // turn alive through quieter syllables / breath residue above the lower
    // silence floor. Ambient noise below silenceThreshold does not count.
    if (!_hasSpeech) {
      if (currentDb >= config.speechStartThresholdDb) {
        speechStartedNow = true;
        _speechStartedAt = now;
        _hasSpeech = true;
        _lastSpeechAt = now;
        lastSpeechRefreshed = true;
      }
    } else if (currentDb >= config.silenceThresholdDb) {
      _lastSpeechAt = now;
      lastSpeechRefreshed = true;
    }

    final noSpeechTimedOut =
        !_hasSpeech && now.difference(_startedAt) >= config.noSpeechTimeout;
    final maxDurationReached =
        now.difference(_startedAt) >= config.maxUtteranceDuration;

    var endpointReached = false;
    int? silenceMs;
    final speechStartedAt = _speechStartedAt;
    final lastSpeechAt = _lastSpeechAt;
    if (_hasSpeech && speechStartedAt != null && lastSpeechAt != null) {
      final speechDuration = now.difference(speechStartedAt);
      final silenceDuration = now.difference(lastSpeechAt);
      silenceMs = silenceDuration.inMilliseconds;
      endpointReached =
          speechDuration >= config.minSpeechDuration &&
          silenceDuration >= config.silenceAfterSpeech;
    }

    return VoiceEndpointUpdate(
      speechStarted: speechStartedNow,
      endpointReached: endpointReached,
      noSpeechTimedOut: noSpeechTimedOut,
      maxDurationReached: maxDurationReached,
      lastSpeechRefreshed: lastSpeechRefreshed,
      silenceMs: silenceMs,
    );
  }
}
