part of 'voice_call_controller_test.dart';

class _GrantedMicrophonePermissionService
    implements MicrophonePermissionService {
  const _GrantedMicrophonePermissionService();

  @override
  Future<void> openSettings() async {}

  @override
  Future<MicrophonePermissionDecision> requestMicrophonePermission({
    bool includeSpeechRecognition = true,
  }) async {
    return MicrophonePermissionDecision.granted;
  }
}

class _NoopVoiceAudioSessionService implements VoiceAudioSessionService {
  const _NoopVoiceAudioSessionService();

  @override
  Future<void> configureForVoiceTurn() async {}

  @override
  Future<void> preferLoudSpeaker() async {}

  @override
  StreamSubscription<AudioInterruptionEvent> listenForInterruptions(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    return const Stream<AudioInterruptionEvent>.empty().listen((_) {});
  }

  @override
  StreamSubscription<void> listenForNoisyAudio(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    return const Stream<void>.empty().listen((_) {});
  }

  @override
  Future<void> setActive(bool active) async {}
}

class _NoopBackgroundVoiceService implements BackgroundVoiceService {
  const _NoopBackgroundVoiceService();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

class _CountingVoiceAudioSessionService implements VoiceAudioSessionService {
  var configureCount = 0;
  var preferLoudSpeakerCount = 0;

  @override
  Future<void> configureForVoiceTurn() async {
    configureCount++;
  }

  @override
  Future<void> preferLoudSpeaker() async {
    preferLoudSpeakerCount++;
  }

  @override
  StreamSubscription<AudioInterruptionEvent> listenForInterruptions(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    return const Stream<AudioInterruptionEvent>.empty().listen((_) {});
  }

  @override
  StreamSubscription<void> listenForNoisyAudio(
    VoiceAudioInterruptionCallback onInterrupted,
  ) {
    return const Stream<void>.empty().listen((_) {});
  }

  @override
  Future<void> setActive(bool active) async {}
}

class _CountingBackgroundVoiceService implements BackgroundVoiceService {
  var startCount = 0;
  var stopCount = 0;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _NoopAudioCaptureService implements AudioCaptureService {
  const _NoopAudioCaptureService();

  @override
  Future<void> cancel() async {}

  @override
  Future<RecordedVoiceAudio?> captureUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
  }) async {
    onReady();
    return null;
  }
}

class _NoopAudioPlaybackService implements AudioPlaybackService {
  const _NoopAudioPlaybackService();

  @override
  Future<void> pause() async {}

  @override
  Future<void> playBase64Audio(
    String audioBase64, {
    required String contentType,
    required AudioPlaybackCompleteCallback onComplete,
    required AudioPlaybackErrorCallback onError,
  }) async {
    onComplete();
  }

  @override
  Future<void> stop() async {}
}

class _HangingStreamingAudioCaptureService
    implements StreamingAudioCaptureService {
  final started = Completer<void>();
  final _capture = Completer<bool>();
  var cancelled = false;

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_capture.isCompleted) {
      _capture.complete(false);
    }
  }

  @override
  Future<bool> streamUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  }) {
    onReady();
    onSpeechStart();
    if (!started.isCompleted) {
      started.complete();
    }
    return _capture.future;
  }
}

class _ReusableSilentStreamingAudioCaptureService
    implements StreamingAudioCaptureService {
  final _ready = <Completer<void>>[];
  final _captures = <Completer<bool>>[];

  Future<void> readyAt(int index) {
    while (_ready.length <= index) {
      _ready.add(Completer<void>());
    }
    return _ready[index].future;
  }

  @override
  Future<void> cancel() async {
    for (final capture in _captures) {
      if (!capture.isCompleted) {
        capture.complete(false);
      }
    }
  }

  @override
  Future<bool> streamUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  }) {
    final index = _captures.length;
    while (_ready.length <= index) {
      _ready.add(Completer<void>());
    }
    final capture = Completer<bool>();
    _captures.add(capture);
    onReady();
    if (!_ready[index].isCompleted) {
      _ready[index].complete();
    }
    return capture.future;
  }
}

class _ScriptedStreamingAudioCaptureService
    implements StreamingAudioCaptureService {
  final _ready = <Completer<void>>[];
  final _captures = <Completer<bool>>[];

  Future<void> readyAt(int index) {
    while (_ready.length <= index) {
      _ready.add(Completer<void>());
    }
    return _ready[index].future;
  }

  void finishCurrentWithSpeech() {
    if (_captures.isEmpty) {
      return;
    }
    final capture = _captures.last;
    if (!capture.isCompleted) {
      capture.complete(true);
    }
  }

  @override
  Future<void> cancel() async {
    for (final capture in _captures) {
      if (!capture.isCompleted) {
        capture.complete(false);
      }
    }
  }

  @override
  Future<bool> streamUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  }) {
    final index = _captures.length;
    while (_ready.length <= index) {
      _ready.add(Completer<void>());
    }
    final capture = Completer<bool>();
    _captures.add(capture);
    onReady();
    if (!_ready[index].isCompleted) {
      _ready[index].complete();
    }
    return capture.future;
  }
}

class _ControlledAudioPlaybackService implements AudioPlaybackService {
  final playStarted = Completer<void>();
  AudioPlaybackCompleteCallback? _onComplete;
  var stopCount = 0;

  @override
  Future<void> pause() async {}

  @override
  Future<void> playBase64Audio(
    String audioBase64, {
    required String contentType,
    required AudioPlaybackCompleteCallback onComplete,
    required AudioPlaybackErrorCallback onError,
  }) async {
    _onComplete = onComplete;
    if (!playStarted.isCompleted) {
      playStarted.complete();
    }
  }

  void complete() {
    final onComplete = _onComplete;
    _onComplete = null;
    onComplete?.call();
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeStreamingVoiceApi extends StreamingVoiceApi {
  _FakeStreamingVoiceApi() : super(baseUrl: 'http://localhost');

  final socket = _FakeVoiceWebSocket();

  @override
  Future<StreamingVoiceSession> connect({
    String? conversationId,
    String inputMimeType = 'audio/linear16',
    int sampleRate = 16000,
    Map<String, dynamic>? financialContext,
  }) async {
    return StreamingVoiceSession(socket);
  }
}

class _FakeVoiceWebSocket implements VoiceWebSocket {
  final _events = StreamController<dynamic>.broadcast();
  final sentEvents = <String>[];

  @override
  Stream<dynamic> get stream => _events.stream;

  void emit(Map<String, dynamic> event) {
    _events.add(jsonEncode(event));
  }

  @override
  void add(dynamic data) {
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        sentEvents.add(decoded['event'] as String? ?? '');
      }
    } else if (data is Uint8List) {
      sentEvents.add('audio.chunk');
    }
  }

  @override
  Future<void> close() async {
    await _events.close();
  }
}
