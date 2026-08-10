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
    bool continueSession = false,
  }) async {
    onComplete();
  }

  @override
  Future<void> stop() async {}
}

class _NoopStreamingAudioCaptureService implements StreamingAudioCaptureService {
  const _NoopStreamingAudioCaptureService();

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> streamUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  }) async {
    return false;
  }
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
    // Do not auto-start VAD speech — idle-endpoint tests need STT-only turns
    // while the capture future stays open.
    onReady();
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
  var startCount = 0;
  var cancelCount = 0;

  Future<void> readyAt(int index) {
    while (_ready.length <= index) {
      _ready.add(Completer<void>());
    }
    return _ready[index].future;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
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
    startCount++;
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
  SpeechStartCallback? _lastOnSpeechStart;
  SpeechEndCallback? _lastOnSpeechEnded;

  Future<void> readyAt(int index) {
    while (_ready.length <= index) {
      _ready.add(Completer<void>());
    }
    return _ready[index].future;
  }

  void startCurrentSpeech() {
    _lastOnSpeechStart?.call();
  }

  void finishCurrentWithSpeech() {
    if (_captures.isEmpty) {
      return;
    }
    final capture = _captures.last;
    if (capture.isCompleted) {
      return;
    }
    _lastOnSpeechStart?.call();
    _lastOnSpeechEnded?.call();
    if (!capture.isCompleted) {
      capture.complete(true);
    }
  }

  /// Ends capture as empty (e.g. audio-session interrupt) without speech_end.
  void finishCurrentWithoutSpeech() {
    if (_captures.isEmpty) {
      return;
    }
    final capture = _captures.last;
    if (capture.isCompleted) {
      return;
    }
    capture.complete(false);
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
    _lastOnSpeechStart = onSpeechStart;
    _lastOnSpeechEnded = onSpeechEnded;
    if (!_ready[index].isCompleted) {
      _ready[index].complete();
    }
    return capture.future;
  }
}

class _ControlledAudioPlaybackService implements AudioPlaybackService {
  Completer<void> playStarted = Completer<void>();
  AudioPlaybackCompleteCallback? _onComplete;
  var stopCount = 0;
  var playCount = 0;

  @override
  Future<void> pause() async {}

  @override
  Future<void> playBase64Audio(
    String audioBase64, {
    required String contentType,
    required AudioPlaybackCompleteCallback onComplete,
    required AudioPlaybackErrorCallback onError,
    bool continueSession = false,
  }) async {
    playCount++;
    _onComplete = onComplete;
    if (!playStarted.isCompleted) {
      playStarted.complete();
    }
  }

