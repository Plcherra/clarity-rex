import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:clarity/features/assistant/voice/application/voice_call_controller.dart';
import 'package:clarity/features/assistant/voice/data/audio_capture_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_playback_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_recording_service.dart';
import 'package:clarity/features/assistant/voice/data/audio_session_service.dart';
import 'package:clarity/features/assistant/voice/data/background_voice_service.dart';
import 'package:clarity/features/assistant/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/features/assistant/voice/data/streaming_voice_api.dart';
import 'package:clarity/features/assistant/voice/domain/voice_call_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'voice_call_controller_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'voice endpoint detector keeps short pauses inside long speech open',
    () {
      const config = VoiceCaptureConfig();
      expect(config.silenceAfterSpeech, const Duration(milliseconds: 2100));
      expect(config.maxUtteranceDuration, const Duration(seconds: 120));

      final startedAt = DateTime(2026);
      final detector = VoiceEndpointDetector(
        config: config,
        startedAt: startedAt,
      );

      final speechStart = detector.addAmplitude(currentDb: -42, now: startedAt);
      expect(speechStart.speechStarted, isTrue);
      expect(speechStart.endpointReached, isFalse);

      final shortPause = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 1800)),
      );
      expect(shortPause.endpointReached, isFalse);

      final resumedSpeech = detector.addAmplitude(
        currentDb: -43,
        now: startedAt.add(const Duration(milliseconds: 1900)),
      );
      expect(resumedSpeech.endpointReached, isFalse);

      final secondShortPause = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 3700)),
      );
      expect(secondShortPause.endpointReached, isFalse);

      final realEndpoint = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 4100)),
      );
      expect(realEndpoint.endpointReached, isTrue);
    },
  );

  test('voice audio session asks native iOS to prefer loud speaker', () async {
    const channel = MethodChannel('clarity/voice_audio');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await PackageVoiceAudioSessionService(
      voiceAudioChannel: channel,
    ).preferLoudSpeaker();

    expect(calls, ['preferLoudSpeaker']);
  });

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

  test(
    'streaming voice waits for playback before returning to listening',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
      final audioSessionService = _CountingVoiceAudioSessionService();
      final container = ProviderContainer(
        overrides: [
          microphonePermissionProvider.overrideWithValue(
            const _GrantedMicrophonePermissionService(),
          ),
          voiceAudioSessionServiceProvider.overrideWithValue(
            audioSessionService,
          ),
          backgroundVoiceServiceProvider.overrideWithValue(
            const _NoopBackgroundVoiceService(),
          ),
          audioCaptureServiceProvider.overrideWithValue(
            const _NoopAudioCaptureService(),
          ),
          audioPlaybackServiceProvider.overrideWithValue(playbackService),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(streamingApi),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      captureService.finishCurrentWithSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Plan my launch week',
        'speech_final': true,
      });
      streamingApi.socket.emit({'event': 'assistant.started'});
      streamingApi.socket.emit({
        'event': 'assistant.token',
        'token': 'Use weekly launch plans.',
      });
      streamingApi.socket.emit({
        'event': 'assistant.audio_chunk',
        'audio_base64': base64Encode([1, 2, 3]),
        'audio_content_type': 'audio/mpeg',
        'text': 'Use weekly launch plans.',
      });

      await playbackService.playStarted.future;
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(
        audioSessionService.preferLoudSpeakerCount,
        greaterThanOrEqualTo(1),
      );

      streamingApi.socket.emit({
        'event': 'assistant.done',
        'conversation_id': 'conversation-voice',
        'response_text': 'Use weekly launch plans.',
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);

      playbackService.complete();
      await captureService.readyAt(1);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
      expect(state.lastAssistantResponse, 'Use weekly launch plans.');
      expect(playbackService.stopCount, 0);
    },
  );

  test(
    'streaming transcript does not duplicate partial and final text',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
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
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript':
            "It's next week, but on the eighteenth, it's my mom's birthday",
      });
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript':
            "It's next week, but on the eighteenth, it's my mom's birthday. "
            "It's next week, but on the eighteenth, it's my mom's birthday.",
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(voiceCallProvider);
      expect(
        state.currentTranscript,
        "It's next week, but on the eighteenth, it's my mom's birthday.",
      );
      expect(
        RegExp(
          "mom's birthday",
          caseSensitive: false,
        ).allMatches(state.currentTranscript).length,
        1,
      );
    },
  );

  test(
    'inactive lifecycle keeps audio route stable and suppresses no-speech fail',
    () async {
      final captureService = _SilentStreamingAudioCaptureService();
      final audioSessionService = _CountingVoiceAudioSessionService();
      final backgroundVoiceService = _CountingBackgroundVoiceService();
      final container = ProviderContainer(
        overrides: [
          microphonePermissionProvider.overrideWithValue(
            const _GrantedMicrophonePermissionService(),
          ),
          voiceAudioSessionServiceProvider.overrideWithValue(
            audioSessionService,
          ),
          backgroundVoiceServiceProvider.overrideWithValue(
            backgroundVoiceService,
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
      expect(audioSessionService.configureCount, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
      expect(audioSessionService.configureCount, 1);
      expect(backgroundVoiceService.startCount, 1);
    },
  );

  test(
    'turn-in-progress stream error keeps the voice call recoverable',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
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
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'error',
        'code': 'turn_in_progress',
        'detail': 'Rex is still answering the previous voice turn.',
      });
      await Future<void>.delayed(Duration.zero);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, contains('previous response'));
    },
  );
}
