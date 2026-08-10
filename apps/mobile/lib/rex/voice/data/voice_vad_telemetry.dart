import 'package:clarity/rex/voice/data/voice_capture_config.dart';

/// Sampled amplitude-endpoint diagnostics — never stores PCM / raw audio.
class VoiceVadTelemetry {
  VoiceVadTelemetry();

  static final VoiceVadTelemetry instance = VoiceVadTelemetry();

  static const _sampleInterval = Duration(milliseconds: 400);

  VoiceCaptureConfig? _config;
  String _pcmFormat = 'pcm16le/16kHz/mono';
  String _audioRoute = 'unknown';
  var _chunkCount = 0;
  var _byteCount = 0;
  var _sumDb = 0.0;
  var _minDb = 0.0;
  var _maxDb = -160.0;
  var _aboveSpeechStart = 0;
  var _aboveSilenceFloor = 0;
  var _lastSpeechRefreshCount = 0;
  var _wouldEndpointCount = 0;
  int? _lastWouldEndpointSilenceMs;
  DateTime? _lastSampleAt;
  double? _lastSampledDb;
  var _hasSpeech = false;

  void resetForCapture({
    required VoiceCaptureConfig config,
    String pcmFormat = 'pcm16le/16kHz/mono',
    String audioRoute = 'unknown',
  }) {
    _config = config;
    _pcmFormat = pcmFormat;
    _audioRoute = audioRoute;
    _chunkCount = 0;
    _byteCount = 0;
    _sumDb = 0.0;
    _minDb = 0.0;
    _maxDb = -160.0;
    _aboveSpeechStart = 0;
    _aboveSilenceFloor = 0;
    _lastSpeechRefreshCount = 0;
    _wouldEndpointCount = 0;
    _lastWouldEndpointSilenceMs = null;
    _lastSampleAt = null;
    _lastSampledDb = null;
    _hasSpeech = false;
  }

  void setAudioRoute(String route) {
    if (route.trim().isNotEmpty) {
      _audioRoute = route.trim();
    }
  }

  void observeChunk({
    required double currentDb,
    required int byteCount,
    required DateTime now,
    required bool lastSpeechRefreshed,
    required bool wouldEndpoint,
    required int? silenceMs,
    required bool hasSpeech,
  }) {
    final config = _config;
    _chunkCount++;
    _byteCount += byteCount;
    _hasSpeech = hasSpeech;
    if (_chunkCount == 1) {
      _minDb = currentDb;
      _maxDb = currentDb;
      _sumDb = currentDb;
    } else {
      if (currentDb < _minDb) {
        _minDb = currentDb;
      }
      if (currentDb > _maxDb) {
        _maxDb = currentDb;
      }
      _sumDb += currentDb;
    }
    if (config != null) {
      if (currentDb >= config.speechStartThresholdDb) {
        _aboveSpeechStart++;
      }
      if (currentDb >= config.silenceThresholdDb) {
        _aboveSilenceFloor++;
      }
    }
    if (lastSpeechRefreshed) {
      _lastSpeechRefreshCount++;
    }
    if (wouldEndpoint) {
      _wouldEndpointCount++;
      _lastWouldEndpointSilenceMs = silenceMs;
    }

    final lastSample = _lastSampleAt;
    if (lastSample == null ||
        now.difference(lastSample) >= _sampleInterval) {
      _lastSampleAt = now;
      _lastSampledDb = currentDb;
    }
  }

  double get averageDb =>
      _chunkCount == 0 ? 0 : _sumDb / _chunkCount;

  double get pctAboveSpeechStart =>
      _chunkCount == 0 ? 0 : 100.0 * _aboveSpeechStart / _chunkCount;

  double get pctAboveSilenceFloor =>
      _chunkCount == 0 ? 0 : 100.0 * _aboveSilenceFloor / _chunkCount;

  Map<String, Object?> toMap() {
    final config = _config;
    return {
      'pcm_format': _pcmFormat,
      'audio_route': _audioRoute,
      'silence_after_speech_ms': config?.silenceAfterSpeech.inMilliseconds,
      'speech_start_db': config?.speechStartThresholdDb,
      'silence_floor_db': config?.silenceThresholdDb,
      'min_speech_ms': config?.minSpeechDuration.inMilliseconds,
      'chunk_count': _chunkCount,
      'byte_count': _byteCount,
      'current_db_sampled': _lastSampledDb,
      'min_db': _chunkCount == 0 ? null : _minDb,
      'max_db': _chunkCount == 0 ? null : _maxDb,
      'avg_db': _chunkCount == 0 ? null : averageDb,
      'pct_above_speech_start': pctAboveSpeechStart,
      'pct_above_silence_floor': pctAboveSilenceFloor,
      'last_speech_refresh_count': _lastSpeechRefreshCount,
      'would_endpoint_count': _wouldEndpointCount,
      'last_would_endpoint_silence_ms': _lastWouldEndpointSilenceMs,
      'has_speech': _hasSpeech,
    };
  }

  /// Compact one-line summary for owner export / debugPrint.
  String summaryLine() {
    final config = _config;
    final silenceMs = config?.silenceAfterSpeech.inMilliseconds ?? -1;
    final sampled = _lastSampledDb?.toStringAsFixed(1) ?? 'n/a';
    return 'vad_telemetry '
        'silence_ms=$silenceMs '
        'chunks=$_chunkCount bytes=$_byteCount '
        'db[cur=$sampled min=${_minDb.toStringAsFixed(1)} '
        'max=${_maxDb.toStringAsFixed(1)} avg=${averageDb.toStringAsFixed(1)}] '
        'pct_start=${pctAboveSpeechStart.toStringAsFixed(1)} '
        'pct_floor=${pctAboveSilenceFloor.toStringAsFixed(1)} '
        'last_speech_refresh=$_lastSpeechRefreshCount '
        'would_endpoint=$_wouldEndpointCount '
        'silence_at_would=${_lastWouldEndpointSilenceMs ?? -1}ms '
        'route=$_audioRoute format=$_pcmFormat';
  }
}