  void armNextPlay() {
    playStarted = Completer<void>();
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

class _NoopBargeInDetectionService implements BargeInDetectionService {
  const _NoopBargeInDetectionService();

  @override
  Future<void> start({
    required VoiceCaptureConfig config,
    required BargeInCallback onBargeIn,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _ControlledBargeInDetectionService implements BargeInDetectionService {
  final started = Completer<void>();
  BargeInCallback? _onBargeIn;
  var stopCount = 0;

  @override
  Future<void> start({
    required VoiceCaptureConfig config,
    required BargeInCallback onBargeIn,
  }) async {
    _onBargeIn = onBargeIn;
    if (!started.isCompleted) {
      started.complete();
    }
  }

  void trigger([List<Uint8List> audioChunks = const []]) {
    _onBargeIn?.call(audioChunks);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _onBargeIn = null;
  }
}

class _RecordingChatApi extends ChatApi {
  _RecordingChatApi({
    this.responseText = 'Chat fallback reply.',
    this.conversationId = 'conversation-chat-fallback',
  }) : super(baseUrl: 'http://localhost');

  final String responseText;
  final String conversationId;
  final sentMessages = <String>[];

  @override
  Future<ChatApiResponse> sendMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    sentMessages.add(message);
    final resolvedConversationId = conversationId ?? this.conversationId;
    return ChatApiResponse(
      conversationId: resolvedConversationId,
      response: responseText,
      messages: [
        ChatApiMessage(
          id: 'user-1',
          conversationId: resolvedConversationId,
          role: 'user',
          content: message,
          timestamp: DateTime(2026),
        ),
        ChatApiMessage(
          id: 'assistant-1',
          conversationId: resolvedConversationId,
          role: 'assistant',
          content: responseText,
          timestamp: DateTime(2026),
        ),
      ],
    );
  }
}

class _FailingChatApi extends ChatApi {
  _FailingChatApi() : super(baseUrl: 'http://localhost');

  @override
  Future<ChatApiResponse> sendMessage(
    String message, {
    String? conversationId,
    XFile? attachment,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    throw Exception('chat_fallback_unavailable');
  }
}

class _FakeCloudVoiceApi extends CloudVoiceApi {
  _FakeCloudVoiceApi() : super(baseUrl: 'http://localhost');

  final synthesizedTexts = <String>[];
  final voiceTurns = <RecordedVoiceAudio>[];
  var voiceTurnCount = 0;
  Map<String, dynamic>? lastWriteConfirmation;

  @override
  Future<CloudVoiceSynthesisResponse> synthesize(String text) async {
    synthesizedTexts.add(text);
    return CloudVoiceSynthesisResponse(
      audioContentType: 'audio/mpeg',
      audioBase64: base64Encode([1, 2, 3]),
      audioEncoding: 'mp3',
      voiceName: 'test-voice',
      languageCode: 'en-US',
    );
  }

  @override
  Future<CloudVoiceTurnResponse> sendVoiceTurn({
    required XFile audio,
    required String inputMimeType,
    String? conversationId,
    Map<String, dynamic>? financialContext,
    Map<String, dynamic>? writeConfirmation,
  }) async {
    voiceTurnCount++;
    lastWriteConfirmation = writeConfirmation;
    voiceTurns.add(
      RecordedVoiceAudio(
        file: audio,
        inputMimeType: inputMimeType,
      ),
    );
    return CloudVoiceTurnResponse(
      conversationId: conversationId ?? 'conversation-rest-fallback',
      transcript: 'Hello from REST fallback',
      responseText: 'REST fallback reply',
      audioContentType: 'audio/mpeg',
      audioBase64: base64Encode([1, 2, 3]),
      audioEncoding: 'mp3',
      voiceName: 'test-voice',
      languageCode: 'en-US',
    );
  }
}

class _FailingCloudVoiceApi extends CloudVoiceApi {
  _FailingCloudVoiceApi() : super(baseUrl: 'http://localhost');

  @override
  Future<CloudVoiceSynthesisResponse> synthesize(String text) async {
    throw CloudVoiceApiException('Synthesis unavailable.');
  }
}

class _RecordingAudioCaptureService implements AudioCaptureService {
  var captureCount = 0;

  @override
  Future<void> cancel() async {}

  @override
  Future<RecordedVoiceAudio?> captureUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
  }) async {
    captureCount++;
    onReady();
    onSpeechStart();
    return RecordedVoiceAudio(
      file: XFile.fromData(
        Uint8List.fromList([1, 2, 3, 4]),
        name: 'rex-voice-call.pcm',
        mimeType: 'audio/pcm',
      ),
      inputMimeType: 'audio/linear16',
    );
  }
}

class _FailingStreamingVoiceApi extends StreamingVoiceApi {
  _FailingStreamingVoiceApi() : super(baseUrl: 'http://localhost');

  @override
  Future<StreamingVoiceSession> connect({
    String? conversationId,
    String inputMimeType = 'audio/linear16',
    int sampleRate = 16000,
    String client = 'flutter_streaming',
    Map<String, dynamic>? financialContext,
  }) async {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
}

/// REST mic capture that can return empty after the test plants a transcript.
class _EmptyAfterReadyAudioCaptureService implements AudioCaptureService {
  final _ready = <Completer<void>>[];
  final _finish = <Completer<RecordedVoiceAudio?>>[];

  Future<void> readyAt(int index) async {
    while (_ready.length <= index) {
      await Future<void>.delayed(Duration.zero);
    }
    await _ready[index].future;
  }

  void finishEmptyAt(int index) {
    final completer = _finish[index];
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  @override
  Future<void> cancel() async {
    for (final completer in _finish) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
  }

  @override
  Future<RecordedVoiceAudio?> captureUtterance({
    required VoiceCaptureConfig config,
    required CaptureReadyCallback onReady,
    required SpeechStartCallback onSpeechStart,
  }) async {
    final ready = Completer<void>();
    final finish = Completer<RecordedVoiceAudio?>();
    _ready.add(ready);
    _finish.add(finish);
    onReady();
    onSpeechStart();
    ready.complete();
    return finish.future;
  }
}

class _FakeStreamingVoiceApi extends StreamingVoiceApi {
  _FakeStreamingVoiceApi() : super(baseUrl: 'http://localhost');

  final sockets = <_FakeVoiceWebSocket>[];
  var connectCount = 0;

  _FakeVoiceWebSocket get socket {
    if (sockets.isEmpty) {
      sockets.add(_FakeVoiceWebSocket());
    }
    return sockets.last;
  }

  @override
  Future<StreamingVoiceSession> connect({
    String? conversationId,
    String inputMimeType = 'audio/linear16',
    int sampleRate = 16000,
    String client = 'flutter_streaming',
    Map<String, dynamic>? financialContext,
  }) async {
    connectCount++;
    if (sockets.isEmpty || sockets.last.isClosed) {
      sockets.add(_FakeVoiceWebSocket());
    }
    return StreamingVoiceSession(socket);
  }
}

class _FakeVoiceWebSocket implements VoiceWebSocket {
  final _events = StreamController<dynamic>.broadcast();
  final sentEvents = <String>[];
  final sentPayloads = <Map<String, dynamic>>[];
  final sentAudioChunks = <Uint8List>[];
  var closeCount = 0;

  bool get isClosed => _events.isClosed;

  @override
  Stream<dynamic> get stream => _events.stream;

  void emit(Map<String, dynamic> event) {
    _events.add(jsonEncode(event));
  }

  Future<void> closeFromServer() async {
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  @override
  void add(dynamic data) {
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        sentEvents.add(decoded['event'] as String? ?? '');
        sentPayloads.add(Map<String, dynamic>.from(decoded));
      }
    } else if (data is Uint8List) {
      sentEvents.add('audio.chunk');
      sentAudioChunks.add(Uint8List.fromList(data));
    }
  }

  @override
  Future<void> close() async {
    closeCount++;
    if (!_events.isClosed) {
      await _events.close();
    }
  }
}
