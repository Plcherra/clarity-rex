import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clarity/core/l10n/app_locale.dart';
import 'package:clarity/core/l10n/app_localizations_lookup.dart';
import 'package:clarity/core/l10n/friendly_service_error.dart';
import 'package:clarity/core/platform/app_capabilities.dart';
import 'package:clarity/features/profile/application/locale_controller.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/core/rex/rex_auth_headers.dart';
import 'package:clarity/rex/chat/application/chat_controller.dart';
import 'package:clarity/rex/chat/data/chat_models.dart';
import 'package:clarity/rex/data/financial_context_service.dart';
import 'package:clarity/rex/voice/data/audio_capture_service.dart';
import 'package:clarity/rex/voice/data/audio_playback_service.dart';
import 'package:clarity/rex/voice/data/recorded_voice_audio.dart';
import 'package:clarity/rex/voice/data/audio_session_service.dart';
import 'package:clarity/rex/voice/data/background_voice_service.dart';
import 'package:clarity/rex/voice/data/cloud_voice_api.dart';
import 'package:clarity/rex/voice/data/native_voice_session_service.dart';
import 'package:clarity/rex/voice/data/speech_to_text_service.dart';
import 'package:clarity/rex/voice/data/streaming_audio_capture_service.dart';
import 'package:clarity/rex/voice/data/streaming_audio_playback_queue.dart';
import 'package:clarity/rex/voice/data/streaming_voice_api.dart';
import 'package:clarity/rex/voice/application/voice_permission_service.dart';
import 'package:clarity/rex/voice/application/voice_transcript_buffer.dart';
import 'package:clarity/rex/voice/domain/voice_call_state.dart';
import 'package:clarity/rex/voice/data/web_pcm_microphone_engine_stub.dart'
    if (dart.library.html) 'package:clarity/rex/voice/data/web_pcm_microphone_engine_web.dart';
import 'package:clarity/rex/voice/data/web_page_visibility.dart';

import 'voice_call_controller_providers.dart';
export 'package:clarity/rex/voice/application/voice_permission_service.dart';
export 'voice_call_controller_providers.dart';

part 'voice_call_controller_commands.dart';
part 'voice_call_controller_native.dart';
part 'voice_call_controller_lifecycle.dart';
part 'voice_call_controller_streaming.dart';
part 'voice_call_controller_streaming_capture.dart';
part 'voice_call_controller_streaming_events.dart';
part 'voice_call_controller_streaming_playback.dart';
part 'voice_call_controller_timers.dart';
part 'voice_call_controller_l10n.dart';
part 'voice_call_controller_dependencies.dart';
part 'voice_call_controller_chat_sync.dart';
part 'voice_call_controller_turn_timing.dart';

final voiceCallProvider = NotifierProvider<VoiceCallController, VoiceCallState>(
  VoiceCallController.new,
);

