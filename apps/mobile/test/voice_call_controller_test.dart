import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:clarity/features/assistant/voice/application/voice_call_controller.dart';
import 'package:clarity/features/assistant/voice/application/voice_controller.dart';
import 'package:clarity/features/assistant/voice/data/audio_capture_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_playback_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_recording_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_session_service.dart';
import 'package:clarity/features/assistant/voice/data/background_voice_service.dart';
import 'package:clarity/features/assistant/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/features/assistant/voice/data/streaming_voice_api.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'streaming voice force-endpoints after speech starts but no final event',
    () async {
      final captureService = _HangingStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final container = ProviderContainer(
        overrides: [
          microphonePermissionProvider.overrideWithValue(
            const _GrantedMicrophonePermissionService(),
          ),
          voiceAudioSessionServiceProvider.overrideWithValue(
            const _NoopVoiceAudioSessionService(),
          ),
          backgroundVoiceServiceProvider.overrideWithValue(
            const _NoopBackgroundVoiceService(),
          ),
          audioCaptureServiceProvider.overrideWithValue(
            const _NoopAudioCaptureService(),
          ),
          audioPlaybackServiceProvider.overrideWithValue(
            const _NoopAudioPlaybackService(),
          ),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(streamingApi),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          voiceCallSpeechStartTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.started.future;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(streamingApi.socket.sentEvents, contains('utterance.end'));
      expect(captureService.cancelled, isTrue);
    },
  );

  test(
    'streaming voice fails instead of hanging when no speech arrives',
    () async {
      final captureService = _SilentStreamingAudioCaptureService();
      final container = ProviderContainer(
        overrides: [
          microphonePermissionProvider.overrideWithValue(
            const _GrantedMicrophonePermissionService(),
          ),
          voiceAudioSessionServiceProvider.overrideWithValue(
            const _NoopVoiceAudioSessionService(),
          ),
          backgroundVoiceServiceProvider.overrideWithValue(
            const _NoopBackgroundVoiceService(),
          ),
          audioCaptureServiceProvider.overrideWithValue(
            const _NoopAudioCaptureService(),
          ),
          audioPlaybackServiceProvider.overrideWithValue(
            const _NoopAudioPlaybackService(),
          ),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(_FakeStreamingVoiceApi()),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          voiceCallNoSpeechTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
          voiceCallEmptyTurnLimitProvider.overrideWithValue(1),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.ready.future;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.failed);
      expect(state.errorMessage, contains('did not catch any audio'));
      expect(state.currentTranscript, isEmpty);
      expect(captureService.cancelled, isTrue);
    },
  );

  test(
    'silence after assistant response keeps call listening without error',
    () async {
      final captureService = _ReusableSilentStreamingAudioCaptureService();
      final container = ProviderContainer(
        overrides: [
          microphonePermissionProvider.overrideWithValue(
            const _GrantedMicrophonePermissionService(),
          ),
          voiceAudioSessionServiceProvider.overrideWithValue(
            const _NoopVoiceAudioSessionService(),
          ),
          backgroundVoiceServiceProvider.overrideWithValue(
            const _NoopBackgroundVoiceService(),
          ),
          audioCaptureServiceProvider.overrideWithValue(
            const _NoopAudioCaptureService(),
          ),
          audioPlaybackServiceProvider.overrideWithValue(
            const _NoopAudioPlaybackService(),
          ),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(_FakeStreamingVoiceApi()),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          voiceCallNoSpeechTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
          voiceCallEmptyTurnLimitProvider.overrideWithValue(1),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      controller.startSpeaking('Rex response.');
      controller.completeSpeaking();
      await captureService.readyAt(1);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
      expect(state.currentTranscript, isEmpty);
    },
  );
}

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

class _SilentStreamingAudioCaptureService
    implements StreamingAudioCaptureService {
  final ready = Completer<void>();
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
    if (!ready.isCompleted) {
      ready.complete();
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
