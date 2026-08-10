import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:cross_file/cross_file.dart';
import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/network/device_connectivity.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/voice/application/voice_call_controller.dart';
import 'package:clarity/rex/voice/data/audio_capture_service.dart';
import 'package:clarity/rex/voice/data/audio_playback_service.dart';
import 'package:clarity/rex/voice/data/audio_session_service.dart';
import 'package:clarity/rex/voice/data/background_voice_service.dart';
import 'package:clarity/rex/voice/data/cloud_voice_api.dart';
import 'package:clarity/rex/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/rex/voice/data/streaming_voice_api.dart';
import 'package:clarity/rex/voice/domain/streaming_capture_end_kind.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/rex/chat/presentation/widgets/inline_voice_call_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/l10n_test_wrapper.dart';

part 'voice_call_controller_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    // Avoid DNS preflight on every startCall in unit tests (A23).
    debugDeviceOnlineCheckOverride = () async => true;
  });
  tearDownAll(() {
    debugDeviceOnlineCheckOverride = null;
  });

  test(
    'voice endpoint detector keeps short pauses inside long speech open',
    () {
      const config = VoiceCaptureConfig();
      expect(config.silenceAfterSpeech, const Duration(milliseconds: 4000));
      expect(config.maxUtteranceDuration, const Duration(seconds: 120));

      final startedAt = DateTime(2026);
      final detector = VoiceEndpointDetector(
        config: config,
        startedAt: startedAt,
      );

      final speechStart = detector.addAmplitude(currentDb: -42, now: startedAt);
      expect(speechStart.speechStarted, isTrue);
      expect(speechStart.endpointReached, isFalse);

      // Soft syllables in the hysteresis band keep the turn open.
      final softSpeech = detector.addAmplitude(
        currentDb: -55,
        now: startedAt.add(const Duration(milliseconds: 800)),
      );
      expect(softSpeech.endpointReached, isFalse);

      final shortPause = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 2800)),
      );
      expect(shortPause.endpointReached, isFalse);

      final resumedSpeech = detector.addAmplitude(
        currentDb: -43,
        now: startedAt.add(const Duration(milliseconds: 2900)),
      );
      expect(resumedSpeech.endpointReached, isFalse);

      final secondShortPause = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 5500)),
      );
      expect(secondShortPause.endpointReached, isFalse);

      final realEndpoint = detector.addAmplitude(
        currentDb: -43,
        now: startedAt.add(const Duration(milliseconds: 5600)),
      );
      expect(realEndpoint.endpointReached, isFalse);

      final longerPauseEndpoint = detector.addAmplitude(
        currentDb: -80,
        now: startedAt.add(const Duration(milliseconds: 9700)),
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

    for (var second = 2; second <= 34; second += 4) {
      expect(
        detector
            .addAmplitude(
              currentDb: -43,
              now: startedAt.add(Duration(seconds: second - 1)),
            )
            .endpointReached,
        isFalse,
      );
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
              now: startedAt.add(Duration(seconds: second, milliseconds: 1500)),
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

  test('CloudVoiceTurnResponse parses memory changes', () {
    final response = CloudVoiceTurnResponse.fromJson({
      'conversation_id': 'conversation-1',
      'transcript': 'Remember my mom birthday',
      'response_text': 'Got it.',
      'audio_content_type': 'audio/mpeg',
      'audio_base64': '',
      'audio_encoding': 'MP3',
      'voice_name': 'test-voice',
      'language_code': 'en-US',
      'memory_changes': {'created': 1},
    });

    expect(response.memoryChanges, {'created': 1});
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
    'startCall aborts offline with chatErrorNetwork before listening',
    () async {
      final previous = debugDeviceOnlineCheckOverride;
      debugDeviceOnlineCheckOverride = () async => false;
      addTearDown(() {
        debugDeviceOnlineCheckOverride = previous;
      });

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
            _HangingStreamingAudioCaptureService(),
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);
      expect(await controller.startCall(), isFalse);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.failed);
      expect(state.errorMessage, lookupEnglishLocalizationsForTests().chatErrorNetwork);
    },
  );

  test(
    'streaming voice keeps listening while capture hangs without local endpoint',
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

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        isEmpty,
      );
      expect(captureService.cancelled, isFalse);
    },
  );

  test(
    'transcript idle without prior VAD must not finalize',
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
          voiceCallTranscriptIdleTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 40),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.started.future;

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Hello Rex how are you',
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // STT idle is not VAD silence — must not masquerade as submit authority.
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        isEmpty,
      );
    },
  );

  test(
    'transcript idle after VAD silence finalizes once',
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
          voiceCallTranscriptIdleTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 40),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(voiceCallProvider.notifier).startCall(),
        isTrue,
      );
      await captureService.started.future;

      // VAD first (empty transcript), then STT arrives and idle completes.
      captureService.notifyVadSilence();
      await Future<void>.delayed(Duration.zero);
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Save my morning routine',
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        hasLength(1),
      );

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Save my morning routine',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        hasLength(1),
      );
    },
  );

  test('unexpected streaming socket close recovers to listening', () async {
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
    expect(state.phase, VoiceCallPhase.listening);
    expect(state.errorMessage, contains('disconnected'));
    expect(state.isCallActive, isTrue);
  });

  test(
    'streaming voice falls back to REST when websocket connect fails',
    () async {
      final captureService = _RecordingAudioCaptureService();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          audioCaptureServiceProvider.overrideWithValue(captureService),
          audioPlaybackServiceProvider.overrideWithValue(playbackService),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          cloudVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(
            _FailingStreamingVoiceApi(),
          ),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            const _NoopStreamingAudioCaptureService(),
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
      await playbackService.playStarted.future;

      expect(captureService.captureCount, 1);
      expect(cloudVoiceApi.voiceTurnCount, 1);
      expect(cloudVoiceApi.voiceTurns.single.inputMimeType, 'audio/linear16');
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
    },
  );

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
    'streaming voice stops auto-retrying after repeated no-speech turns',
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
      await captureService.readyAt(3);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.failed);
      expect(state.errorMessage, contains('Tap Try again'));
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

    expect(container.read(voiceCallBargeInEnabledProvider), isFalse);
    expect(
      container.read(voiceCallTranscriptIdleTimeoutProvider),
      const Duration(milliseconds: 8000),
    );
    expect(
      container.read(voiceCallNoSpeechTimeoutProvider),
      const Duration(seconds: 24),
    );
    expect(
      container.read(voiceCallThinkingTimeoutProvider),
      const Duration(seconds: 90),
    );
  });

  test(
    'streaming voice finalizes on local capture end without speech_final',
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
        'transcript': 'Tell me about my budgets',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
      final endPayload = streamingApi.socket.sentPayloads.firstWhere(
        (payload) => payload['event'] == 'utterance.end',
      );
      expect(endPayload['transcript'], 'Tell me about my budgets');
      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.first.content, 'Tell me about my budgets');
      expect(messages.first.isVoiceInterim, isFalse);
    },
  );

  test(
    'streaming empty_audio with known transcript completes via chat fallback',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final chatApi = _RecordingChatApi();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          chatApiProvider.overrideWithValue(chatApi),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Remember my coffee budget',
      });
      await Future<void>.delayed(Duration.zero);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);

      streamingApi.socket.emit({
        'event': 'error',
        'code': 'empty_audio',
        'detail': 'I did not catch any audio.',
      });
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );

      expect(chatApi.sentMessages, ['Remember my coffee budget']);
      expect(cloudVoiceApi.synthesizedTexts, ['Chat fallback reply.']);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
      expect(streamingApi.socket.sentEvents, isNot(contains('user.interrupt')));
    },
  );

  test(
    'soft recover with known transcript completes via chat instead of wiping',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final chatApi = _RecordingChatApi();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          chatApiProvider.overrideWithValue(chatApi),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Buy milk tomorrow',
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(voiceCallProvider).currentTranscript,
        'Buy milk tomorrow',
      );

      // Capture ends without finalize (e.g. music/audio-session interrupt) —
      // must not clear the transcript and restart listening.
      captureService.finishCurrentWithoutSpeech();
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );

      expect(chatApi.sentMessages, ['Buy milk tomorrow']);
      expect(cloudVoiceApi.synthesizedTexts, ['Chat fallback reply.']);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(container.read(chatProvider).messages, isNotEmpty);
      expect(
        container
            .read(chatProvider)
            .messages
            .where((m) => m.role == ChatMessageRole.user)
            .length,
        1,
      );
    },
  );

  test(
    'cloud-fallback soft-recover still chats on the second listen epoch',
    () async {
      // Mirrors prod when WS never hits uvicorn: connect fails → REST mic →
      // empty capture with a known transcript → chat+TTS. Turn sequence stays
      // unused; listen-epoch gating must allow the second utterance.
      final captureService = _EmptyAfterReadyAudioCaptureService();
      final chatApi = _RecordingChatApi();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          audioCaptureServiceProvider.overrideWithValue(captureService),
          audioPlaybackServiceProvider.overrideWithValue(playbackService),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(
            _FailingStreamingVoiceApi(),
          ),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            const _NoopStreamingAudioCaptureService(),
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          chatApiProvider.overrideWithValue(chatApi),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);
      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);
      controller.updateTranscript('First cloud turn');
      captureService.finishEmptyAt(0);
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );
      expect(chatApi.sentMessages, ['First cloud turn']);

      playbackService.armNextPlay();
      playbackService.complete();
      await Future<void>.delayed(Duration.zero);
      await captureService.readyAt(1);
      controller.updateTranscript('Second cloud turn');
      captureService.finishEmptyAt(1);
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );

      expect(chatApi.sentMessages, ['First cloud turn', 'Second cloud turn']);
      expect(cloudVoiceApi.synthesizedTexts.length, 2);
    },
  );

  test(
    'second soft-recover after chat fallback still completes via chat',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final chatApi = _RecordingChatApi();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          chatApiProvider.overrideWithValue(chatApi),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'First turn',
      });
      await Future<void>.delayed(Duration.zero);
      // Finalize path sets `_streamingTurnFinalizedSequence`; old chat-fallback
      // gating reused that id and blocked the next turn.
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      streamingApi.socket.emit({
        'event': 'error',
        'code': 'empty_audio',
        'detail': 'I did not catch any audio.',
      });
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );
      expect(chatApi.sentMessages, ['First turn']);
      playbackService.armNextPlay();
      playbackService.complete();
      await Future<void>.delayed(Duration.zero);
      await captureService.readyAt(1);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Second turn',
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(voiceCallProvider).currentTranscript,
        'Second turn',
      );
      captureService.finishCurrentWithoutSpeech();
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );

      expect(chatApi.sentMessages, ['First turn', 'Second turn']);
      expect(cloudVoiceApi.synthesizedTexts.length, 2);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(
        container.read(voiceCallProvider).currentTranscript,
        isNot(equals('Second turn')),
      );
    },
  );

  test(
    'empty_audio chat fallback still works after a prior soft-recover in the call',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final chatApi = _RecordingChatApi();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          bargeInDetectionServiceProvider.overrideWithValue(
            const _NoopBargeInDetectionService(),
          ),
          chatApiProvider.overrideWithValue(chatApi),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      // Prior empty turn soft-recovers and used to poison the shared counter so
      // the next empty_audio with known text soft-recovered again instead of
      // completing via chat+TTS.
      streamingApi.socket.emit({
        'event': 'error',
        'code': 'empty_audio',
        'detail': 'I did not catch any audio.',
      });
      await captureService.readyAt(1);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Wake me at five',
      });
      await Future<void>.delayed(Duration.zero);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);

      streamingApi.socket.emit({
        'event': 'error',
        'code': 'empty_audio',
        'detail': 'I did not catch any audio.',
      });
      await Future<void>.delayed(Duration.zero);
      await playbackService.playStarted.future.timeout(
        const Duration(seconds: 1),
      );

      expect(chatApi.sentMessages, ['Wake me at five']);
      expect(cloudVoiceApi.synthesizedTexts, ['Chat fallback reply.']);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
    },
  );

  test(
    'soft recover after failed chat fallback clears orphan bubble and next speech_final',
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
          chatApiProvider.overrideWithValue(_FailingChatApi()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Save my launch plan',
      });
      await Future<void>.delayed(Duration.zero);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(container.read(chatProvider).messages, hasLength(1));
      expect(
        container.read(chatProvider).messages.first.isVoiceInterim,
        isFalse,
      );

      streamingApi.socket.emit({
        'event': 'error',
        'code': 'empty_audio',
        'detail': 'I did not catch any audio.',
      });
      await captureService.readyAt(1).timeout(const Duration(seconds: 2));

      final afterRecover = container.read(voiceCallProvider);
      expect(afterRecover.phase, VoiceCallPhase.listening);
      expect(afterRecover.currentTranscript, isEmpty);
      // Finalized local bubble must not survive an abandoned turn.
      expect(container.read(chatProvider).messages, isEmpty);

      // Next turn: speech_final alone must not cut mid-speech; VAD end closes.
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Try this again',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents
            .where((event) => event == 'utterance.end')
            .length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test(
    'streaming voice finalizes once when speech_final arrives twice same turn',
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
        'transcript': 'Plan my launch week',
      });
      await Future<void>.delayed(Duration.zero);

      const transcript = 'Plan my launch week';
      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': transcript,
        'speech_final': true,
      });
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': transcript,
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      // Mid-utterance speech_final must not close while mic speech is open.
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.first.content, transcript);
      expect(messages.first.isVoiceInterim, isFalse);
    },
  );

  test(
    'streaming voice waits for speech_final when local VAD ends before transcript arrives',
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

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        isEmpty,
      );
      // Must not wipe Deepgram while waiting for late speech_final.
      expect(
        streamingApi.socket.sentEvents,
        isNot(contains('user.interrupt')),
      );

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Plan my launch week',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
    },
  );

  test(
    'empty speech_final does not cancel capture or soft-recover listen',
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

      // Premature empty endpoint from STT must not kill the mic turn.
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': '',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        isEmpty,
      );

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Keep going with this idea',
      });
      await Future<void>.delayed(Duration.zero);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Keep going with this idea',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
    },
  );

  testWidgets('voice live transcript hides processing while thinking', (
    tester,
  ) async {
    const userText = 'Twitter account for Clarity';
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: VoiceLiveTranscript(
            state: VoiceCallState(
              phase: VoiceCallPhase.thinking,
              currentTranscript: userText,
              callStartedAt: DateTime(2026),
            ),
          ),
        ),
      ),
    );

    expect(find.text(userText), findsNothing);
    expect(find.text(l10n.voicePanelProcessing), findsNothing);
    expect(find.text(l10n.voicePanelThinking), findsNothing);
  });

  testWidgets(
    'voice live transcript does not duplicate assistant reply while speaking',
    (tester) async {
      const reply = 'Haha it is late af over here';
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: VoiceLiveTranscript(
              state: VoiceCallState(
                phase: VoiceCallPhase.speaking,
                lastAssistantResponse: reply,
                callStartedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );

      expect(find.text(reply), findsNothing);
      expect(find.text(l10n.voicePanelSpeaking), findsOneWidget);
    },
  );

  testWidgets(
    'voice live transcript hides Thinking while timed indicator owns it',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: VoiceLiveTranscript(
              state: VoiceCallState(
                phase: VoiceCallPhase.thinking,
                thinkingStartedAt: DateTime(2026),
                callStartedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );

      expect(find.text(l10n.voicePanelThinking), findsNothing);
    },
  );

  testWidgets(
    'voice live transcript keeps Start talking while listening (no duplicate)',
    (tester) async {
      const userText = 'Twitter account for Clarity';
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: VoiceLiveTranscript(
              state: VoiceCallState(
                phase: VoiceCallPhase.listening,
                currentTranscript: userText,
                callStartedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );

      // Interim chat bubble owns live speech; bottom status stays the prompt.
      expect(find.text(userText), findsNothing);
      expect(find.text(l10n.voicePanelStartTalking), findsOneWidget);
    },
  );

  testWidgets('inline voice panel has no manual interrupt button', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
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
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
  });

  testWidgets('inline voice panel shows recoverable retry action on failure', (
    tester,
  ) async {
    var retryCount = 0;
    var settingsCount = 0;
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Column(
            children: [
              VoiceLiveTranscript(
                state: VoiceCallState(
                  phase: VoiceCallPhase.failed,
                  errorMessage: 'Assistant voice stream disconnected.',
                  callStartedAt: DateTime(2026),
                ),
              ),
              InlineVoiceCallPanel(
                state: VoiceCallState(
                  phase: VoiceCallPhase.failed,
                  errorMessage: 'Assistant voice stream disconnected.',
                  callStartedAt: DateTime(2026),
                ),
                onRetry: () => retryCount++,
                onEnd: () {},
                onToggleMute: () {},
                onOpenSettings: () => settingsCount++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.text(l10n.voiceFailureConnectionDropped),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.voicePanelTryAgainTooltip), findsOneWidget);
    expect(find.byTooltip(l10n.voicePanelSettingsTooltip), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.voicePanelTryAgainTooltip));
    await tester.tap(find.byTooltip(l10n.voicePanelSettingsTooltip));

    expect(retryCount, 1);
    expect(settingsCount, 1);
  });

  test(
    'streaming voice waits for playback before returning to listening',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
      final audioSessionService = _CountingVoiceAudioSessionService();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final localeController = LocaleController(
        preferences: SharedPreferencesAsync(),
      );
      await localeController.load();
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
          localeControllerProvider.overrideWithValue(localeController),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Plan my launch week',
      });
      await Future<void>.delayed(Duration.zero);

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
        'memory_changes': {'created': 1},
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
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(chatProvider).conversationId, 'conversation-voice');
      expect(container.read(chatProvider).messages.length, 2);

      await playbackService.playStarted.future;
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(
        audioSessionService.preferLoudSpeakerCount,
        greaterThanOrEqualTo(1),
      );
      final stopCountAfterPlaybackStarted = playbackService.stopCount;

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
      expect(playbackService.stopCount, stopCountAfterPlaybackStarted);
      expect(streamingApi.connectCount, 1);
      expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
      expect(streamingApi.socket.closeCount, 0);
    },
  );

  test(
    'streaming voice does not fallback when audio chunks are accepted but still playing',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
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
          streamingVoiceApiProvider.overrideWithValue(streamingApi),
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

      captureService.finishCurrentWithSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Tell me about push ups',
        'speech_final': true,
      });
      streamingApi.socket.emit({'event': 'assistant.started'});
      streamingApi.socket.emit({
        'event': 'assistant.token',
        'token': 'Wide-grip push-ups work chest and back.',
      });
      streamingApi.socket.emit({
        'event': 'assistant.audio_chunk',
        'audio_base64': base64Encode([1, 2, 3]),
        'audio_content_type': 'audio/mpeg',
        'text': 'Wide-grip push-ups work chest and back.',
      });
      await playbackService.playStarted.future;

      streamingApi.socket.emit({
        'event': 'assistant.done',
        'conversation_id': 'conversation-voice',
        'response_text': 'Wide-grip push-ups work chest and back.',
      });
      await Future<void>.delayed(Duration.zero);

      expect(cloudVoiceApi.synthesizedTexts, isEmpty);
      expect(playbackService.playCount, 1);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);

      playbackService.complete();
      await captureService.readyAt(1);

      expect(cloudVoiceApi.synthesizedTexts, isEmpty);
      expect(playbackService.playCount, 1);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
    },
  );

  test(
    'streaming voice synthesizes fallback audio when done has text but no audio chunk',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
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
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'I finished my plan tonight',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'I finished my plan tonight',
        'speech_final': true,
      });
      streamingApi.socket.emit({'event': 'assistant.started'});
      streamingApi.socket.emit({
        'event': 'assistant.token',
        'token':
            "I understood that, but I couldn't save it just now.",
      });
      streamingApi.socket.emit({
        'event': 'messages.updated',
        'conversation_id': 'conversation-voice',
        'messages': [
          {
            'id': 'user-message-1',
            'conversation_id': 'conversation-voice',
            'role': 'user',
            'content': 'I finished my plan tonight',
            'timestamp': '2026-06-01T12:00:00Z',
          },
          {
            'id': 'assistant-message-1',
            'conversation_id': 'conversation-voice',
            'role': 'assistant',
            'content':
                "I understood that, but I couldn't save it just now.",
            'timestamp': '2026-06-01T12:00:01Z',
          },
        ],
      });
      streamingApi.socket.emit({
        'event': 'assistant.done',
        'conversation_id': 'conversation-voice',
        'response_text':
            "I understood that, but I couldn't save it just now.",
      });

      await captureService.readyAt(1).timeout(const Duration(seconds: 1));

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.errorMessage, isNull);
      expect(
        state.lastAssistantResponse,
        "I understood that, but I couldn't save it just now.",
      );
      expect(cloudVoiceApi.synthesizedTexts, [
        "I understood that, but I couldn't save it just now.",
      ]);
      expect(container.read(chatProvider).messages.length, 2);
    },
  );

  test(
    'muted streaming turn resumes listening after assistant.done without audio',
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
      controller.toggleMuted();
      await captureService.readyAt(0);

      captureService.finishCurrentWithSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'What are you?',
        'speech_final': true,
      });
      streamingApi.socket.emit({'event': 'assistant.started'});
      streamingApi.socket.emit({
        'event': 'assistant.token',
        'token': "I'm Rex, Clarity's private AI companion.",
      });
      streamingApi.socket.emit({
        'event': 'assistant.done',
        'conversation_id': 'conversation-voice',
        'response_text': "I'm Rex, Clarity's private AI companion.",
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.isMuted, isTrue);
      expect(state.errorMessage, isNull);
      expect(
        state.lastAssistantResponse,
        "I'm Rex, Clarity's private AI companion.",
      );
    },
  );

  test(
    'speech final prepares playback audio session before assistant audio',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
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
        'transcript': 'Hello Rex',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hello Rex',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(audioSessionService.configureCount, greaterThanOrEqualTo(1));
      expect(audioSessionService.preferLoudSpeakerCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'streaming playback fallback surfaces error when synthesis fails',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
      final cloudVoiceApi = _FailingCloudVoiceApi();
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
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Hello Rex',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hello Rex',
        'speech_final': true,
      });
      streamingApi.socket.emit({'event': 'assistant.started'});
      streamingApi.socket.emit({
        'event': 'assistant.token',
        'token': 'Short reply.',
      });
      streamingApi.socket.emit({
        'event': 'assistant.done',
        'conversation_id': 'conversation-voice',
        'response_text': 'Short reply.',
      });

      await Future<void>.delayed(Duration.zero);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.failed);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, isNotEmpty);
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

      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hey. How are you doing?',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      // speech_final while capturing must keep listening (no ~1s cut-off).
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(
        streamingApi.socket.sentEvents.where(
          (event) => event == 'utterance.end',
        ),
        isEmpty,
      );

      captureService.finishCurrentWithSpeech();
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

    final chatMessages = container.read(chatProvider).messages;
    expect(chatMessages, hasLength(1));
    expect(chatMessages.first.content, 'Tell me about my day.');
    expect(chatMessages.first.isVoiceInterim, isFalse);
  });

  test('updateTranscript adds interim voice message to chat', () async {
    final captureService = _ScriptedStreamingAudioCaptureService();
    final bargeInService = _ControlledBargeInDetectionService();
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
        bargeInDetectionServiceProvider.overrideWithValue(bargeInService),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceCallProvider.notifier);
    expect(await controller.startCall(), isTrue);
    await captureService.readyAt(0);

    controller.updateTranscript('How are my budgets');
    await Future<void>.delayed(Duration.zero);

    final interim = container.read(chatProvider).messages;
    expect(interim, hasLength(1));
    expect(interim.first.content, 'How are my budgets');
    expect(interim.first.isVoiceInterim, isTrue);

    controller.startThinking(finalTranscript: 'How are my budgets looking?');
    await Future<void>.delayed(Duration.zero);

    final finalized = container.read(chatProvider).messages;
    expect(finalized, hasLength(1));
    expect(finalized.first.content, 'How are my budgets looking?');
    expect(finalized.first.isVoiceInterim, isFalse);
  });

  test(
    'messages.updated with assistant-only keeps finalized local voice message',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final bargeInService = _ControlledBargeInDetectionService();
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
          bargeInDetectionServiceProvider.overrideWithValue(bargeInService),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);
      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      controller.updateTranscript('to the door frame.');
      controller.startThinking(finalTranscript: 'to the door frame.');
      await Future<void>.delayed(Duration.zero);

      streamingApi.socket.emit({
        'event': 'messages.updated',
        'conversation_id': 'conversation-voice',
        'messages': [
          {
            'id': 'assistant-message-1',
            'conversation_id': 'conversation-voice',
            'role': 'assistant',
            'content': 'It is a doorway pull-up bar.',
            'timestamp': '2026-06-01T12:00:01Z',
          },
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(2));
      expect(messages.first.role, ChatMessageRole.user);
      expect(messages.first.content, 'to the door frame.');
      expect(messages.first.isVoiceInterim, isFalse);
      expect(messages.last.role, ChatMessageRole.assistant);
    },
  );

  test(
    'REST fallback keeps user transcript after backend sync',
    () async {
      final captureService = _RecordingAudioCaptureService();
      final cloudVoiceApi = _FakeCloudVoiceApi();
      final playbackService = _ControlledAudioPlaybackService();
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
          audioCaptureServiceProvider.overrideWithValue(captureService),
          audioPlaybackServiceProvider.overrideWithValue(playbackService),
          streamingVoiceEnabledProvider.overrideWithValue(true),
          cloudVoiceEnabledProvider.overrideWithValue(true),
          nativeIosVoiceEnabledProvider.overrideWithValue(false),
          streamingVoiceApiProvider.overrideWithValue(
            _FailingStreamingVoiceApi(),
          ),
          streamingAudioCaptureServiceProvider.overrideWithValue(
            const _NoopStreamingAudioCaptureService(),
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
      await playbackService.playStarted.future;
      await Future<void>.delayed(Duration.zero);

      final messages = container.read(chatProvider).messages;
      expect(messages.any((message) => message.role == ChatMessageRole.user), isTrue);
      expect(
        messages.any(
          (message) =>
              message.role == ChatMessageRole.user &&
              message.content.contains('Hello from REST fallback'),
        ),
        isTrue,
      );
      expect(messages.any((message) => message.role == ChatMessageRole.assistant), isTrue);
    },
  );

  test(
    'barge-in monitoring stays off by default during Rex playback',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final playbackService = _ControlledAudioPlaybackService();
      final bargeInService = _ControlledBargeInDetectionService();
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
          streamingAudioCaptureServiceProvider.overrideWithValue(
            captureService,
          ),
          bargeInDetectionServiceProvider.overrideWithValue(bargeInService),
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);

      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      unawaited(controller.speakTypedAssistantResponse('Rex is speaking now.'));
      await playbackService.playStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.speaking);
      expect(bargeInService.started.isCompleted, isFalse);

      playbackService.complete();
      await captureService.readyAt(1);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
    },
  );

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
      // Soft empty recover must not wipe live STT (stuck listening loop).
      expect(streamingApi.socket.sentEvents, isNot(contains('user.interrupt')));
      expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
      expect(streamingApi.socket.closeCount, 0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Hello again',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);
      expect(streamingApi.socket.sentEvents, contains('utterance.end'));

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Hello again',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

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
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(voiceCallProvider).currentTranscript,
        "It's next week, but on the eighteenth, it's my mom's birthday",
      );

      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript':
            "It's next week, but on the eighteenth, it's my mom's birthday. "
            "It's next week, but on the eighteenth, it's my mom's birthday.",
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.thinking);
      expect(state.currentTranscript, isEmpty);
    },
  );

  test(
    'startCapturingSpeech during same utterance keeps one chat message',
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

      controller.updateTranscript('Everything good? I want some weights');
      controller.startCapturingSpeech();
      controller.updateTranscript(
        'Everything good? I want some weights so I can exercise at home.',
      );
      await Future<void>.delayed(Duration.zero);

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(
        messages.first.content,
        'Everything good? I want some weights so I can exercise at home.',
      );
      expect(messages.first.isVoiceInterim, isTrue);
    },
  );

  test(
    'speech_final keeps one finalized user message in chat',
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
        'transcript': 'so I can exercise at home.',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript':
            'Everything good? I also want some weights so I can exercise at home.',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(
        messages.first.content,
        'Everything good? I also want some weights so I can exercise at home.',
      );
      expect(messages.first.isVoiceInterim, isFalse);
      expect(streamingApi.socket.sentEvents, contains('utterance.end'));
    },
  );

  test(
    'speech_final with last segment only keeps full interim transcript in chat',
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

      const fullTranscript =
          'Everything good? I also want some weights so I can exercise at home.';

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'Everything good?',
      });
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'I also want some weights',
      });
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'so I can exercise at home.',
      });
      await Future<void>.delayed(Duration.zero);

      final interim = container.read(chatProvider).messages;
      expect(interim, hasLength(1));
      expect(interim.first.content, fullTranscript);
      expect(interim.first.isVoiceInterim, isTrue);

      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': 'so I can exercise at home.',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(chatProvider).messages.first.content, fullTranscript);
      expect(container.read(chatProvider).messages.first.isVoiceInterim, isTrue);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.first.content, fullTranscript);
      expect(messages.first.isVoiceInterim, isFalse);
      expect(streamingApi.socket.sentEvents, contains('utterance.end'));
    },
  );

  test(
    'local endpoint before speech_final upgrades one chat bubble to full transcript',
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

      const partialTranscript =
          'Great. So my next goal should buy this bar and what do you recommend for, like, some weights because I got I gotta lift';
      const fullTranscript =
          '$partialTranscript something. You know?';

      final controller = container.read(voiceCallProvider.notifier);
      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': partialTranscript,
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      final partialMessages = container.read(chatProvider).messages;
      expect(partialMessages, hasLength(1));
      expect(partialMessages.first.content, partialTranscript);

      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': fullTranscript,
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.first.content, fullTranscript);
      expect(messages.first.isVoiceInterim, isFalse);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
    },
  );

  test(
    'startCapturingSpeech after breath pause keeps turn-scoped local voice id',
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

      const firstSegment =
          'Great. So my next goal should buy this bar and what do you recommend for, like, some weights because I got I gotta lift';
      const fullTranscript = '$firstSegment something. You know?';

      final controller = container.read(voiceCallProvider.notifier);
      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      controller.updateTranscript(firstSegment);
      controller.startCapturingSpeech();
      controller.updateTranscript(fullTranscript, isFinal: true);
      controller.startThinking(finalTranscript: fullTranscript);
      await Future<void>.delayed(Duration.zero);

      final messages = container.read(chatProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.first.content, fullTranscript);
      expect(messages.first.id, startsWith('local-voice-'));
    },
  );

  test(
    'second turn strips sticky prior and bubble matches utterance.end',
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

      const prior =
          'OK so I am about to buy my first bike when I got my learning permit';
      const nextOnly = 'and I know it is possible with the CBR 600';
      const sticky = '$prior $nextOnly';

      final controller = container.read(voiceCallProvider.notifier);
      expect(await controller.startCall(), isTrue);
      await captureService.readyAt(0);

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': prior,
      });
      await Future<void>.delayed(Duration.zero);
      captureService.startCurrentSpeech();
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      final firstEnd = streamingApi.socket.sentPayloads.lastWhere(
        (payload) => payload['event'] == 'utterance.end',
      );
      expect(firstEnd['transcript'], prior);
      expect(container.read(chatProvider).messages.single.content, prior);

      controller.resumeListening();
      await captureService.readyAt(1);

      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': sticky,
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(container.read(voiceCallProvider).currentTranscript, nextOnly);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      final secondEnd = streamingApi.socket.sentPayloads.lastWhere(
        (payload) => payload['event'] == 'utterance.end',
      );
      final bubble = container.read(chatProvider).messages.last.content;
      expect(secondEnd['transcript'], nextOnly);
      expect(bubble, nextOnly);
      expect(bubble.startsWith(prior), isFalse);

      // Late sticky polish must not re-stack prior into the finalized bubble.
      streamingApi.socket.emit({
        'event': 'transcript.final',
        'transcript': '$sticky RR',
        'speech_final': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(chatProvider).messages.last.content,
        '$nextOnly RR',
      );
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(2),
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
      expect(state.isCallActive, isTrue);
    },
  );

  test(
    'inactive then resumed preserves streaming session and live transcript',
    () async {
      final captureService = _ReusableSilentStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
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
        'transcript': 'I want a motorcycle',
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(voiceCallProvider).currentTranscript,
        'I want a motorcycle',
      );
      expect(streamingApi.connectCount, 1);
      final configureBefore = audioSessionService.configureCount;

      // Screenshot / Control Center path.
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(voiceCallProvider);
      expect(state.isCallActive, isTrue);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.currentTranscript, 'I want a motorcycle');
      expect(streamingApi.connectCount, 1);
      expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
      expect(streamingApi.socket.sentEvents, isNot(contains('utterance.end')));
      // Soft resume must not reconfigure AVAudioSession (that kills the mic).
      expect(audioSessionService.configureCount, configureBefore);
    },
  );

  test(
    'screenshot inactive must not finalize partial transcript as utterance.end',
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

      const partial = 'Yeah I guess my question is only';
      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': partial,
      });
      await Future<void>.delayed(Duration.zero);

      // User takes a screenshot mid-sentence: inactive + capture looks ended.
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(
        streamingApi.socket.sentEvents.where((e) => e == 'utterance.end'),
        isEmpty,
      );
      expect(container.read(voiceCallProvider).currentTranscript, partial);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await captureService.readyAt(1);

      expect(container.read(voiceCallProvider).isCallActive, isTrue);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(container.read(voiceCallProvider).currentTranscript, partial);
      expect(
        streamingApi.socket.sentEvents.where((e) => e == 'utterance.end'),
        isEmpty,
      );
      expect(streamingApi.connectCount, 1);
    },
  );

  test(
    'mic stream death before inactive must not send utterance.end',
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

      const partial = 'My real goal of buying before I do the road test';
      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': partial,
      });
      await Future<void>.delayed(Duration.zero);

      // Screenshot race: recorder dies while app still reports foreground.
      captureService.abortCurrentWithSpeechWithoutEndpoint();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await captureService.readyAt(1);

      expect(container.read(voiceCallProvider).isCallActive, isTrue);
      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(container.read(voiceCallProvider).currentTranscript, partial);
      expect(
        streamingApi.socket.sentEvents.where((e) => e == 'utterance.end'),
        isEmpty,
      );
      expect(streamingApi.connectCount, 1);
    },
  );

  test(
    'manual-endpoint-only suppresses VAD submit until red stop',
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
          voiceManualEndpointOnlyProvider.overrideWithValue(true),
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

      const spoken =
          'I am speaking continuously for a long time about the road test '
          'and whether I should wait for the full license before buying';
      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': spoken,
      });
      await Future<void>.delayed(Duration.zero);

      // Local VAD would have fired — must not submit in manual-endpoint mode.
      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await captureService.readyAt(1);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(container.read(voiceCallProvider).currentTranscript, spoken);
      expect(
        streamingApi.socket.sentEvents.where((e) => e == 'utterance.end'),
        isEmpty,
      );

      expect(await controller.submitManualEndTurn(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where((e) => e == 'utterance.end'),
        hasLength(1),
      );
      final endPayload = streamingApi.socket.sentPayloads.lastWhere(
        (p) => p['event'] == 'utterance.end',
      );
      expect(endPayload['transcript'], spoken);
    },
  );

  test(
    'max-duration capture rolls same turn without utterance.end',
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

      const partial = 'I am still talking through the max duration limit';
      captureService.startCurrentSpeech();
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': partial,
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithMaxDuration();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await captureService.readyAt(1);

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
      expect(container.read(voiceCallProvider).currentTranscript, partial);
      expect(
        streamingApi.socket.sentEvents.where((e) => e == 'utterance.end'),
        isEmpty,
      );
      expect(streamingApi.connectCount, 1);
    },
  );

  test('detached lifecycle ends the active voice call', () async {
    final captureService = _ReusableSilentStreamingAudioCaptureService();
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
    expect(container.read(voiceCallProvider).isCallActive, isTrue);

    controller.didChangeAppLifecycleState(AppLifecycleState.detached);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(voiceCallProvider).isCallActive, isFalse);
  });

  test(
    'paused then resumed keeps healthy listen cycle without new websocket',
    () async {
      final captureService = _ReusableSilentStreamingAudioCaptureService();
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
      expect(streamingApi.connectCount, 1);
      expect(captureService.startCount, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(voiceCallProvider);
      expect(state.isCallActive, isTrue);
      expect(state.phase, VoiceCallPhase.listening);
      expect(streamingApi.connectCount, 1);
      expect(captureService.startCount, 1);
      expect(streamingApi.socket.sentEvents, isNot(contains('session.end')));
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

  test(
    'voice call survives 5 consecutive mixed spoken and typed turns',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
      final streamingApi = _FakeStreamingVoiceApi();
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
          cloudVoiceApiProvider.overrideWithValue(cloudVoiceApi),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(voiceCallProvider.notifier);
      final chatController = container.read(chatProvider.notifier);
      final apiMessages = <Map<String, dynamic>>[];
      var messageSequence = 0;
      var captureIndex = 0;

      void expectListeningAfterTurn(String expectedAssistantResponse) {
        final voice = container.read(voiceCallProvider);
        final chat = container.read(chatProvider);
        expect(voice.phase, VoiceCallPhase.listening);
        expect(voice.errorMessage, isNull);
        expect(voice.conversationId, 'conversation-mixed');
        expect(voice.lastAssistantResponse, expectedAssistantResponse);
        expect(chat.conversationId, 'conversation-mixed');
        expect(chat.messages.last.content, expectedAssistantResponse);
      }

      void appendApiMessage(String role, String content) {
        messageSequence++;
        apiMessages.add({
          'id': 'message-$messageSequence',
          'conversation_id': 'conversation-mixed',
          'role': role,
          'content': content,
          'timestamp':
              '2026-06-01T12:00:${messageSequence.toString().padLeft(2, '0')}Z',
        });
      }

      void appendLocalMessage(ChatMessageRole role, String content) {
        messageSequence++;
        final messageId = 'local-message-$messageSequence';
        final timestamp = DateTime.utc(2026, 6, 1, 12, 0, messageSequence);
        apiMessages.add({
          'id': messageId,
          'conversation_id': 'conversation-mixed',
          'role': role == ChatMessageRole.user ? 'user' : 'assistant',
          'content': content,
          'timestamp': timestamp.toIso8601String(),
        });
        chatController.addMessage(
          ChatMessage(
            id: messageId,
            role: role,
            content: content,
            timestamp: timestamp,
          ),
        );
      }

      Future<void> completeSpokenTurn({
        required String userText,
        required String assistantText,
      }) async {
        final nextCaptureIndex = captureIndex + 1;
        appendApiMessage('user', userText);
        appendApiMessage('assistant', assistantText);

        streamingApi.socket.emit({
          'event': 'transcript.partial',
          'transcript': userText,
        });
        await Future<void>.delayed(Duration.zero);

        captureService.finishCurrentWithSpeech();
        final socket = streamingApi.socket;
        socket.emit({
          'event': 'transcript.final',
          'transcript': userText,
          'speech_final': true,
        });
        socket.emit({'event': 'assistant.started'});
        socket.emit({'event': 'assistant.token', 'token': assistantText});
        socket.emit({
          'event': 'assistant.audio_chunk',
          'audio_base64': base64Encode([1, 2, 3]),
          'audio_content_type': 'audio/mpeg',
          'text': assistantText,
        });
        socket.emit({
          'event': 'messages.updated',
          'conversation_id': 'conversation-mixed',
          'messages': [...apiMessages],
        });
        socket.emit({
          'event': 'assistant.done',
          'conversation_id': 'conversation-mixed',
          'response_text': assistantText,
        });

        await captureService
            .readyAt(nextCaptureIndex)
            .timeout(const Duration(seconds: 1));
        captureIndex = nextCaptureIndex;
        expectListeningAfterTurn(assistantText);
      }

      Future<void> completeTypedTurn({
        required String userText,
        required String assistantText,
      }) async {
        final nextCaptureIndex = captureIndex + 1;

        controller.beginTypedTextTurn(userText);
        expect(
          container.read(voiceCallProvider).phase,
          VoiceCallPhase.thinking,
        );
        expect(container.read(voiceCallProvider).currentTranscript, userText);

        appendLocalMessage(ChatMessageRole.user, userText);
        appendLocalMessage(ChatMessageRole.assistant, assistantText);
        await controller.speakTypedAssistantResponse(assistantText);

        await captureService
            .readyAt(nextCaptureIndex)
            .timeout(const Duration(seconds: 1));
        captureIndex = nextCaptureIndex;
        expectListeningAfterTurn(assistantText);
      }

      expect(
        await controller.startCall(conversationId: 'conversation-mixed'),
        isTrue,
      );
      await captureService.readyAt(captureIndex);

      await completeSpokenTurn(
        userText: 'Voice turn one',
        assistantText: 'Voice reply one.',
      );
      await completeTypedTurn(
        userText: 'Typed turn two',
        assistantText: 'Typed reply two.',
      );
      await completeSpokenTurn(
        userText: 'Voice turn three',
        assistantText: 'Voice reply three.',
      );
      await completeTypedTurn(
        userText: 'Typed turn four',
        assistantText: 'Typed reply four.',
      );
      await completeSpokenTurn(
        userText: 'Voice turn five',
        assistantText: 'Voice reply five.',
      );

      expect(cloudVoiceApi.synthesizedTexts, [
        'Typed reply two.',
        'Typed reply four.',
      ]);
      expect(
        container.read(chatProvider).messages.length,
        greaterThanOrEqualTo(10),
      );
      expect(streamingApi.connectCount, greaterThanOrEqualTo(1));
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

  test('pauseForSaveConfirmation only interrupts once', () async {
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
          _ScriptedStreamingAudioCaptureService(),
        ),
        bargeInDetectionServiceProvider.overrideWithValue(
          const _NoopBargeInDetectionService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(voiceCallProvider.notifier);
    expect(await controller.startCall(), isTrue);

    controller.pauseForSaveConfirmation();
    controller.pauseForSaveConfirmation();

    expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
    controller.resumeAfterSaveConfirmation();
    expect(container.read(voiceCallProvider).phase, VoiceCallPhase.listening);
  });

  test(
    'resumeAfterSaveConfirmation restarts listening after mid-utterance card pause',
    () async {
      final captureService = _ScriptedStreamingAudioCaptureService();
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

      controller.startCapturingSpeech(transcript: 'After the card I can talk again.');
      controller.pauseForSaveConfirmation();
      controller.resumeAfterSaveConfirmation();

      final state = container.read(voiceCallProvider);
      expect(state.phase, VoiceCallPhase.listening);
      expect(state.isCallActive, isTrue);
    },
  );

  test(
    'streaming voice completes turn while pending save card exists in history',
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

      container.read(chatProvider.notifier).addMessage(
        ChatMessage(
          id: 'assistant-pending',
          role: ChatMessageRole.assistant,
          content: 'Should I save that goal?',
          timestamp: DateTime(2026),
          clarityActions: const [
            ClarityActionCard(
              id: 'plan-save-1',
              action: 'save_plan',
              payload: {},
              confirmationText: 'Save goal?',
              riskLevel: 'medium',
              status: 'pending',
            ),
          ],
        ),
      );

      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Tell me',
      });
      await Future<void>.delayed(Duration.zero);
      streamingApi.socket.emit({
        'event': 'transcript.partial',
        'transcript': 'Tell me about my budgets',
      });
      await Future<void>.delayed(Duration.zero);

      captureService.finishCurrentWithSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(voiceCallProvider).phase, VoiceCallPhase.thinking);
      expect(
        streamingApi.socket.sentEvents.where((event) => event == 'utterance.end'),
        hasLength(1),
      );
      final messages = container.read(chatProvider).messages;
      expect(messages.where((message) => message.role == ChatMessageRole.user), hasLength(1));
      expect(messages.lastWhere((message) => message.role == ChatMessageRole.user).isVoiceInterim, isFalse);
    },
  );
}