class VoiceCallController extends Notifier<VoiceCallState>
    with WidgetsBindingObserver {
  int _callGeneration = 0;
  AudioCaptureService? _activeCaptureService;
  StreamingAudioCaptureService? _activeStreamingCaptureService;
  StreamingVoiceSession? _activeStreamingSession;
  Future<void>? _activeStreamingEventsTask;
  AudioPlaybackService? _activePlaybackService;
  SpeechToTextService? _activeInterimSpeechToTextService;
  StreamingAudioPlaybackQueue? _activeStreamingPlaybackQueue;
  BargeInDetectionService? _activeBargeInDetectionService;
  VoiceAudioSessionService? _activeAudioSessionService;
  BackgroundVoiceService? _activeBackgroundVoiceService;
  NativeVoiceSessionService? _activeNativeVoiceSessionService;
  StreamSubscription<NativeVoiceEvent>? _nativeVoiceSubscription;
  final _transcriptBuffer = VoiceTranscriptBuffer();
  var _nativeAssistantText = '';
  var _isStartingCall = false;
  var _isBargeInMonitoring = false;
  var _isHandlingLifecycleResume = false;
  var _isAppInForeground = true;
  var _isUsingNativeVoice = false;
  var _warnedLegacyNativeVoiceFlag = false;
  var _isAwaitingFollowUpSpeech = false;
  var _emptyVoiceTurnRecoveryCount = 0;
  var _streamingUtteranceEndSent = false;
  var _streamingTurnSequence = 0;
  int? _streamingTurnFinalizedSequence;
  var _streamingListenEpoch = 0;
  var _streamingListenEpochInFlight = false;
  Map<String, dynamic>? _prefetchedFinancialContext;
  Future<Map<String, dynamic>?>? _prefetchedFinancialContextTask;
  String? _prefetchedFinancialContextTranscript;
  Timer? _thinkingTimeoutTimer;
  Timer? _noSpeechTimeoutTimer;
  _VoiceTurnTiming? _activeVoiceTurnTiming;
  String? _activeVoiceMessageLocalId;
  String? _pendingUtteranceTranscript;

  @override
  VoiceCallState build() {
    WidgetsFlutterBinding.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      listenWebPageVisibility(_handleWebPageVisibilityChanged);
    }
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      if (kIsWeb) {
        disposeWebPageVisibilityListener();
      }
      _callGeneration++;
      _cancelThinkingTimeout();
      _cancelNoSpeechTimeout();
      final captureService = _activeCaptureService;
      final playbackService = _activePlaybackService;
      final interimSpeechToTextService = _activeInterimSpeechToTextService;
      final streamingPlaybackQueue = _activeStreamingPlaybackQueue;
      final bargeInDetectionService = _activeBargeInDetectionService;
      final streamingCaptureService = _activeStreamingCaptureService;
      final streamingSession = _activeStreamingSession;
      final nativeVoiceSubscription = _nativeVoiceSubscription;
      final nativeVoiceSession = _activeNativeVoiceSessionService;
      final audioSessionService = _activeAudioSessionService;
      final backgroundVoiceService = _activeBackgroundVoiceService;
      if (captureService != null) {
        unawaited(captureService.cancel());
      }
      if (streamingCaptureService != null) {
        unawaited(streamingCaptureService.cancel());
      }
      if (streamingSession != null) {
        _activeStreamingSession = null;
        _activeStreamingEventsTask = null;
        unawaited(streamingSession.endSession());
      }
      if (nativeVoiceSubscription != null) {
        unawaited(nativeVoiceSubscription.cancel());
      }
      if (nativeVoiceSession != null) {
        unawaited(nativeVoiceSession.stopSession());
      }
      if (streamingPlaybackQueue != null) {
        unawaited(streamingPlaybackQueue.cancel());
      }
      if (bargeInDetectionService != null) {
        unawaited(bargeInDetectionService.stop());
      }
      if (playbackService != null) {
        unawaited(playbackService.stop());
      }
      if (interimSpeechToTextService != null) {
        unawaited(interimSpeechToTextService.cancel());
      }
      if (backgroundVoiceService != null) {
        unawaited(backgroundVoiceService.stop());
      }
      if (audioSessionService != null) {
        unawaited(audioSessionService.setActive(false));
      }
    });
    return const VoiceCallState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      unawaited(endCall());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isAppInForeground = false;
    }

    if (!this.state.isCallActive) {
      return;
    }

    if (_isUsingNativeVoice) {
      unawaited(
        _nativeVoiceSessionService.setForegroundState(
          state == AppLifecycleState.resumed,
        ),
      );
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_handleLifecycleResume());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (AppCapabilities.instance.supportsBackgroundVoice) {
        unawaited(_backgroundVoiceService.start());
      }
      return;
    }
  }

  Future<bool> startCall({String? conversationId}) async {
    if (_isStartingCall || !state.canStartCall) {
      return false;
    }

    _isStartingCall = true;
    _isAwaitingFollowUpSpeech = false;
    _emptyVoiceTurnRecoveryCount = 0;
    _warnIfLegacyNativeVoiceFlagRequested();
    final generation = ++_callGeneration;
    _clearVisibleTranscript();
    final startedAt = ref.read(voiceCallNowProvider)();
    final activeConversationId =
        conversationId ?? ref.read(chatProvider).conversationId;

    final permissionDecision = await ref
        .read(microphonePermissionProvider)
        .requestMicrophonePermission(includeSpeechRecognition: false);
    if (!_isCurrentCall(generation)) {
      _isStartingCall = false;
      return false;
    }
    if (permissionDecision != MicrophonePermissionDecision.granted) {
      fail(permissionMessage(permissionDecision));
      _isStartingCall = false;
      return false;
    }

    state = VoiceCallState(
      phase: VoiceCallPhase.listening,
      conversationId: activeConversationId,
      callStartedAt: startedAt,
    );

    if (_shouldUseNativeVoice) {
      final nativeStarted = await _startNativeVoiceSession(
        generation: generation,
        conversationId: activeConversationId,
      );
      if (nativeStarted) {
        _isStartingCall = false;
        return true;
      }
    }

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearError: true,
      clearCallEndedAt: true,
    );
    _isStartingCall = false;

    // Web browsers require mic capture to start while the tap gesture is still
    // active. Do not block on audio-session setup before opening the mic.
    if (kIsWeb) {
      _startListeningCycle(generation);
      unawaited(_prepareVoiceAudioEnvironment());
      return true;
    }

    try {
      await _prepareVoiceAudioEnvironment();
    } on Object {
      failL10n((l10n) => l10n.voiceErrorAudioSessionStartFailed);
      return false;
    }
    if (!_isCurrentCall(generation)) {
      return false;
    }

    _startListeningCycle(generation);
    return true;
  }

  void startSpeaking(String responseText) {
    if (!state.isCallActive) {
      return;
    }

    _isAwaitingFollowUpSpeech = false;
    _emptyVoiceTurnRecoveryCount = 0;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    state = state.copyWith(
      phase: VoiceCallPhase.speaking,
      isCapturingSpeech: false,
      lastAssistantResponse: responseText,
      clearError: true,
    );
  }

  void completeSpeaking() {
    if (state.phase != VoiceCallPhase.speaking) {
      return;
    }

    _finishAssistantResponseAndListen();
  }

  void _finishAssistantResponseAndListen() {
    if (!state.isCallActive) {
      return;
    }

    _isAwaitingFollowUpSpeech = true;
    _emptyVoiceTurnRecoveryCount = 0;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearCurrentTranscript: true,
      clearError: true,
    );
    _clearVisibleTranscript();
    _resetActiveVoiceMessageLocalId();
    _resetPendingUtteranceTranscript();
    _startListeningCycle(_callGeneration);
  }

  bool _hasActiveStreamingListenCycle() =>
      _streamingListenEpochInFlight && _streamingListenEpoch > 0;

  void interruptAndListen({
    String? reason,
    List<Uint8List> initialAudioChunks = const [],
  }) {
    if (!state.isCallActive) {
      return;
    }

    final generation = ++_callGeneration;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.interrupt());
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        clearCurrentTranscript: true,
        clearError: true,
      );
      _clearVisibleTranscript();
      return;
    }
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    streamingSession?.interrupt();
    unawaited(_streamingPlaybackQueue.cancel());
    unawaited(_playbackService.stop());

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      isCapturingSpeech: false,
      clearCurrentTranscript: true,
      clearError: true,
    );
    _clearVisibleTranscript();
    _startListeningCycle(generation, initialAudioChunks: initialAudioChunks);
  }

  void setMuted(bool isMuted) {
    if (!state.isCallActive) {
      return;
    }

    state = state.copyWith(isMuted: isMuted);
    if (_isUsingNativeVoice) {
      unawaited(_nativeVoiceSessionService.setMuted(isMuted));
      return;
    }
    if (isMuted) {
      _callGeneration++;
      _cancelThinkingTimeout();
      _cancelNoSpeechTimeout();
      unawaited(_stopInterimTranscription());
      unawaited(_captureService.cancel());
      unawaited(_streamingCaptureService.cancel());
      _stopBargeInMonitoring();
      final streamingSession = _activeStreamingSession;
      _activeStreamingSession = null;
      _activeStreamingEventsTask = null;
      streamingSession?.interrupt();
      unawaited(_streamingPlaybackQueue.cancel());
      unawaited(streamingSession?.endSession());
    } else if (state.phase == VoiceCallPhase.listening) {
      _startListeningCycle(++_callGeneration);
    }
  }

  void toggleMuted() {
    setMuted(!state.isMuted);
  }

  void fail(String message) {
    _callGeneration++;
    _isAwaitingFollowUpSpeech = false;
    _emptyVoiceTurnRecoveryCount = 0;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    unawaited(_stopInterimTranscription());
    _stopNativeVoiceSession();
    unawaited(_captureService.cancel());
    unawaited(_streamingCaptureService.cancel());
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    _activeStreamingEventsTask = null;
    streamingSession?.interrupt();
    unawaited(_streamingPlaybackQueue.cancel());
    unawaited(streamingSession?.endSession());
    unawaited(_playbackService.stop());
    unawaited(_backgroundVoiceService.stop());
    unawaited(_audioSessionService.setActive(false));
    state = state.copyWith(
      phase: VoiceCallPhase.failed,
      isCapturingSpeech: false,
      errorMessage: message,
      callEndedAt: ref.read(voiceCallNowProvider)(),
      clearCurrentTranscript: true,
    );
    _clearVisibleTranscript();
  }

  Future<void> endCall() async {
    if (!state.canEndCall) {
      return;
    }

    _callGeneration++;
    _isAwaitingFollowUpSpeech = false;
    _emptyVoiceTurnRecoveryCount = 0;
    _cancelThinkingTimeout();
    _cancelNoSpeechTimeout();
    await _releaseVoiceHardware();
    state = state.copyWith(
      phase: VoiceCallPhase.idle,
      isCapturingSpeech: false,
      callEndedAt: ref.read(voiceCallNowProvider)(),
      clearCurrentTranscript: true,
      clearError: true,
    );
    _clearVisibleTranscript();
  }

  Future<void> openVoiceSettings() async {
    await ref.read(microphonePermissionProvider).openSettings();
  }
}
