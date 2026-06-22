import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/data/audio_capture_service.dart';
import 'package:clarity/rex/voice/data/audio_playback_service.dart';
import 'package:clarity/rex/voice/data/audio_recording_service.dart';
import 'package:clarity/rex/voice/data/audio_session_service.dart';
import 'package:clarity/rex/voice/data/background_voice_service.dart';
import 'package:clarity/rex/voice/data/cloud_voice_api.dart';
import 'package:clarity/rex/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/rex/voice/data/streaming_voice_api.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'voice_call_controller_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'voice endpoint detector keeps short pauses inside long speech open',
    () {
      const config = VoiceCaptureConfig();
      expect(config.silenceAfterSpeech, const Duration(milliseconds: 3200));
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
        now: startedAt.add(const Duration(milliseconds: 2500)),
      );
      expect(shortPause.endpointReached, isFalse);

      final resumedSpeech = detector.addAmplitude(
        currentDb: -43,
        now: startedAt.add(const Duration(milliseconds: 2600)),
      );
      expect(resumedSpeech.endpointReached, isFalse);

      final secondShortPause = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 5100)),
      );
      expect(secondShortPause.endpointReached, isFalse);

      final realEndpoint = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 5700)),
      );
      expect(realEndpoint.endpointReached, isFalse);

      final longerPauseEndpoint = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 5900)),
      );
      expect(longerPauseEndpoint.endpointReached, isTrue);
    },
  );

  test('voice endpoint detector allows long speech with natural pauses', () {
    const config = VoiceCaptureConfig();
    final startedAt = DateTime(2026);
    final detector = VoiceEndpointDetector(
      config: config,
      startedAt: startedAt,
    );

    expect(
      detector.addAmplitude(currentDb: -42, now: startedAt).endpointReached,
      isFalse,
    );

    for (var second = 2; second <= 36; second += 4) {
      expect(
        detector
            .addAmplitude(
              currentDb: -80,
              now: startedAt.add(Duration(seconds: second)),
            )
            .endpointReached,
        isFalse,
      );
      expect(
        detector
            .addAmplitude(
              currentDb: -43,
              now: startedAt.add(Duration(seconds: second, milliseconds: 2500)),
            )
            .endpointReached,
        isFalse,
      );
    }

    final endpoint = detector.addAmplitude(
      currentDb: -80,
      now: startedAt.add(const Duration(seconds: 42)),
    );
    expect(endpoint.endpointReached, isTrue);
  });

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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
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
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        hasLength(1),
      );
      expect(captureService.cancelled, isTrue);
    },
  );

  test('unexpected streaming socket close fails instead of hanging', () async {
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
        streamingAudioCaptureServiceProvider.overrideWithValue(captureService),
        bargeInDetectionServiceProvider.overrideWithValue(
          const _NoopBargeInDetectionService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceCallProvider.notifier);

    expect(await controller.startCall(), isTrue);
    await captureService.readyAt(0);

    await streamingApi.socket.closeFromServer();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(voiceCallProvider);
    expect(state.phase, VoiceCallPhase.failed);
    expect(state.errorMessage, contains('disconnected'));
  });

  test(
    'streaming voice keeps listening quietly when no speech arrives',
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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          voiceCallNoSpeechTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);
      await captureService.readyAt(1);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
      expect(state.currentTranscript, isEmpty);
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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          voiceCallNoSpeechTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
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

  test('voice defaults are tuned for interruptible walking playback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(voiceCallBargeInEnabledProvider), isTrue);
    expect(
      container.read(voiceCallTranscriptIdleTimeoutProvider),
      const Duration(seconds: 5),
    );
    expect(
      container.read(voiceCallNoSpeechTimeoutProvider),
      const Duration(seconds: 24),
    );
    expect(
      container.read(voiceCallThinkingTimeoutProvider),
      const Duration(seconds: 30),
    );
  });

  testWidgets('inline voice panel has no manual interrupt button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineVoiceCallPanel(
            state: VoiceCallState(
              phase: VoiceCallPhase.speaking,
              callStartedAt: DateTime(2026),
            ),
            onRetry: () {},
            onEnd: () {},
            onToggleMute: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.front_hand_rounded), findsNothing);
    expect(find.text('You can interrupt by speaking.'), findsOneWidget);
  });

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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
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
      streamingApi.socket.emit({
        'event': 'messages.updated',
        'conversation_id': 'conversation-voice',
        'messages': [
          {
            'id': 'user-message-1',
            'conversation_id': 'conversation-voice',
            'role': 'user',
            'content': 'Plan my launch week',
            'timestamp': '2026-06-01T12:00:00Z',
          },
          {
            'id': 'assistant-message-1',
            'conversation_id': 'conversation-voice',
            'role': 'assistant',
            'content': 'Use weekly launch plans.',
            'timestamp': '2026-06-01T12:00:01Z',
          },
        ],
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(chatProvider).conversationId, 'conversation-voice');
      expect(container.read(chatProvider).messages.length, 2);

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
      expect(streamingApi.connectCount, 1);
      expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
      expect(streamingApi.socket.closeCount, 0);
    },
  );

  test(
    'streaming speech-final transcript closes the utterance for backend processing',
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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hey. How are you doing?',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        hasLength(1),
      );

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Hey. How are you doing?',
      });
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hey. How are you doing?',
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        hasLength(1),
      );
    },
  );

  test('barge-in does not start while Rex is thinking', () async {
    final captureService = _ScriptedStreamingAudioCaptureService();
    final streamingApi = _FakeStreamingVoiceApi();
    final bargeInService = _ControlledBargeInDetectionService();
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
        streamingAudioCaptureServiceProvider.overrideWithValue(captureService),
        bargeInDetectionServiceProvider.overrideWithValue(bargeInService),
        voiceCallBargeInEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceCallProvider.notifier);

    expect(await controller.startCall(), isTrue);
    await captureService.readyAt(0);

    controller.startThinking(finalTranscript: 'Tell me about my day.');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(voiceCallProvider);
    expect(state.phase, VoiceCallPhase.thinking);
    expect(bargeInService.started.isCompleted, isFalse);
    expect(streamingApi.socket.sentEvents, isNot(contains('user.interrupt')));
    expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
    expect(streamingApi.connectCount, 1);
    expect(streamingApi.socket.closeCount, 0);
    expect(bargeInService.stopCount, 0);
  });

  test(
    'streaming empty audio error restarts listening instead of failing call',
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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'error',
        'code': 'empty_audio',
        'detail': 'I did not catch any audio.',
      });
      await captureService.readyAt(1);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
      expect(streamingApi.socket.sentEvents, contains('user.interrupt'));
      expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
      expect(streamingApi.socket.closeCount, 0);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);
      expect(streamingApi.socket.sentEvents, contains('utterance.end'));

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hello again',
        'speech_final': true,
      });
      streamingApi.socket.emit({'event': 'assistant.started'});
      streamingApi.socket.emit({
        'event': 'assistant.token',
        'token': 'Back online.',
      });
      streamingApi.socket.emit({
        'event': 'assistant.audio_chunk',
        'audio_base64': base64Encode([1, 2, 3]),
        'audio_content_type': 'audio/mpeg',
        'text': 'Back online.',
      });
      streamingApi.socket.emit({
        'event': 'assistant.done',
        'conversation_id': 'conversation-voice',
        'response_text': 'Back online.',
      });
      await captureService.readyAt(2).timeout(const Duration(seconds: 1));

      final recoveredState = container.read(voiceCallProvider);
      expect(recoveredState.phase, VoiceCallPhase.listening);
      expect(recoveredState.lastAssistantResponse, 'Back online.');
      expect(streamingApi.connectCount, 1);
      expect(streamingApi.socket.closeCount, 0);
    },
  );

  test('barge-in interrupts speaking and returns to listening', () async {
    final captureService = _ScriptedStreamingAudioCaptureService();
    final playbackService = _ControlledAudioPlaybackService();
    final bargeInService = _ControlledBargeInDetectionService();
    final cloudVoiceApi = _FakeCloudVoiceApi();
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
        audioPlaybackServiceProvider.overrideWithValue(playbackService),
        streamingVoiceEnabledProvider.overrideWithValue(true),
        nativeIosVoiceEnabledProvider.overrideWithValue(false),
        streamingVoiceApiProvider.overrideWithValue(streamingApi),
        streamingAudioCaptureServiceProvider.overrideWithValue(captureService),
        bargeInDetectionServiceProvider.overrideWithValue(bargeInService),
        voiceCallBargeInEnabledProvider.overrideWithValue(true),
        cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceCallProvider.notifier);

    expect(await controller.startCall(), isTrue);
    await captureService.readyAt(0);

    unawaited(
      controller.speakTypedAssistantResponse('Rex is still answering.'),
    );
    await playbackService.playStarted.future;
    await bargeInService.started.future;
    final preRollChunk = Uint8List.fromList([5, 4, 3]);
    bargeInService.trigger([preRollChunk]);
    await captureService.readyAt(1);

    final state = container.read(voiceCallProvider);
    expect(state.phase, VoiceCallPhase.listening);
    expect(streamingApi.socket.sentEvents, contains('user.interrupt'));
    expect(streamingApi.socket.sentEvents, contains('audio.chunk'));
    expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
    expect(streamingApi.socket.sentAudioChunks.single, preRollChunk);
    expect(streamingApi.connectCount, 1);
    expect(streamingApi.socket.closeCount, 0);
    expect(playbackService.stopCount, greaterThanOrEqualTo(1));
    expect(bargeInService.stopCount, 1);
  });

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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
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
      final captureService = _ReusableSilentStreamingAudioCaptureService();
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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          voiceCallNoSpeechTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);
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
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
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

  test(
    'typed reply during active voice synthesizes audio and returns to listening',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final playbackService = _ControlledAudioPlaybackService();
      final audioSessionService = _CountingVoiceAudioSessionService();
      final cloudVoiceApi = _FakeCloudVoiceApi();
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
          streamingVoiceApiProvider.overrideWithValue(_FakeStreamingVoiceApi()),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      controller.beginTypedTextTurn('Typed while voice is open.');
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        container.read(voiceCallProvider).currentTranscript,
        'Typed while voice is open.',
      );

      final speak = controller.speakTypedAssistantResponse(
        'Spoken typed reply.',
      );
      await playbackService.playStarted.future;

      expect(cloudVoiceApi.synthesizedTexts, ['Spoken typed reply.']);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(
        container.read(voiceCallProvider).lastAssistantResponse,
        'Spoken typed reply.',
      );
      expect(audioSessionService.preferLoudSpeakerCount, 1);

      playbackService.complete();
      await speak;
      await captureService.readyAt(1);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
    },
  );

  test('typed reply during muted voice skips audio playback', () async {
    final captureService = _ScriptedStreamingAudioCaptureService();
    final playbackService = _ControlledAudioPlaybackService();
    final cloudVoiceApi = _FakeCloudVoiceApi();
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
        audioPlaybackServiceProvider.overrideWithValue(playbackService),
        streamingVoiceEnabledProvider.overrideWithValue(true),
        nativeIosVoiceEnabledProvider.overrideWithValue(false),
        streamingVoiceApiProvider.overrideWithValue(_FakeStreamingVoiceApi()),
        streamingAudioCaptureServiceProvider.overrideWithValue(captureService),
        bargeInDetectionServiceProvider.overrideWithValue(
          const _NoopBargeInDetectionService(),
        ),
        cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceCallProvider.notifier);

    expect(await controller.startCall(), isTrue);
    await captureService.readyAt(0);
    controller.setMuted(true);

    controller.beginTypedTextTurn('Typed while muted.');
    await controller.speakTypedAssistantResponse('Silent typed reply.');

    final state = container.read(voiceCallProvider);
    expect(state.phase, VoiceCallPhase.listening);
    expect(state.isMuted, isTrue);
    expect(state.lastAssistantResponse, 'Silent typed reply.');
    expect(cloudVoiceApi.synthesizedTexts, isEmpty);
    expect(playbackService.playStarted.isCompleted, isFalse);
  });
}
