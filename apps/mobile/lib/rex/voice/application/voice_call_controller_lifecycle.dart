// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'voice_call_controller.dart';

extension VoiceCallControllerLifecycle on VoiceCallController {
  Future<void> _prepareVoiceAudioEnvironment() async {
    try {
      await _audioSessionService.configureForVoiceTurn();
      await _backgroundVoiceService.start();
    } on Object {
      // Audio session setup should improve reliability, not block voice mode.
    }
  }

  Future<void> _releaseVoiceHardware() async {
    await _stopInterimTranscription();
    _stopNativeVoiceSession();
    _stopBargeInMonitoring();
    final streamingSession = _activeStreamingSession;
    _activeStreamingSession = null;
    _activeStreamingEventsTask = null;

    // Stop mic capture before closing the websocket so late chunks are not
    // sent into a closing socket and browser tracks are released promptly.
    await _streamingCaptureService.cancel();
    await _captureService.cancel();

    streamingSession?.interrupt();

    await Future.wait([
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
      debugPrint('rex_voice_lifecycle inactive_preserve_session');
      return;
    }

    if (next == AppLifecycleState.paused || next == AppLifecycleState.hidden) {
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

  Future<void> _handleLifecycleResume({
    required bool fromTransientInactive,
    required bool returningFromTrueBackground,
  }) async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    _isHandlingLifecycleResume = true;
    try {
      // Reaffirm route / session after Control Center or lock-screen overlays.
      await _audioSessionService.configureForVoiceTurn();
      await _audioSessionService.preferLoudSpeaker();
      if (AppCapabilities.instance.supportsBackgroundVoice) {
        await _backgroundVoiceService.start();
      }
      if (state.isCallActive &&
          state.phase == VoiceCallPhase.thinking &&
          !state.isMuted) {
        _armThinkingTimeout(_callGeneration);
      }

      // inactive → resumed must never recreate mic, WS, timers, or turn state.
      if (fromTransientInactive || !returningFromTrueBackground) {
        debugPrint('rex_voice_lifecycle soft_resume preserve_session');
        return;
      }

      if (!state.isCallActive ||
          state.phase != VoiceCallPhase.listening ||
          state.isMuted) {
        return;
      }

      // True background return with a healthy listen cycle: leave it alone.
      if (_hasActiveStreamingListenCycle() && _streamingSessionIsConnected()) {
        debugPrint('rex_voice_lifecycle background_resume keep_listen_cycle');
        return;
      }

      if (_finishPendingStreamingUtteranceOnResume()) {
        return;
      }

      // Capture/session died while away — recover listen without killing the call.
      debugPrint('rex_voice_lifecycle background_resume recover_listen_cycle');
      final generation = ++_callGeneration;
      await _captureService.cancel();
      await _streamingCaptureService.cancel();
      _stopBargeInMonitoring();
      if (!_streamingSessionIsConnected()) {
        final streamingSession = _activeStreamingSession;
        _activeStreamingSession = null;
        _activeStreamingEventsTask = null;
        streamingSession?.interrupt();
        unawaited(streamingSession?.endSession());
      }

      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        isCapturingSpeech: false,
        clearError: true,
      );
      _startListeningCycle(generation);
    } finally {
      _isHandlingLifecycleResume = false;
    }
  }

  bool _finishPendingStreamingUtteranceOnResume() {
    if (!ref.read(streamingVoiceEnabledProvider)) {
      return false;
    }
    final streamingSession = _activeStreamingSession;
    if (streamingSession == null || state.currentTranscript.trim().isEmpty) {
      return false;
    }

    unawaited(_streamingCaptureService.cancel());
    _finalizeStreamingTurn(
      transcript: _transcriptBuffer.visible,
      session: streamingSession,
      turnSequence: _streamingTurnSequence,
    );
    return true;
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
  }

  Future<void> _handleWebForegroundResume() async {
    if (_isHandlingLifecycleResume) {
      return;
    }
    _isHandlingLifecycleResume = true;
    try {
      await WebPcmMicrophoneEngine.instance.resumeIfSuspended();

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

      if (_finishPendingStreamingUtteranceOnResume()) {
        return;
      }

      // Preserve a healthy web listen cycle across tab focus blips.
      if (_hasActiveStreamingListenCycle() && _streamingSessionIsConnected()) {
        return;
      }

      final generation = ++_callGeneration;
      await _streamingCaptureService.cancel();
      _stopBargeInMonitoring();
      state = state.copyWith(isCapturingSpeech: false, clearError: true);
      _startListeningCycle(generation);
    } finally {
      _isHandlingLifecycleResume = false;
    }
  }
}
