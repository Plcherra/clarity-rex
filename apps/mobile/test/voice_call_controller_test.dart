import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:clarity/features/assistant/voice/application/voice_call_controller.dart';
import 'package:clarity/features/assistant/voice/application/voice_controller.dart';
import 'package:clarity/features/assistant/voice/data/audio_capture_service.dart';
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
    required SpeechStartCallback onSpeechStart,
    required SpeechEndCallback onSpeechEnded,
    required AudioChunkCallback onAudioChunk,
  }) {
    onSpeechStart();
    if (!started.isCompleted) {
      started.complete();
    }
    return _capture.future;
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
