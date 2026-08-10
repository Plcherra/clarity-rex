// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerLifecycle on VoiceCallController {
  Future<void> _prepareVoiceAudioEnvironment() async {
    try {
      await _audioSessionService.configureForVoiceTurn();
      _bindAudioInterruptionHold();
      await _backgroundVoiceService.start();
    } on Object {
      // Audio session setup should improve reliability, not block voice mode.
    }
  }

  void _bindAudioInterruptionHold() {
    unawaited(_audioInterruptionSubscription?.cancel());
    _audioInterruptionSubscription = _audioSessionService.listenForInterruptions(
      onBegin: () {
        if (!state.isCallActive || _isUsingNativeVoice) {
          return;
        }
        _beginLifecycleUtteranceHold(reason: 'audio_interruption');
      },
      onEnd: () {
        if (!state.isCallActive || _isUsingNativeVoice) {
          return;
        }
        unawaited(_handleAudioInterruptionEnded());
      },
    );
  }

  Future<void> _handleAudioInterruptionEnded() async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    // Same soft recover as screenshot inactive→resumed: never finalize.
    _endLifecycleUtteranceHold();
    await _recoverListenCycleAfterLifecycleHold();
    debugPrint('rex_voice_lifecycle audio_interruption_ended recover_listen');
  }

  Future<void> _releaseVoiceHardware() async {
    await _stopInterimTranscription();
    _stopNativeVoiceSession();
    _stopBargeInMonitoring();
    final interruptionSubscription = _audioInterruptionSubscription;
    _audioInterruptionSubscription = null;
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    _activeStreamingEventsTask = null;

    // Stop mic capture before closing the websocket so late chunks are not
    // sent into a closing socket and browser tracks are released promptly.
    await _streamingCaptureService.cancel();
    await _captureService.cancel();

    streamingSession?.interrupt();

    await Future.wait([
      if (interruptionSubscription != null) interruptionSubscription.cancel(),
      _streamingPlaybackQueue.cancel(),
      _playbackService.stop(),
      _backgroundVoiceService.stop(),
      _audioSessionService.setActive(false),
      if (streamingSession != null) streamingSession.endSession(),
    ]);
  }

  /// Lifecycle contract for an active streaming voice call:
  /// - [AppLifecycleState.inactive]: preserve completely (screenshot / CC)
  /// - [AppLifecycleState.resumed]: soft restore; never recreate a healthy call
  /// - [AppLifecycleState.paused] / [AppLifecycleState.hidden]: keep call;
  ///   ensure background audio session stays armed on native mobile
  /// - [AppLifecycleState.detached]: end the call
  void _onAppLifecycleStateChanged(AppLifecycleState next) {
    final previous = _lastAppLifecycleState;
    _lastAppLifecycleState = next;

    if (next == AppLifecycleState.detached) {
      _isAppInForeground = false;
      _holdUtteranceEndForLifecycle = false;
      _restartListenAfterLifecycleHold = false;
      unawaited(endCall());
      return;
    }

    if (next == AppLifecycleState.resumed) {
      _isAppInForeground = true;
    } else if (next == AppLifecycleState.inactive ||
        next == AppLifecycleState.paused ||
        next == AppLifecycleState.hidden) {
      // Suppress no-speech fail while UI is obscured; do not tear down audio.
      _isAppInForeground = false;
    }

    if (!state.isCallActive) {
      return;
    }

    if (_isUsingNativeVoice) {
      unawaited(
        _nativeVoiceSessionService.setForegroundState(
          next == AppLifecycleState.resumed,
        ),
      );
      return;
    }

    // Screenshot, Control Center, notification shade, app-switch peek.
    if (next == AppLifecycleState.inactive) {
      _beginLifecycleUtteranceHold(reason: 'inactive');
      return;
    }

    if (next == AppLifecycleState.paused || next == AppLifecycleState.hidden) {
      _beginLifecycleUtteranceHold(reason: '$next');
      if (AppCapabilities.instance.supportsBackgroundVoice) {
        unawaited(_backgroundVoiceService.start());
      }
      debugPrint('rex_voice_lifecycle background_keep_session state=$next');
      return;
    }

    if (next == AppLifecycleState.resumed) {
      final fromTransientInactive = previous == AppLifecycleState.inactive;
      final fromTrueBackground =
          previous == AppLifecycleState.paused ||
          previous == AppLifecycleState.hidden;
      unawaited(
        _handleLifecycleResume(
          fromTransientInactive: fromTransientInactive,
          returningFromTrueBackground: fromTrueBackground,
        ),
      );
    }
  }

  void _beginLifecycleUtteranceHold({required String reason}) {
    _holdUtteranceEndForLifecycle = true;
    // Do not let transcript-idle / speech-final grace fire mid-screenshot.
    _cancelListeningEndpointTimeout();
    _cancelSpeechFinalGrace();
    debugPrint('rex_voice_lifecycle hold_utterance_end reason=$reason');
  }

  void _endLifecycleUtteranceHold() {
    _holdUtteranceEndForLifecycle = false;
  }

  Future<void> _handleLifecycleResume({
    required bool fromTransientInactive,
    required bool returningFromTrueBackground,
  }) async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    _isHandlingLifecycleResume = true;
    try {
      // Screenshot / Control Center: absolute no-op for audio session.
      // Reconfigure/setActive here kills the recorder and used to finalize the
      // partial transcript as if the user had stopped talking.
      if (fromTransientInactive || !returningFromTrueBackground) {
        _endLifecycleUtteranceHold();
        await _recoverListenCycleAfterLifecycleHold();
        debugPrint('rex_voice_lifecycle soft_resume preserve_session');
        return;
      }

      // True background return: reaffirm session, then keep or recover listen.
      await _audioSessionService.configureForVoiceTurn();
      await _audioSessionService.preferLoudSpeaker();
      if (AppCapabilities.instance.supportsBackgroundVoice) {
        await _backgroundVoiceService.start();
      }
      _endLifecycleUtteranceHold();

      if (state.isCallActive &&
          state.phase == VoiceCallPhase.thinking &&
          !state.isMuted) {
        _armThinkingTimeout(_callGeneration);
      }

      if (!state.isCallActive ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted) {
        return;
      }

      if (_hasActiveStreamingListenCycle() && _streamingSessionIsConnected()) {
        debugPrint('rex_voice_lifecycle background_resume keep_listen_cycle');
        return;
      }

      await _recoverListenCycleAfterLifecycleHold();
    } finally {
      _isHandlingLifecycleResume = false;
    }
  }

  /// Restart mic capture after a lifecycle blip without finalizing or clearing
  /// the in-progress transcript (never auto-send on resume).
  Future<void> _recoverListenCycleAfterLifecycleHold() async {
    if (!state.isCallActive ||
        state.phase != VoiceCallPhase.listening ||
        state.isMuted) {
      _restartListenAfterLifecycleHold = false;
      return;
    }

    final needsRestart =
        _restartListenAfterLifecycleHold ||
        !_hasActiveStreamingListenCycle() ||
        !_streamingSessionIsConnected();
    _restartListenAfterLifecycleHold = false;
    if (!needsRestart) {
      return;
    }

    debugPrint('rex_voice_lifecycle resume_restart_listen_preserving_transcript');
    final generation = _callGeneration;
    await _captureService.cancel();
    await _streamingCaptureService.cancel();
    _stopBargeInMonitoring();
    state = state.copyWith(isCapturingSpeech: false, clearError: true);
    _startListeningCyclePreservingTranscript(generation);
  }

  void _handleWebPageVisibilityChanged(bool isVisible) {
    if (isVisible) {
      _isAppInForeground = true;
      if (state.isCallActive && !_isUsingNativeVoice) {
        unawaited(_handleWebForegroundResume());
      }
      return;
    }
    _isAppInForeground = false;
    if (state.isCallActive && !_isUsingNativeVoice) {
      _beginLifecycleUtteranceHold(reason: 'web_hidden');
    }
  }

  Future<void> _handleWebForegroundResume() async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    _isHandlingLifecycleResume = true;
    try {
      await WebPcmMicrophoneEngine.instance.resumeIfSuspended();
      _endLifecycleUtteranceHold();

      if (state.isCallActive &&
          (state.phase == VoiceCallPhase.speaking ||
              state.phase == VoiceCallPhase.thinking)) {
        if (!_streamingPlaybackQueue.isIdle) {
          await _streamingPlaybackQueue.cancel();
        }
        if (state.phase == VoiceCallPhase.speaking) {
          completeSpeaking();
        }
        if (!state.isMuted && state.phase != VoiceCallPhase.listening) {
          resumeListening();
        }
      }

      if (!state.isCallActive ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted) {
        return;
      }

      await _recoverListenCycleAfterLifecycleHold();
    } finally {
      _isHandlingLifecycleResume = false;
    }
  }
}
